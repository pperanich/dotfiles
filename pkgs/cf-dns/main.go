package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"log"
	"os"
	"strings"

	"github.com/cloudflare/cloudflare-go"
)

// Config represents the JSON configuration structure
type Config struct {
	Zone    string   `json:"zone"`
	Records []Record `json:"records"`
}

// Record represents a DNS record in the configuration
type Record struct {
	Type    string `json:"type"`
	Name    string `json:"name"`
	Content string `json:"content"`
	Proxied bool   `json:"proxied"`
	TTL     int    `json:"ttl"`
	Comment string `json:"comment,omitempty"`
}

func main() {
	if len(os.Args) < 2 {
		fmt.Println("Usage: cf-dns <command> [args]")
		fmt.Println("Commands: sync, list")
		os.Exit(1)
	}

	switch os.Args[1] {
	case "sync":
		syncCmd()
	case "list":
		listCmd()
	default:
		fmt.Printf("Unknown command: %s\n", os.Args[1])
		os.Exit(1)
	}
}

func getAPI() (*cloudflare.API, error) {
	token := os.Getenv("CLOUDFLARE_API_TOKEN")
	if token == "" {
		return nil, fmt.Errorf("CLOUDFLARE_API_TOKEN environment variable is required")
	}
	return cloudflare.NewWithAPIToken(token)
}

func getZoneID(api *cloudflare.API, zoneName string) (string, error) {
	id, err := api.ZoneIDByName(zoneName)
	if err != nil {
		return "", fmt.Errorf("failed to find zone ID for %s: %w", zoneName, err)
	}
	return id, nil
}

func listCmd() {
	listFlags := flag.NewFlagSet("list", flag.ExitOnError)
	zoneName := listFlags.String("zone", "", "Zone name (overrides CLOUDFLARE_ZONE env var)")
	listFlags.Parse(os.Args[2:])

	if *zoneName == "" {
		*zoneName = os.Getenv("CLOUDFLARE_ZONE")
	}
	if *zoneName == "" {
		fmt.Println("Error: Zone name is required via --zone or CLOUDFLARE_ZONE env var")
		os.Exit(1)
	}

	api, err := getAPI()
	if err != nil {
		log.Fatal(err)
	}

	zoneID, err := getZoneID(api, *zoneName)
	if err != nil {
		log.Fatal(err)
	}

	// Fetch all records
	recs, _, err := api.ListDNSRecords(context.Background(), cloudflare.ZoneIdentifier(zoneID), cloudflare.ListDNSRecordsParams{})
	if err != nil {
		log.Fatalf("Failed to list DNS records: %v", err)
	}

	fmt.Printf("DNS Records for %s (%s):\n", *zoneName, zoneID)
	fmt.Printf("%-6s %-30s %-40s %-6s %-6s %s\n", "TYPE", "NAME", "CONTENT", "PROXY", "TTL", "MANAGED")
	for _, r := range recs {
		managed := ""
		if strings.Contains(r.Comment, "managed-by:cf-dns") {
			managed = "(managed)"
		}
		proxied := "false"
		if r.Proxied != nil && *r.Proxied {
			proxied = "true"
		}
		fmt.Printf("%-6s %-30s %-40s %-6s %-6d %s\n", r.Type, r.Name, r.Content, proxied, r.TTL, managed)
	}
}

