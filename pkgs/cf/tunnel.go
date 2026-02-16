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
	"path/filepath"
	"strings"

	cloudflare "github.com/cloudflare/cloudflare-go/v6"
	"github.com/cloudflare/cloudflare-go/v6/dns"
	"github.com/cloudflare/cloudflare-go/v6/zero_trust"
)

// tunnelMetadata is the JSON structure committed to the repo for Nix eval.
type tunnelMetadata struct {
	TunnelID   string `json:"tunnelId"`
	TunnelName string `json:"tunnelName"`
}

// tunnelCredentials is the cloudflared credentials JSON format.
type tunnelCredentials struct {
	AccountTag   string `json:"AccountTag"`
	TunnelID     string `json:"TunnelID"`
	TunnelSecret string `json:"TunnelSecret"`
}

const nilUUID = "00000000-0000-0000-0000-000000000000"

func tunnelListCmd(args []string) {
	fs := flag.NewFlagSet("tunnel list", flag.ExitOnError)
	accountID := fs.String("account-id", "", "Cloudflare account ID (overrides CLOUDFLARE_ACCOUNT_ID)")
	fs.Parse(args)

	acctID := resolveAccountID(*accountID)
	client := newClient()

	ctx := context.Background()
	iter := client.ZeroTrust.Tunnels.Cloudflared.ListAutoPaging(ctx, zero_trust.TunnelCloudflaredListParams{
		AccountID: cloudflare.F(acctID),
		IsDeleted: cloudflare.F(false),
	})

	fmt.Printf("%-38s %-20s %-12s %-20s\n", "ID", "NAME", "STATUS", "CREATED")
	for iter.Next() {
		t := iter.Current()
		created := ""
		if !t.CreatedAt.IsZero() {
			created = t.CreatedAt.Format("2006-01-02 15:04")
		}
		fmt.Printf("%-38s %-20s %-12s %-20s\n", t.ID, t.Name, t.Status, created)
	}
	if err := iter.Err(); err != nil {
		log.Fatalf("Failed to list tunnels: %v", err)
	}
}

