package main

import (
	"context"
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"strings"
	"syscall"
	"time"

	cloudflare "github.com/cloudflare/cloudflare-go/v6"
	"github.com/cloudflare/cloudflare-go/v6/dns"
	"github.com/cloudflare/cloudflare-go/v6/zero_trust"
)

const shareComment = "managed-by:cf-share"

// shareAppPrefix names the Access apps `cf share` creates, so teardown (and the
// statefile-less fallback) can tell them apart from persistent `cf-access:` apps
// and never delete one it didn't create.
const shareAppPrefix = "cf-share: "

// shareState is persisted so `cf share down` can clean up after a crash.
type shareState struct {
	FullHost      string `json:"fullHost"`
	AppID         string `json:"appID"`
	PolicyID      string `json:"policyID"`
	CreatedApp    bool   `json:"createdApp"`
	DNSRecordID   string `json:"dnsRecordID"`
	ZoneID        string `json:"zoneID"`
	AccountID     string `json:"accountID"`
	CredsTempPath string `json:"credsTempPath,omitempty"`
	TunnelID      string `json:"tunnelID"`
	CreatedTunnel bool   `json:"createdTunnel"`
	UsedExec      bool   `json:"usedExec"`
}

// tunnelTokenPayload matches cloudflared's base64 TUNNEL_TOKEN JSON schema.
type tunnelTokenPayload struct {
	AccountTag   string `json:"a"`
	TunnelID     string `json:"t"`
	TunnelSecret string `json:"s"`
}