func syncCmd() {
	syncFlags := flag.NewFlagSet("sync", flag.ExitOnError)
	configFile := syncFlags.String("config", "", "Path to JSON config file (default: stdin)")
	apply := syncFlags.Bool("apply", false, "Apply changes to Cloudflare")
	zoneOverride := syncFlags.String("zone", "", "Override zone name from config")
	syncFlags.Parse(os.Args[2:])

	// Read config
	var configData []byte
	var err error
	if *configFile != "" {
		configData, err = os.ReadFile(*configFile)
		if err != nil {
			log.Fatalf("Failed to read config file: %v", err)
		}
	} else {
		configData, err = io.ReadAll(os.Stdin)
		if err != nil {
			log.Fatalf("Failed to read from stdin: %v", err)
		}
	}

	var cfg Config
	if err := json.Unmarshal(configData, &cfg); err != nil {
		log.Fatalf("Failed to parse JSON config: %v", err)
	}

	if *zoneOverride != "" {
		cfg.Zone = *zoneOverride
	}

	if cfg.Zone == "" {
		log.Fatal("Error: Zone name is required in config or via --zone flag")
	}

	api, err := getAPI()
	if err != nil {
		log.Fatal(err)
	}

	zoneID, err := getZoneID(api, cfg.Zone)
	if err != nil {
		log.Fatal(err)
	}

	// Fetch existing records
	existingRecs, _, err := api.ListDNSRecords(context.Background(), cloudflare.ZoneIdentifier(zoneID), cloudflare.ListDNSRecordsParams{})
	if err != nil {
		log.Fatalf("Failed to list DNS records: %v", err)
	}

	// Map existing records by type+name for easy lookup
	// Note: Cloudflare allows multiple records with same name/type (e.g. multiple A records for round-robin)
	// But for this simple sync tool, we'll assume unique name+type or handle duplicates carefully.
	// The requirement says: "Find matching existing record by (type, name) tuple".
	// If there are multiple, we might have an issue. Let's assume 1:1 mapping for now or pick the first one.
	existingMap := make(map[string]cloudflare.DNSRecord)
	for _, r := range existingRecs {
		key := fmt.Sprintf("%s|%s", r.Type, r.Name)
		existingMap[key] = r
	}

	created := 0
	updated := 0
	unchanged := 0
	changesNeeded := false

	fmt.Printf("Syncing DNS records for %s (%s)...\n", cfg.Zone, zoneID)
	if !*apply {
		fmt.Println("(DRY RUN - No changes will be applied)")
	}

	for _, desired := range cfg.Records {
		key := fmt.Sprintf("%s|%s", desired.Type, desired.Name)
		existing, found := existingMap[key]

		comment := "managed-by:cf-dns"

		if !found {
			// CREATE
			fmt.Printf("  CREATE  %-6s %-30s -> %s (ttl=%d)\n", desired.Type, desired.Name, desired.Content, desired.TTL)
			created++
			changesNeeded = true
			if *apply {
				_, err := api.CreateDNSRecord(context.Background(), cloudflare.ZoneIdentifier(zoneID), cloudflare.CreateDNSRecordParams{
					Type:    desired.Type,
					Name:    desired.Name,
					Content: desired.Content,
					TTL:     desired.TTL,
					Proxied: &desired.Proxied,
					Comment: comment,
				})
				if err != nil {
					log.Printf("Error creating record %s: %v", desired.Name, err)
				}
			}
		} else {
			// UPDATE check
			// Compare content, proxied, ttl
			// Note: Cloudflare might normalize content (e.g. IPv6). We compare as string.

			needsUpdate := false
			diffs := []string{}

			if existing.Content != desired.Content {
				needsUpdate = true
				diffs = append(diffs, fmt.Sprintf("content: %s -> %s", existing.Content, desired.Content))
			}

			existingProxied := false
			if existing.Proxied != nil {
				existingProxied = *existing.Proxied
			}
			if existingProxied != desired.Proxied {
				needsUpdate = true
				diffs = append(diffs, fmt.Sprintf("proxied: %v -> %v", existingProxied, desired.Proxied))
			}

			if existing.TTL != desired.TTL {
				needsUpdate = true
				diffs = append(diffs, fmt.Sprintf("ttl: %d -> %d", existing.TTL, desired.TTL))
			}

			// Also update if comment is missing or different (to ensure managed tag)
			if !strings.Contains(existing.Comment, "managed-by:cf-dns") {
				needsUpdate = true
				diffs = append(diffs, "adding managed tag")
			}

			if needsUpdate {
				fmt.Printf("  UPDATE  %-6s %-30s -> %s (%s)\n", desired.Type, desired.Name, desired.Content, strings.Join(diffs, ", "))
				updated++
				changesNeeded = true
				if *apply {
					_, err := api.UpdateDNSRecord(context.Background(), cloudflare.ZoneIdentifier(zoneID), cloudflare.UpdateDNSRecordParams{
						ID:      existing.ID,
						Type:    desired.Type,
						Name:    desired.Name,
						Content: desired.Content,
						TTL:     desired.TTL,
						Proxied: &desired.Proxied,
						Comment: &comment,
					})
					if err != nil {
						log.Printf("Error updating record %s: %v", desired.Name, err)
					}
				}
			} else {
				fmt.Printf("  OK      %-6s %-30s -> %s (ttl=%d)\n", desired.Type, desired.Name, desired.Content, desired.TTL)
				unchanged++
			}
		}
	}

	fmt.Printf("\nSummary: %d create, %d update, %d unchanged\n", created, updated, unchanged)

	if !*apply {
		fmt.Println("Run with --apply to execute changes.")
		if changesNeeded {
			os.Exit(2)
		}
	}
}