func tunnelSyncCmd(args []string) {
	fs := flag.NewFlagSet("tunnel sync", flag.ExitOnError)
	name := fs.String("name", "", "Tunnel name (required)")
	accountID := fs.String("account-id", "", "Cloudflare account ID (overrides CLOUDFLARE_ACCOUNT_ID)")
	apply := fs.Bool("apply", false, "Apply changes (default: dry run)")
	force := fs.Bool("force", false, "Force operation on stale state")
	credsFile := fs.String("creds-file", "", "Path for encrypted credentials (default: sops/cloudflared-tunnel.json)")
	metaFile := fs.String("meta-file", "", "Path for metadata JSON (default: auto-detect)")
	var hostnames multiFlag
	fs.Var(&hostnames, "hostname", "Hostname for tunnel CNAME (repeatable)")
	zoneName := fs.String("zone", "", "Zone name for CNAME records (overrides CLOUDFLARE_ZONE)")
	fs.Parse(args)

	if *name == "" {
		fmt.Fprintln(os.Stderr, "Error: --name is required")
		fs.Usage()
		os.Exit(1)
	}

	acctID := resolveAccountID(*accountID)
	client := newClient()
	ctx := context.Background()

	// Resolve paths
	repoRoot := findRepoRoot()
	if *credsFile == "" {
		*credsFile = filepath.Join(repoRoot, "sops", "cloudflared-tunnel.json")
	}
	if *metaFile == "" {
		*metaFile = filepath.Join(repoRoot, "machines", "pp-router1", "cf-tunnel.json")
	}

	// --- Gather state ---
	// 1. Check for existing tunnel via API
	var existingTunnelID string
	iter := client.ZeroTrust.Tunnels.Cloudflared.ListAutoPaging(ctx, zero_trust.TunnelCloudflaredListParams{
		AccountID: cloudflare.F(acctID),
		IsDeleted: cloudflare.F(false),
		Name:      cloudflare.F(*name),
	})
	for iter.Next() {
		t := iter.Current()
		if strings.EqualFold(t.Name, *name) {
			existingTunnelID = t.ID
			break
		}
	}
	if err := iter.Err(); err != nil {
		log.Fatalf("Failed to list tunnels: %v", err)
	}

	// 2. Check for metadata file
	var meta tunnelMetadata
	metaExists := false
	if data, err := os.ReadFile(*metaFile); err == nil {
		metaExists = true
		if err := json.Unmarshal(data, &meta); err != nil {
			log.Fatalf("Failed to parse metadata file %s: %v", *metaFile, err)
		}
	}
	// Treat nil-UUID placeholder as "no metadata"
	if meta.TunnelID == nilUUID {
		meta = tunnelMetadata{}
		// File exists but has placeholder — treat as no real metadata
	}

	// 3. Check for credentials file
	credsExist := fileExists(*credsFile)

	// --- State machine ---
	hasTunnel := existingTunnelID != ""
	hasMeta := metaExists && meta.TunnelID != ""
	hasCreds := credsExist

	fmt.Printf("Tunnel sync for %q:\n", *name)
	fmt.Printf("  API tunnel:  %s\n", boolToState(hasTunnel, existingTunnelID))
	fmt.Printf("  Metadata:    %s\n", boolToState(hasMeta, meta.TunnelID))
	fmt.Printf("  Credentials: %s\n", boolToState(hasCreds, *credsFile))
	fmt.Println()

	switch {
	case !hasTunnel && !hasMeta && !hasCreds:
		// Fresh start — create everything
		fmt.Println("Action: CREATE tunnel, encrypt credentials, write metadata")
		if len(hostnames) > 0 {
			fmt.Printf("Action: CREATE CNAME records for %v\n", hostnames)
		}

		if !*apply {
			fmt.Println("\n(DRY RUN - Run with --apply to execute)")
			os.Exit(2)
		}

		tunnelID, _ := createTunnel(ctx, client, acctID, *name, *credsFile)
		writeMetadata(*metaFile, tunnelID, *name)
		if len(hostnames) > 0 {
			zone := resolveZoneName(*zoneName)
			createTunnelCNAMEs(ctx, client, zone, tunnelID, hostnames)
		}

		printNextSteps(tunnelID, *name, *credsFile, *metaFile)

	case hasTunnel && hasMeta && hasCreds:
		// Everything exists — verify and update CNAMEs if needed
		if meta.TunnelID != existingTunnelID {
			log.Fatalf("MISMATCH: metadata tunnelId=%s but API tunnel=%s. Manual resolution required.", meta.TunnelID, existingTunnelID)
		}
		fmt.Println("State: Tunnel, metadata, and credentials all present and matching.")
		if len(hostnames) > 0 {
			zone := resolveZoneName(*zoneName)
			fmt.Printf("Action: Ensure CNAME records for %v\n", hostnames)
			if !*apply {
				fmt.Println("\n(DRY RUN - Run with --apply to execute)")
				os.Exit(2)
			}
			createTunnelCNAMEs(ctx, client, zone, existingTunnelID, hostnames)
		} else {
			fmt.Println("Nothing to do.")
		}

	case hasTunnel && hasMeta && !hasCreds:
		// Credentials lost — FATAL
		log.Fatalf("FATAL: Tunnel %s exists and metadata present, but credentials file %s is missing.\n"+
			"The tunnel secret cannot be recovered from the API. You must:\n"+
			"  1. Delete the tunnel in Cloudflare dashboard\n"+
			"  2. Reset metadata: set tunnelId to %q in %s\n"+
			"  3. Re-run: cf tunnel sync --name %s --apply",
			existingTunnelID, *credsFile, nilUUID, *metaFile, *name)

	case hasTunnel && !hasMeta && hasCreds:
		// Metadata missing — reconstruct from API
		fmt.Printf("Warning: Metadata file missing but tunnel %s exists. Writing metadata.\n", existingTunnelID)
		if !*apply {
			fmt.Println("\n(DRY RUN - Run with --apply to execute)")
			os.Exit(2)
		}
		writeMetadata(*metaFile, existingTunnelID, *name)

	case !hasTunnel && hasMeta && hasCreds:
		// Stale state — tunnel deleted but local artifacts remain
		fmt.Printf("Warning: No tunnel named %q found in API, but metadata and credentials exist.\n", *name)
		fmt.Println("This may be stale state from a deleted tunnel.")
		if !*force {
			log.Fatal("Use --force to re-create the tunnel and overwrite existing files.")
		}
		fmt.Println("Action: CREATE new tunnel (overwriting stale state)")
		if !*apply {
			fmt.Println("\n(DRY RUN - Run with --apply to execute)")
			os.Exit(2)
		}
		tunnelID, _ := createTunnel(ctx, client, acctID, *name, *credsFile)
		writeMetadata(*metaFile, tunnelID, *name)
		if len(hostnames) > 0 {
			zone := resolveZoneName(*zoneName)
			createTunnelCNAMEs(ctx, client, zone, tunnelID, hostnames)
		}
		printNextSteps(tunnelID, *name, *credsFile, *metaFile)

	default:
		// Other partial states
		fmt.Printf("Warning: Unexpected state combination (tunnel=%v, meta=%v, creds=%v)\n", hasTunnel, hasMeta, hasCreds)
		if !*force {
			log.Fatal("Use --force to proceed despite unexpected state.")
		}
		if !hasTunnel {
			fmt.Println("Action: CREATE tunnel")
			if !*apply {
				fmt.Println("\n(DRY RUN - Run with --apply to execute)")
				os.Exit(2)
			}
			tunnelID, _ := createTunnel(ctx, client, acctID, *name, *credsFile)
			writeMetadata(*metaFile, tunnelID, *name)
			printNextSteps(tunnelID, *name, *credsFile, *metaFile)
		}
	}
}