func shareUpCmd(args []string) {
	fs := flag.NewFlagSet("share up", flag.ExitOnError)
	port := fs.Int("port", 0, "Local origin port (required)")
	host := fs.String("host", "", "Hostname to expose; bare label is joined with the zone (required)")
	tunnelID := fs.String("tunnel-id", "", "Reuse this existing tunnel instead of creating an ephemeral one")
	credsFile := fs.String("creds-file", "", "Reuse a persistent tunnel via its sops creds instead of an ephemeral tunnel")
	zoneName := fs.String("zone", "", "Zone name (overrides CLOUDFLARE_ZONE)")
	accountID := fs.String("account-id", "", "Cloudflare account ID (overrides CLOUDFLARE_ACCOUNT_ID)")
	sessionDuration := fs.String("session-duration", "24h", "Access app session duration")
	ttl := fs.String("ttl", "", "Auto-teardown after this Go duration (e.g. 2h)")
	execCmd := fs.String("exec", "", "Shell command to run as the app (via sh -c) for the tunnel's lifetime")
	var emails multiFlag
	fs.Var(&emails, "email", "Allowlisted email (repeatable, at least one required)")
	fs.Parse(args)

	if *port == 0 {
		fmt.Fprintln(os.Stderr, "Error: --port is required")
		fs.Usage()
		os.Exit(1)
	}
	if *host == "" {
		fmt.Fprintln(os.Stderr, "Error: --host is required")
		fs.Usage()
		os.Exit(1)
	}
	if len(emails) == 0 {
		fmt.Fprintln(os.Stderr, "Error: at least one --email is required")
		fs.Usage()
		os.Exit(1)
	}

	var ttlDur time.Duration
	if *ttl != "" {
		d, err := time.ParseDuration(*ttl)
		if err != nil {
			log.Fatalf("Invalid --ttl %q: %v", *ttl, err)
		}
		ttlDur = d
	}

	if _, err := exec.LookPath("cloudflared"); err != nil {
		log.Fatalf("cloudflared not found in PATH: %v", err)
	}

	acctID := resolveAccountID(*accountID)
	zone := resolveZoneName(*zoneName)
	client := newClient()
	ctx := context.Background()

	fullHost := joinHost(*host, zone)
	// Default: create a throwaway tunnel per share. Passing --creds-file or
	// --tunnel-id opts into reusing a persistent tunnel instead.
	persistent := *credsFile != "" || *tunnelID != ""

	zoneID, err := resolveZoneID(client, zone)
	if err != nil {
		log.Fatalf("Failed to resolve zone: %v", err)
	}

	statePath, logPath, err := shareRuntimePaths(fullHost)
	if err != nil {
		log.Fatalf("Failed to initialize state directory: %v", err)
	}

	fmt.Println("=== cf share up ===")
	fmt.Printf("  Host:     %s\n", fullHost)
	fmt.Printf("  Origin:   http://localhost:%d\n", *port)
	fmt.Printf("  Allow:    %s\n", strings.Join(emails, ", "))
	if ttlDur > 0 {
		fmt.Printf("  TTL:      %s\n", ttlDur)
	}
	fmt.Println()

	st := &shareState{
		FullHost:  fullHost,
		ZoneID:    zoneID,
		AccountID: acctID,
	}

	// Best-effort teardown of whatever we managed to create so far.
	var appChild, cfChild *exec.Cmd
	var cfExit chan error
	cfCancel := func() {}
	reaped := false
	// Only the reaper goroutine ever calls cfChild.Wait(); teardown cancels
	// and drains its result to avoid a concurrent double-Wait.
	stopCf := func() {
		cfCancel()
		if cfExit != nil && !reaped {
			<-cfExit
			reaped = true
		}
	}
	teardown := func() {
		shareTeardown(ctx, client, st, stopCf, appChild, statePath, logPath)
	}
	fail := func(format string, a ...interface{}) {
		fmt.Fprintf(os.Stderr, "Error: "+format+"\n", a...)
		teardown()
		os.Exit(1)
	}

	// 2. Obtain tunnel credentials in memory and build TUNNEL_TOKEN (never written
	// to /tmp or passed on argv).
	var creds tunnelCredentials
	if persistent {
		credsPath := *credsFile
		if credsPath == "" {
			credsPath = filepath.Join(findRepoRoot(), "sops", "cloudflared-share.json")
		}
		decrypted, derr := decryptSharedCreds(credsPath)
		if derr != nil {
			log.Fatalf("Failed to decrypt credentials: %v", derr)
		}
		creds = decrypted
		if *tunnelID != "" {
			creds.TunnelID = *tunnelID
		}
	} else {
		name := "cf-share-" + sanitizeHost(fullHost)
		ephemeralCreds, cerr := createEphemeralTunnel(ctx, client, acctID, name)
		if cerr != nil {
			log.Fatalf("Failed to create tunnel: %v", cerr)
		}
		creds = ephemeralCreds
		st.TunnelID = creds.TunnelID
		st.CreatedTunnel = true
		fmt.Printf("Created ephemeral tunnel %s\n", creds.TunnelID)
	}

	tunnelToken, err := buildTunnelToken(creds)
	if err != nil {
		fail("failed to encode tunnel token: %v", err)
	}
	tunnelUUID := creds.TunnelID
	fmt.Printf("Tunnel:   %s\n", tunnelUUID)

	// 3. Optional app subprocess.
	if *execCmd != "" {
		fmt.Printf("Starting app: %s\n", *execCmd)
		appChild = exec.Command("sh", "-c", *execCmd)
		appChild.Stdout = os.Stdout
		appChild.Stderr = os.Stderr
		if err := appChild.Start(); err != nil {
			fail("failed to start --exec app: %v", err)
		}
		st.UsedExec = true
	}

	// 4. Access application (gate before exposing), reconciling allowlist policy
	// if an app for the domain already exists.
	appID, policyID, createdApp, err := ensureAccessApp(ctx, client, acctID, fullHost, *sessionDuration, emails)
	if err != nil {
		fail("failed to ensure Access application: %v", err)
	}
	st.AppID = appID
	st.PolicyID = policyID
	st.CreatedApp = createdApp
	fmt.Printf("Access application ready: %s\n", appID)

	// Pre-create the 0600 log file inside the 0700 state directory.
	if err := touchPrivateFile(logPath); err != nil {
		fail("failed to prepare logfile: %v", err)
	}

	// 5. Start cloudflared as a child bound to its own context, passing the
	// secret tunnel token via TUNNEL_TOKEN environment variable rather than argv.
	cfCtx, cancel := context.WithCancel(ctx)
	cfCancel = cancel
	cfChild = exec.CommandContext(cfCtx, "cloudflared", "tunnel",
		"--logfile", logPath,
		"run",
		"--url", fmt.Sprintf("http://localhost:%d", *port),
	)
	cfChild.Env = append(filteredEnv("TUNNEL_TOKEN"), "TUNNEL_TOKEN="+tunnelToken)
	cfChild.Stdout = os.Stdout
	cfChild.Stderr = os.Stderr
	// Graceful stop: SIGTERM lets cloudflared drain edge connections, so an
	// ephemeral tunnel deletes cleanly instead of erroring on active conns.
	cfChild.Cancel = func() error { return cfChild.Process.Signal(syscall.SIGTERM) }
	cfChild.WaitDelay = 8 * time.Second
	if err := cfChild.Start(); err != nil {
		fail("failed to start cloudflared: %v", err)
	}
	fmt.Printf("cloudflared started (pid %d)\n", cfChild.Process.Pid)
	cfExit = make(chan error, 1)
	go func() { cfExit <- cfChild.Wait() }()

	// 6. DNS CNAME -> tunnel, tagged so neither cf-dns nor cf-tunnel prune it.
	recordID, err := createShareCNAME(ctx, client, zoneID, fullHost, tunnelUUID)
	if err != nil {
		fail("failed to create DNS record: %v", err)
	}
	st.DNSRecordID = recordID

	// 7. Statefile for crash recovery.
	if err := writeShareState(statePath, st); err != nil {
		fail("failed to write statefile: %v", err)
	}

	fmt.Println()
	fmt.Printf("Live: https://%s\n", fullHost)
	fmt.Println("Press Ctrl-C to tear down.")

	// 8. Block until signal, ttl expiry, or cloudflared exit.
	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)

	var ttlCh <-chan time.Time
	if ttlDur > 0 {
		t := time.NewTimer(ttlDur)
		defer t.Stop()
		ttlCh = t.C
	}

	select {
	case sig := <-sigCh:
		fmt.Printf("\nReceived %s, tearing down...\n", sig)
	case <-ttlCh:
		fmt.Printf("\nTTL %s elapsed, tearing down...\n", ttlDur)
	case err := <-cfExit:
		reaped = true // Wait already returned; teardown must not drain again
		fmt.Printf("\ncloudflared exited (%v), tearing down...\n", err)
	}

	teardown()
}

