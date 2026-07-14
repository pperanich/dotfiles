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

// shareState is persisted so `cf share down` can clean up after a crash.
type shareState struct {
	FullHost      string `json:"fullHost"`
	AppID         string `json:"appID"`
	PolicyID      string `json:"policyID"`
	DNSRecordID   string `json:"dnsRecordID"`
	ZoneID        string `json:"zoneID"`
	AccountID     string `json:"accountID"`
	CredsTempPath string `json:"credsTempPath"`
	TunnelID      string `json:"tunnelID"`
	CreatedTunnel bool   `json:"createdTunnel"`
	UsedExec      bool   `json:"usedExec"`
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

	fmt.Println("=== cf share up ===")
	fmt.Printf("  Host:     %s\n", fullHost)
	fmt.Printf("  Origin:   http://localhost:%d\n", *port)
	fmt.Printf("  Allow:    %s\n", strings.Join(emails, ", "))
	if ttlDur > 0 {
		fmt.Printf("  TTL:      %s\n", ttlDur)
	}
	fmt.Println()

	st := &shareState{FullHost: fullHost, ZoneID: zoneID, AccountID: acctID}
	statePath := shareStatePath(fullHost)

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
		shareTeardown(ctx, client, st, stopCf, appChild, statePath)
	}
	fail := func(format string, a ...interface{}) {
		fmt.Fprintf(os.Stderr, "Error: "+format+"\n", a...)
		teardown()
		os.Exit(1)
	}

	// 2. Obtain a tunnel + creds temp file (0600). Ephemeral by default;
	// persistent mode reads an existing tunnel from sops creds.
	var tmpCreds, tunnelUUID string
	if persistent {
		credsPath := *credsFile
		if credsPath == "" {
			credsPath = filepath.Join(findRepoRoot(), "sops", "cloudflared-share.json")
		}
		path, credsTunnelID, derr := decryptSharedCreds(credsPath)
		if derr != nil {
			log.Fatalf("Failed to decrypt credentials: %v", derr)
		}
		tmpCreds = path
		tunnelUUID = credsTunnelID
		if *tunnelID != "" {
			tunnelUUID = *tunnelID
		}
	} else {
		name := "cf-share-" + sanitizeHost(fullHost)
		id, credsJSON, cerr := createEphemeralTunnel(ctx, client, acctID, name)
		if cerr != nil {
			log.Fatalf("Failed to create tunnel: %v", cerr)
		}
		st.TunnelID = id
		st.CreatedTunnel = true
		tunnelUUID = id
		path, werr := writeTempCreds(credsJSON)
		if werr != nil {
			cleanupTunnel(ctx, client, acctID, id)
			log.Fatalf("Failed to stage credentials: %v", werr)
		}
		tmpCreds = path
		fmt.Printf("Created ephemeral tunnel %s\n", id)
	}
	st.CredsTempPath = tmpCreds
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

	// 4. Access application (gate before exposing), reused if it already exists.
	appID, policyID, err := ensureAccessApp(ctx, client, acctID, fullHost, *sessionDuration, emails)
	if err != nil {
		fail("failed to create Access application: %v", err)
	}
	st.AppID = appID
	st.PolicyID = policyID
	fmt.Printf("Access application ready: %s\n", appID)

	// 5. Start cloudflared as a child bound to its own context.
	cfCtx, cancel := context.WithCancel(ctx)
	cfCancel = cancel
	cfChild = exec.CommandContext(cfCtx, "cloudflared", "tunnel", "run",
		"--credentials-file", tmpCreds,
		"--url", fmt.Sprintf("http://localhost:%d", *port),
		tunnelUUID)
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
	statePath := shareStatePath(fullHost)

	if st, err := readShareState(statePath); err == nil {
		fmt.Printf("Tearing down %s from statefile...\n", fullHost)
		shareTeardown(ctx, client, st, func() {}, nil, statePath)
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
	shareTeardown(ctx, client, st, func() {}, nil, statePath)
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

func runtimeDir() string {
	if dir := os.Getenv("XDG_RUNTIME_DIR"); dir != "" {
		return dir
	}
	return os.TempDir()
}

func shareStatePath(fullHost string) string {
	return filepath.Join(runtimeDir(), "cf-share-"+sanitizeHost(fullHost)+".json")
}

func writeShareState(path string, st *shareState) error {
	data, err := json.MarshalIndent(st, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(path, data, 0600)
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

// decryptSharedCreds runs sops, writes plaintext creds to a 0600 temp file, and
// returns the temp path plus the tunnel UUID embedded in the credentials.
func decryptSharedCreds(credsFile string) (path, tunnelID string, err error) {
	if !fileExists(credsFile) {
		return "", "", fmt.Errorf("creds file %s not found", credsFile)
	}
	cmd := exec.Command("sops", "-d", "--input-type", "binary", "--output-type", "binary", credsFile)
	cmd.Stderr = os.Stderr
	out, err := cmd.Output()
	if err != nil {
		return "", "", fmt.Errorf("sops decrypt failed: %w", err)
	}

	var creds tunnelCredentials
	if err := json.Unmarshal(out, &creds); err != nil {
		return "", "", fmt.Errorf("parse decrypted creds: %w", err)
	}
	if creds.TunnelID == "" {
		return "", "", fmt.Errorf("creds file %s has no TunnelID", credsFile)
	}

	path, err = writeTempCreds(out)
	return path, creds.TunnelID, err
}

// writeTempCreds stages cloudflared credentials in a 0600 temp file.
func writeTempCreds(credsJSON []byte) (string, error) {
	f, err := os.CreateTemp(runtimeDir(), "cf-share-creds-*.json")
	if err != nil {
		return "", err
	}
	if err := f.Chmod(0600); err != nil {
		f.Close()
		os.Remove(f.Name())
		return "", err
	}
	if _, err := f.Write(credsJSON); err != nil {
		f.Close()
		os.Remove(f.Name())
		return "", err
	}
	if err := f.Close(); err != nil {
		os.Remove(f.Name())
		return "", err
	}
	return f.Name(), nil
}

// createEphemeralTunnel creates a throwaway tunnel and returns its ID plus the
// cloudflared credentials JSON, kept in memory (never sops-encrypted).
func createEphemeralTunnel(ctx context.Context, client *cloudflare.Client, accountID, name string) (string, []byte, error) {
	secretBytes := make([]byte, 32)
	if _, err := rand.Read(secretBytes); err != nil {
		return "", nil, fmt.Errorf("generate tunnel secret: %w", err)
	}
	secret := base64.StdEncoding.EncodeToString(secretBytes)

	t, err := client.ZeroTrust.Tunnels.Cloudflared.New(ctx, zero_trust.TunnelCloudflaredNewParams{
		AccountID:    cloudflare.F(accountID),
		Name:         cloudflare.F(name),
		ConfigSrc:    cloudflare.F(zero_trust.TunnelCloudflaredNewParamsConfigSrcLocal),
		TunnelSecret: cloudflare.F(secret),
	})
	if err != nil {
		return "", nil, err
	}

	credsJSON, err := json.Marshal(tunnelCredentials{
		AccountTag:   t.AccountTag,
		TunnelID:     t.ID,
		TunnelSecret: secret,
	})
	if err != nil {
		cleanupTunnel(ctx, client, accountID, t.ID)
		return "", nil, fmt.Errorf("marshal credentials: %w", err)
	}
	return t.ID, credsJSON, nil
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

// ensureAccessApp returns an existing self-hosted app for the domain, or creates
// one with a reusable allowlist policy attached. The v6.7.0 inline policy union
// carries no decision/include, so we create the policy via Policies.New and link it.
func ensureAccessApp(ctx context.Context, client *cloudflare.Client, acctID, domain, sessionDuration string, emails []string) (appID, policyID string, err error) {
	iter := client.ZeroTrust.Access.Applications.ListAutoPaging(ctx, zero_trust.AccessApplicationListParams{
		AccountID: cloudflare.F(acctID),
		Domain:    cloudflare.F(domain),
		Exact:     cloudflare.F(true),
	})
	for iter.Next() {
		app := iter.Current()
		if strings.EqualFold(app.Domain, domain) {
			fmt.Printf("Reusing existing Access application %s\n", app.ID)
			return app.ID, "", nil
		}
	}
	if err := iter.Err(); err != nil {
		return "", "", fmt.Errorf("list applications: %w", err)
	}

	include := make([]zero_trust.AccessRuleUnionParam, 0, len(emails))
	for _, e := range emails {
		include = append(include, zero_trust.EmailRuleParam{
			Email: cloudflare.F(zero_trust.EmailRuleEmailParam{Email: cloudflare.F(e)}),
		})
	}

	pol, err := client.ZeroTrust.Access.Policies.New(ctx, zero_trust.AccessPolicyNewParams{
		AccountID: cloudflare.F(acctID),
		Decision:  cloudflare.F(zero_trust.DecisionAllow),
		Name:      cloudflare.F("cf-share allowlist: " + domain),
		Include:   cloudflare.F(include),
	})
	if err != nil {
		return "", "", fmt.Errorf("create policy: %w", err)
	}

	app, err := client.ZeroTrust.Access.Applications.New(ctx, zero_trust.AccessApplicationNewParams{
		AccountID: cloudflare.F(acctID),
		Body: zero_trust.AccessApplicationNewParamsBodySelfHostedApplication{
			Domain:          cloudflare.F(domain),
			Type:            cloudflare.F(zero_trust.ApplicationTypeSelfHosted),
			Name:            cloudflare.F("cf-share: " + domain),
			SessionDuration: cloudflare.F(sessionDuration),
			Policies: cloudflare.F([]zero_trust.AccessApplicationNewParamsBodySelfHostedApplicationPolicyUnion{
				zero_trust.AccessApplicationNewParamsBodySelfHostedApplicationPoliciesAccessAppPolicyLink{
					ID: cloudflare.F(pol.ID),
				},
			}),
		},
	})
	if err != nil {
		// Roll back the orphaned policy on app-create failure.
		_, delErr := client.ZeroTrust.Access.Policies.Delete(ctx, pol.ID, zero_trust.AccessPolicyDeleteParams{
			AccountID: cloudflare.F(acctID),
		})
		if delErr != nil {
			fmt.Fprintf(os.Stderr, "Warning: failed to clean up policy %s: %v\n", pol.ID, delErr)
		}
		return "", "", fmt.Errorf("create application: %w", err)
	}
	return app.ID, pol.ID, nil
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
// ephemeral tunnel, temp files.
func shareTeardown(ctx context.Context, client *cloudflare.Client, st *shareState, stopCf func(), appChild *exec.Cmd, statePath string) {
	deleteShareCNAME(ctx, client, st)

	if st.AppID != "" {
		if _, err := client.ZeroTrust.Access.Applications.Delete(ctx, st.AppID, zero_trust.AccessApplicationDeleteParams{
			AccountID: cloudflare.F(st.AccountID),
		}); err != nil {
			fmt.Fprintf(os.Stderr, "Warning: failed to delete Access application %s: %v\n", st.AppID, err)
		}
	}
	if st.PolicyID != "" {
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