// createTunnel creates a new Cloudflare tunnel and encrypts the credentials with sops.
func createTunnel(ctx context.Context, client *cloudflare.Client, accountID, name, credsPath string) (tunnelID, accountTag string) {
	// Generate 32 bytes of random secret
	secretBytes := make([]byte, 32)
	if _, err := rand.Read(secretBytes); err != nil {
		log.Fatalf("Failed to generate tunnel secret: %v", err)
	}
	tunnelSecret := base64.StdEncoding.EncodeToString(secretBytes)

	fmt.Printf("Creating tunnel %q...\n", name)
	tunnel, err := client.ZeroTrust.Tunnels.Cloudflared.New(ctx, zero_trust.TunnelCloudflaredNewParams{
		AccountID:    cloudflare.F(accountID),
		Name:         cloudflare.F(name),
		ConfigSrc:    cloudflare.F(zero_trust.TunnelCloudflaredNewParamsConfigSrcLocal),
		TunnelSecret: cloudflare.F(tunnelSecret),
	})
	if err != nil {
		log.Fatalf("Failed to create tunnel: %v", err)
	}

	fmt.Printf("Tunnel created: %s\n", tunnel.ID)

	// Build credentials JSON
	creds := tunnelCredentials{
		AccountTag:   tunnel.AccountTag,
		TunnelID:     tunnel.ID,
		TunnelSecret: tunnelSecret,
	}
	credsJSON, err := json.MarshalIndent(creds, "", "  ")
	if err != nil {
		log.Fatalf("Failed to marshal credentials: %v", err)
	}

	// Write plaintext then encrypt in-place with sops (binary format for sops-nix compat)
	if err := os.WriteFile(credsPath, credsJSON, 0600); err != nil {
		// Clean up tunnel on failure
		cleanupTunnel(ctx, client, accountID, tunnel.ID)
		log.Fatalf("Failed to write credentials file: %v", err)
	}

	cmd := exec.Command("sops", "-e", "-i", "--input-type", "binary", "--output-type", "binary", credsPath)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		os.Remove(credsPath)
		cleanupTunnel(ctx, client, accountID, tunnel.ID)
		log.Fatalf("Failed to encrypt credentials with sops: %v\n"+
			"Ensure sops/.sops.yaml has a creation_rule for cloudflared-tunnel.json", err)
	}

	fmt.Printf("Encrypted credentials saved to %s\n", credsPath)
	return tunnel.ID, tunnel.AccountTag
}

// cleanupTunnel deletes an orphaned tunnel after a failure.
func cleanupTunnel(ctx context.Context, client *cloudflare.Client, accountID, tunnelID string) {
	fmt.Fprintf(os.Stderr, "Cleaning up: deleting orphaned tunnel %s...\n", tunnelID)
	_, err := client.ZeroTrust.Tunnels.Cloudflared.Delete(ctx, tunnelID, zero_trust.TunnelCloudflaredDeleteParams{
		AccountID: cloudflare.F(accountID),
	})
	if err != nil {
		fmt.Fprintf(os.Stderr, "Warning: failed to clean up tunnel: %v\n", err)
	}
}

// writeMetadata writes the tunnel metadata JSON for Nix eval.
func writeMetadata(path, tunnelID, tunnelName string) {
	meta := tunnelMetadata{
		TunnelID:   tunnelID,
		TunnelName: tunnelName,
	}
	data, err := json.MarshalIndent(meta, "", "  ")
	if err != nil {
		log.Fatalf("Failed to marshal metadata: %v", err)
	}
	data = append(data, '\n')
	if err := os.WriteFile(path, data, 0644); err != nil {
		log.Fatalf("Failed to write metadata file %s: %v", path, err)
	}
	fmt.Printf("Metadata written to %s\n", path)
}