func shareDownCmd(args []string) {
	fs := flag.NewFlagSet("share down", flag.ExitOnError)
	host := fs.String("host", "", "Hostname to tear down (required)")
	zoneName := fs.String("zone", "", "Zone name (overrides CLOUDFLARE_ZONE)")
	accountID := fs.String("account-id", "", "Cloudflare account ID (overrides CLOUDFLARE_ACCOUNT_ID)")
	fs.Parse(args)

	if *host == "" {
		fmt.Fprintln(os.Stderr, "Error: --host is required")
		fs.Usage()
		os.Exit(1)
	}

	acctID := resolveAccountID(*accountID)
	zone := resolveZoneName(*zoneName)
	client := newClient()
	ctx := context.Background()

	fullHost := joinHost(*host, zone)
	statePath, logPath, err := shareRuntimePaths(fullHost)
	if err != nil {
		log.Fatalf("Failed to resolve state directory: %v", err)
	}

	if st, err := readShareState(statePath); err == nil {
		fmt.Printf("Tearing down %s from statefile...\n", fullHost)
		shareTeardown(ctx, client, st, func() {}, nil, statePath, logPath)
		return
	}

	// Fallback: reconstruct enough to delete the app, CNAME, and any ephemeral
	// tunnel named after the host.
	fmt.Printf("No statefile; reconciling %s from API...\n", fullHost)
	zoneID, err := resolveZoneID(client, zone)
	if err != nil {
		log.Fatalf("Failed to resolve zone: %v", err)
	}
	st := &shareState{FullHost: fullHost, ZoneID: zoneID, AccountID: acctID}
	if id := findShareTunnel(ctx, client, acctID, "cf-share-"+sanitizeHost(fullHost)); id != "" {
		st.TunnelID = id
		st.CreatedTunnel = true
	}
	// Recover the Access app so a crash without a statefile doesn't orphan it.
	// Restricted to `cf-share:` apps so a host collision can't delete a
	// persistent gate.
	if appID, policyID := findShareApp(ctx, client, acctID, fullHost); appID != "" {
		st.AppID = appID
		st.PolicyID = policyID
		st.CreatedApp = true
	}
	shareTeardown(ctx, client, st, func() {}, nil, statePath, logPath)
}

