package main

import (
	"context"
	"fmt"
	"os"
	"strings"

	cloudflare "github.com/cloudflare/cloudflare-go/v6"
	"github.com/cloudflare/cloudflare-go/v6/option"
	"github.com/cloudflare/cloudflare-go/v6/zones"
)

func main() {
	if len(os.Args) < 2 {
		printUsage()
		os.Exit(1)
	}

	switch os.Args[1] {
	case "dns":
		if len(os.Args) < 3 {
			fmt.Println("Usage: cf dns <sync|list>")
			os.Exit(1)
		}
		switch os.Args[2] {
		case "sync":
			dnsSyncCmd(os.Args[3:])
		case "list":
			dnsListCmd(os.Args[3:])
		default:
			fmt.Printf("Unknown dns command: %s\n", os.Args[2])
			os.Exit(1)
		}
	case "tunnel":
		if len(os.Args) < 3 {
			fmt.Println("Usage: cf tunnel <sync|list>")
			os.Exit(1)
		}
		switch os.Args[2] {
		case "sync":
			tunnelSyncCmd(os.Args[3:])
		case "list":
			tunnelListCmd(os.Args[3:])
		default:
			fmt.Printf("Unknown tunnel command: %s\n", os.Args[2])
			os.Exit(1)
		}
	default:
		fmt.Printf("Unknown command: %s\n", os.Args[1])
		printUsage()
		os.Exit(1)
	}
}

func printUsage() {
	fmt.Println("Usage: cf <command> <subcommand> [options]")
	fmt.Println()
	fmt.Println("Commands:")
	fmt.Println("  dns sync     Sync DNS records from config to Cloudflare")
	fmt.Println("  dns list     List DNS records for a zone")
	fmt.Println("  tunnel sync  Provision/sync a Cloudflare Tunnel")
	fmt.Println("  tunnel list  List Cloudflare Tunnels")
	fmt.Println()
	fmt.Println("Environment:")
	fmt.Println("  CLOUDFLARE_API_TOKEN   API token (required)")
	fmt.Println("  CLOUDFLARE_ACCOUNT_ID  Account ID (required for tunnel commands)")
	fmt.Println("  CLOUDFLARE_ZONE        Default zone name")
}

// newClient creates a Cloudflare API client using the CLOUDFLARE_API_TOKEN env var.
func newClient() *cloudflare.Client {
	token := os.Getenv("CLOUDFLARE_API_TOKEN")
	if token == "" {
		fmt.Fprintln(os.Stderr, "Error: CLOUDFLARE_API_TOKEN environment variable is required")
		os.Exit(1)
	}
	return cloudflare.NewClient(option.WithAPIToken(token))
}

// resolveZoneID looks up a zone ID by name using the v6 API.
func resolveZoneID(client *cloudflare.Client, zoneName string) (string, error) {
	ctx := context.Background()
	iter := client.Zones.ListAutoPaging(ctx, zones.ZoneListParams{
		Name: cloudflare.F(zoneName),
	})
	for iter.Next() {
		zone := iter.Current()
		if strings.EqualFold(zone.Name, zoneName) {
			return zone.ID, nil
		}
	}
	if err := iter.Err(); err != nil {
		return "", fmt.Errorf("failed to list zones: %w", err)
	}
	return "", fmt.Errorf("zone %q not found", zoneName)
}

// resolveZoneName returns the zone name from flag or env, or exits.
func resolveZoneName(flagValue string) string {
	if flagValue != "" {
		return flagValue
	}
	envVal := os.Getenv("CLOUDFLARE_ZONE")
	if envVal != "" {
		return envVal
	}
	fmt.Fprintln(os.Stderr, "Error: Zone name is required via --zone or CLOUDFLARE_ZONE env var")
	os.Exit(1)
	return ""
}

// resolveAccountID returns the account ID from flag or env, or exits.
func resolveAccountID(flagValue string) string {
	if flagValue != "" {
		return flagValue
	}
	envVal := os.Getenv("CLOUDFLARE_ACCOUNT_ID")
	if envVal != "" {
		return envVal
	}
	fmt.Fprintln(os.Stderr, "Error: Account ID is required via --account-id or CLOUDFLARE_ACCOUNT_ID env var")
	os.Exit(1)
	return ""
}