// createTunnelCNAMEs creates or updates CNAME records pointing hostnames to the tunnel.
func createTunnelCNAMEs(ctx context.Context, client *cloudflare.Client, zoneName, tunnelID string, hostnames []string) {
	zoneID, err := resolveZoneID(client, zoneName)
	if err != nil {
		log.Fatalf("Failed to resolve zone: %v", err)
	}

	tunnelTarget := fmt.Sprintf("%s.cfargotunnel.com", tunnelID)
	comment := "managed-by:cf-tunnel"

	// Fetch existing CNAME records
	existingMap := make(map[string]dns.RecordResponse)
	iter := client.DNS.Records.ListAutoPaging(ctx, dns.RecordListParams{
		ZoneID: cloudflare.F(zoneID),
		Type:   cloudflare.F(dns.RecordListParamsTypeCNAME),
	})
	for iter.Next() {
		r := iter.Current()
		existingMap[r.Name] = r
	}
	if err := iter.Err(); err != nil {
		log.Fatalf("Failed to list DNS records: %v", err)
	}

	for _, hostname := range hostnames {
		existing, found := existingMap[hostname]

		if !found {
			fmt.Printf("  CREATE CNAME  %s -> %s\n", hostname, tunnelTarget)
			_, err := client.DNS.Records.New(ctx, dns.RecordNewParams{
				ZoneID: cloudflare.F(zoneID),
				Body: dns.CNAMERecordParam{
					Name:    cloudflare.F(hostname),
					Type:    cloudflare.F(dns.CNAMERecordTypeCNAME),
					Content: cloudflare.F(tunnelTarget),
					TTL:     cloudflare.F(dns.TTL(1)), // automatic
					Proxied: cloudflare.F(true),
					Comment: cloudflare.F(comment),
				},
			})
			if err != nil {
				log.Printf("Error creating CNAME for %s: %v", hostname, err)
			}
		} else if existing.Content != tunnelTarget || !strings.Contains(existing.Comment, "managed-by:cf-tunnel") {
			fmt.Printf("  UPDATE CNAME  %s -> %s\n", hostname, tunnelTarget)
			_, err := client.DNS.Records.Update(ctx, existing.ID, dns.RecordUpdateParams{
				ZoneID: cloudflare.F(zoneID),
				Body: dns.CNAMERecordParam{
					Name:    cloudflare.F(hostname),
					Type:    cloudflare.F(dns.CNAMERecordTypeCNAME),
					Content: cloudflare.F(tunnelTarget),
					TTL:     cloudflare.F(dns.TTL(1)),
					Proxied: cloudflare.F(true),
					Comment: cloudflare.F(comment),
				},
			})
			if err != nil {
				log.Printf("Error updating CNAME for %s: %v", hostname, err)
			}
		} else {
			fmt.Printf("  OK CNAME      %s -> %s\n", hostname, tunnelTarget)
		}
	}
}

func printNextSteps(tunnelID, name, credsFile, metaFile string) {
	fmt.Println()
	fmt.Println("=== Tunnel Provisioned ===")
	fmt.Println()
	fmt.Printf("  Tunnel ID:   %s\n", tunnelID)
	fmt.Printf("  Tunnel Name: %s\n", name)
	fmt.Printf("  Credentials: %s (sops-encrypted)\n", credsFile)
	fmt.Printf("  Metadata:    %s\n", metaFile)
	fmt.Println()
	fmt.Println("=== Next Steps ===")
	fmt.Println()
	fmt.Printf("1. Commit %s and %s\n", metaFile, credsFile)
	fmt.Println("2. Deploy: clan machines update pp-router1")
}

// --- Helpers ---

// multiFlag implements flag.Value for repeatable string flags.
type multiFlag []string

func (f *multiFlag) String() string { return strings.Join(*f, ", ") }
func (f *multiFlag) Set(value string) error {
	*f = append(*f, value)
	return nil
}

func findRepoRoot() string {
	dir, err := os.Getwd()
	if err != nil {
		log.Fatal(err)
	}
	for dir != "/" {
		if _, err := os.Stat(filepath.Join(dir, "flake.nix")); err == nil {
			return dir
		}
		dir = filepath.Dir(dir)
	}
	log.Fatal("Error: Could not find flake.nix in any parent directory")
	return ""
}

func fileExists(path string) bool {
	_, err := os.Stat(path)
	return err == nil
}

func boolToState(exists bool, detail string) string {
	if exists {
		return fmt.Sprintf("FOUND (%s)", detail)
	}
	return "NOT FOUND"
}