// joinHost treats a dotless host as a subdomain label of the zone.
func joinHost(host, zone string) string {
	if strings.Contains(host, ".") {
		return host
	}
	return host + "." + zone
}

// sanitizeHost makes a hostname safe for use in file and tunnel names.
func sanitizeHost(fullHost string) string {
	return strings.NewReplacer("/", "_", ".", "_", string(os.PathSeparator), "_").Replace(fullHost)
}

// stateDir returns $XDG_STATE_HOME/cf (fallback $HOME/.local/state/cf),
// ensuring it exists with mode 0700. Never falls back to world-writable /tmp.
func stateDir() (string, error) {
	base := os.Getenv("XDG_STATE_HOME")
	if base == "" {
		home, err := os.UserHomeDir()
		if err != nil || home == "" {
			return "", fmt.Errorf("cannot determine user home directory: %w", err)
		}
		base = filepath.Join(home, ".local", "state")
	}
	dir := filepath.Join(base, "cf")
	if err := os.MkdirAll(dir, 0700); err != nil {
		return "", fmt.Errorf("create state dir %s: %w", dir, err)
	}
	if err := os.Chmod(dir, 0700); err != nil {
		return "", fmt.Errorf("chmod state dir %s: %w", dir, err)
	}
	return dir, nil
}

func shareRuntimePaths(fullHost string) (statePath, logPath string, err error) {
	dir, err := stateDir()
	if err != nil {
		return "", "", err
	}
	stem := filepath.Join(dir, "share-"+sanitizeHost(fullHost))
	return stem + ".json", stem + ".log", nil
}

func touchPrivateFile(path string) error {
	f, err := os.OpenFile(path, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, 0600)
	if err != nil {
		return err
	}
	if err := f.Chmod(0600); err != nil {
		f.Close()
		return err
	}
	return f.Close()
}

func writeShareState(path string, st *shareState) error {
	data, err := json.MarshalIndent(st, "", "  ")
	if err != nil {
		return err
	}
	dir := filepath.Dir(path)
	tmp, err := os.CreateTemp(dir, ".share-state-*.tmp")
	if err != nil {
		return err
	}
	tmpName := tmp.Name()
	if err := tmp.Chmod(0600); err != nil {
		tmp.Close()
		os.Remove(tmpName)
		return err
	}
	if _, err := tmp.Write(data); err != nil {
		tmp.Close()
		os.Remove(tmpName)
		return err
	}
	if err := tmp.Close(); err != nil {
		os.Remove(tmpName)
		return err
	}
	return os.Rename(tmpName, path)
}

func readShareState(path string) (*shareState, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	var st shareState
	if err := json.Unmarshal(data, &st); err != nil {
		return nil, err
	}
	return &st, nil
}

// buildTunnelToken encodes tunnel credentials into a cloudflared TUNNEL_TOKEN.
func buildTunnelToken(creds tunnelCredentials) (string, error) {
	if creds.AccountTag == "" || creds.TunnelID == "" || creds.TunnelSecret == "" {
		return "", fmt.Errorf("incomplete tunnel credentials (accountTag/tunnelID/tunnelSecret required)")
	}
	raw, err := json.Marshal(tunnelTokenPayload{
		AccountTag:   creds.AccountTag,
		TunnelID:     creds.TunnelID,
		TunnelSecret: creds.TunnelSecret,
	})
	if err != nil {
		return "", err
	}
	return base64.StdEncoding.EncodeToString(raw), nil
}

// filteredEnv returns os.Environ() with any existing entry for key removed.
func filteredEnv(key string) []string {
	prefix := key + "="
	env := os.Environ()
	out := make([]string, 0, len(env)+1)
	for _, kv := range env {
		if !strings.HasPrefix(kv, prefix) {
			out = append(out, kv)
		}
	}
	return out
}

// decryptSharedCreds runs sops and parses credentials in memory without
// writing plaintext secrets to disk.
func decryptSharedCreds(credsFile string) (tunnelCredentials, error) {
	if !fileExists(credsFile) {
		return tunnelCredentials{}, fmt.Errorf("creds file %s not found", credsFile)
	}
	cmd := exec.Command("sops", "-d", "--input-type", "binary", "--output-type", "binary", credsFile)
	cmd.Stderr = os.Stderr
	out, err := cmd.Output()
	if err != nil {
		return tunnelCredentials{}, fmt.Errorf("sops decrypt failed: %w", err)
	}

	var creds tunnelCredentials
	if err := json.Unmarshal(out, &creds); err != nil {
		return tunnelCredentials{}, fmt.Errorf("parse decrypted creds: %w", err)
	}
	if creds.TunnelID == "" {
		return tunnelCredentials{}, fmt.Errorf("creds file %s has no TunnelID", credsFile)
	}
	return creds, nil
}

// createEphemeralTunnel creates a throwaway tunnel and returns its credentials
// in memory (never written to disk or sops-encrypted).
func createEphemeralTunnel(ctx context.Context, client *cloudflare.Client, accountID, name string) (tunnelCredentials, error) {
	secretBytes := make([]byte, 32)
	if _, err := rand.Read(secretBytes); err != nil {
		return tunnelCredentials{}, fmt.Errorf("generate tunnel secret: %w", err)
	}
	secret := base64.StdEncoding.EncodeToString(secretBytes)

	t, err := client.ZeroTrust.Tunnels.Cloudflared.New(ctx, zero_trust.TunnelCloudflaredNewParams{
		AccountID:    cloudflare.F(accountID),
		Name:         cloudflare.F(name),
		ConfigSrc:    cloudflare.F(zero_trust.TunnelCloudflaredNewParamsConfigSrcLocal),
		TunnelSecret: cloudflare.F(secret),
	})
	if err != nil {
		return tunnelCredentials{}, err
	}

	return tunnelCredentials{
		AccountTag:   t.AccountTag,
		TunnelID:     t.ID,
		TunnelSecret: secret,
	}, nil
}

// findShareTunnel returns the ID of a non-deleted tunnel with the given name.
func findShareTunnel(ctx context.Context, client *cloudflare.Client, accountID, name string) string {
	iter := client.ZeroTrust.Tunnels.Cloudflared.ListAutoPaging(ctx, zero_trust.TunnelCloudflaredListParams{
		AccountID: cloudflare.F(accountID),
		IsDeleted: cloudflare.F(false),
		Name:      cloudflare.F(name),
	})
	for iter.Next() {
		if t := iter.Current(); strings.EqualFold(t.Name, name) {
			return t.ID
		}
	}
	return ""
}

// validateExistingShareApp refuses to adopt or overwrite an existing Cloudflare
// Access application unless its name carries shareAppPrefix ("cf-share: ").
// Without this check, running `cf share up` against a hostname already gated by
// a permanent `cf-access:` application would overwrite its allowlist policy and
// leave the modified policy in place after teardown.
func validateExistingShareApp(name, domain, id string) error {
	if !strings.HasPrefix(name, shareAppPrefix) {
		return fmt.Errorf(
			"refusing to modify existing non-cf-share Access application %q (%s) on %s; only %q-prefixed apps may be reconciled",
			name, id, domain, shareAppPrefix,
		)
	}
	return nil
}

// ensureAccessApp reconciles an existing `cf-share:` self-hosted app for the
// domain (verifying and updating its allowlist policy and session duration if
// drifted), refuses to touch unmanaged apps on that domain, or creates a new
// `cf-share:` app with an allowlist policy attached.
// created reports whether this call created the app; teardown only deletes apps
// it created, so a reused (pre-existing `cf-share:`) app is left in place.
func ensureAccessApp(ctx context.Context, client *cloudflare.Client, acctID, domain, sessionDuration string, emails []string) (appID, policyID string, created bool, err error) {
	iter := client.ZeroTrust.Access.Applications.ListAutoPaging(ctx, zero_trust.AccessApplicationListParams{
		AccountID: cloudflare.F(acctID),
		Domain:    cloudflare.F(domain),
		Exact:     cloudflare.F(true),
	})
	for iter.Next() {
		raw := iter.Current()
		if !strings.EqualFold(raw.Domain, domain) {
			continue
		}
		sh, ok := raw.AsUnion().(zero_trust.AccessApplicationListResponseSelfHostedApplication)
		if !ok {
			return "", "", false, fmt.Errorf("existing Access application %s for %s has unsupported type %q", raw.ID, domain, raw.Type)
		}
		if err := validateExistingShareApp(sh.Name, domain, sh.ID); err != nil {
			return "", "", false, err
		}

		existing := managedAccessApp{
			id:              sh.ID,
			domain:          sh.Domain,
			name:            sh.Name,
			sessionDuration: sh.SessionDuration,
			tags:            sh.Tags,
		}
		if len(sh.Policies) > 0 {
			p := sh.Policies[0]
			existing.policyID = p.ID
			existing.emails = policyEmails(p.Include)
		}

		needsReconcile := existing.policyID == "" ||
			len(sh.Policies) != 1 ||
			!emailsEqual(existing.emails, emails) ||
			existing.sessionDuration != sessionDuration

		if needsReconcile {
			fmt.Printf("Reconciling existing cf-share Access application %s (updating policy/session)...\n", sh.ID)
			if err := updateManagedApp(ctx, client, acctID, existing, existing.name, sessionDuration, emails); err != nil {
				return "", "", false, fmt.Errorf("reconcile existing Access application %s: %w", sh.ID, err)
			}
		} else {
			fmt.Printf("Reusing existing cf-share Access application %s (policy verified)\n", sh.ID)
		}
		return sh.ID, "", false, nil
	}
	if err := iter.Err(); err != nil {
		return "", "", false, fmt.Errorf("list applications: %w", err)
	}

	// share apps stay untagged; only `access sync` tags apps it manages.
	id, pol, err := createAccessAppWithPolicy(ctx, client, acctID, domain, shareAppPrefix+domain, sessionDuration, emails, nil)
	return id, pol, err == nil, err
}

// findShareApp returns the ID and first-policy ID of a `cf share`-created app for
// the domain, or empty strings. The name-prefix guard ensures we never adopt a
// persistent `cf-access:` app that happens to share the domain.
func findShareApp(ctx context.Context, client *cloudflare.Client, acctID, domain string) (appID, policyID string) {
	iter := client.ZeroTrust.Access.Applications.ListAutoPaging(ctx, zero_trust.AccessApplicationListParams{
		AccountID: cloudflare.F(acctID),
		Domain:    cloudflare.F(domain),
		Exact:     cloudflare.F(true),
	})
	for iter.Next() {
		sh, ok := iter.Current().AsUnion().(zero_trust.AccessApplicationListResponseSelfHostedApplication)
		if !ok || !strings.EqualFold(sh.Domain, domain) || !strings.HasPrefix(sh.Name, shareAppPrefix) {
			continue
		}
		appID = sh.ID
		if len(sh.Policies) > 0 {
			policyID = sh.Policies[0].ID
		}
		return appID, policyID
	}
	return "", ""
}

// createShareCNAME points fullHost at the tunnel, tagged managed-by:cf-share.
func createShareCNAME(ctx context.Context, client *cloudflare.Client, zoneID, fullHost, tunnelID string) (string, error) {
	target := fmt.Sprintf("%s.cfargotunnel.com", tunnelID)
	fmt.Printf("  CREATE CNAME  %s -> %s\n", fullHost, target)
	rec, err := client.DNS.Records.New(ctx, dns.RecordNewParams{
		ZoneID: cloudflare.F(zoneID),
		Body: dns.CNAMERecordParam{
			Name:    cloudflare.F(fullHost),
			Type:    cloudflare.F(dns.CNAMERecordTypeCNAME),
			Content: cloudflare.F(target),
			TTL:     cloudflare.F(dns.TTL(1)),
			Proxied: cloudflare.F(true),
			Comment: cloudflare.F(shareComment),
		},
	})
	if err != nil {
		return "", err
	}
	return rec.ID, nil
}

// shareTeardown reverses `up` best-effort: DNS, Access app+policy, children,
// ephemeral tunnel, runtime files.
func shareTeardown(ctx context.Context, client *cloudflare.Client, st *shareState, stopCf func(), appChild *exec.Cmd, statePath, logPath string) {
	deleteShareCNAME(ctx, client, st)

	// Only tear down the Access app/policy this share created; a reused
	// pre-existing app is left in place.
	if st.CreatedApp && st.AppID != "" {
		if _, err := client.ZeroTrust.Access.Applications.Delete(ctx, st.AppID, zero_trust.AccessApplicationDeleteParams{
			AccountID: cloudflare.F(st.AccountID),
		}); err != nil {
			fmt.Fprintf(os.Stderr, "Warning: failed to delete Access application %s: %v\n", st.AppID, err)
		}
	}
	if st.CreatedApp && st.PolicyID != "" {
		if _, err := client.ZeroTrust.Access.Policies.Delete(ctx, st.PolicyID, zero_trust.AccessPolicyDeleteParams{
			AccountID: cloudflare.F(st.AccountID),
		}); err != nil {
			fmt.Fprintf(os.Stderr, "Warning: failed to delete Access policy %s: %v\n", st.PolicyID, err)
		}
	}

	stopCf()
	if appChild != nil && appChild.Process != nil {
		_ = appChild.Process.Kill()
		_ = appChild.Wait()
	}

	// Delete the tunnel only if this share created it (cloudflared is now
	// stopped, so edge connections have drained).
	if st.CreatedTunnel && st.TunnelID != "" {
		cleanupTunnel(ctx, client, st.AccountID, st.TunnelID)
	}

	if st.CredsTempPath != "" {
		if err := os.Remove(st.CredsTempPath); err != nil && !os.IsNotExist(err) {
			fmt.Fprintf(os.Stderr, "Warning: failed to remove temp creds %s: %v\n", st.CredsTempPath, err)
		}
	}
	if err := os.Remove(logPath); err != nil && !os.IsNotExist(err) {
		fmt.Fprintf(os.Stderr, "Warning: failed to remove logfile %s: %v\n", logPath, err)
	}
	if err := os.Remove(statePath); err != nil && !os.IsNotExist(err) {
		fmt.Fprintf(os.Stderr, "Warning: failed to remove statefile %s: %v\n", statePath, err)
	}
	fmt.Println("Teardown complete.")
}

// deleteShareCNAME removes the record by ID, falling back to a name+tag match.
func deleteShareCNAME(ctx context.Context, client *cloudflare.Client, st *shareState) {
	recordID := st.DNSRecordID
	if recordID == "" {
		iter := client.DNS.Records.ListAutoPaging(ctx, dns.RecordListParams{
			ZoneID: cloudflare.F(st.ZoneID),
			Type:   cloudflare.F(dns.RecordListParamsTypeCNAME),
			Name: cloudflare.F(dns.RecordListParamsName{
				Exact: cloudflare.F(st.FullHost),
			}),
		})
		for iter.Next() {
			r := iter.Current()
			if r.Name == st.FullHost && strings.Contains(r.Comment, shareComment) {
				recordID = r.ID
				break
			}
		}
		if err := iter.Err(); err != nil {
			fmt.Fprintf(os.Stderr, "Warning: failed to list DNS records: %v\n", err)
			return
		}
	}
	if recordID == "" {
		return // already gone
	}
	if _, err := client.DNS.Records.Delete(ctx, recordID, dns.RecordDeleteParams{
		ZoneID: cloudflare.F(st.ZoneID),
	}); err != nil {
		fmt.Fprintf(os.Stderr, "Warning: failed to delete DNS record %s: %v\n", recordID, err)
	}
}
