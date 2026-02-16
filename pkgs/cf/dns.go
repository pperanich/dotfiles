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

	cloudflare "github.com/cloudflare/cloudflare-go/v6"
	"github.com/cloudflare/cloudflare-go/v6/dns"
)

// Config represents the JSON configuration structure for DNS sync.
type Config struct {
	Zone    string   `json:"zone"`
	Records []Record `json:"records"`
}

// Record represents a DNS record in the configuration.
type Record struct {
	Type    string `json:"type"`
	Name    string `json:"name"`
	Content string `json:"content"`
	Proxied bool   `json:"proxied"`
	TTL     int    `json:"ttl"`
	Comment string `json:"comment,omitempty"`
}

func dnsListCmd(args []string) {
	fs := flag.NewFlagSet("dns list", flag.ExitOnError)
	zoneName := fs.String("zone", "", "Zone name (overrides CLOUDFLARE_ZONE env var)")
	fs.Parse(args)

	zone := resolveZoneName(*zoneName)
	client := newClient()

	zoneID, err := resolveZoneID(client, zone)
	if err != nil {
		log.Fatal(err)
	}

	ctx := context.Background()
	iter := client.DNS.Records.ListAutoPaging(ctx, dns.RecordListParams{
		ZoneID: cloudflare.F(zoneID),
	})

	fmt.Printf("DNS Records for %s (%s):\n", zone, zoneID)
	fmt.Printf("%-6s %-30s %-40s %-6s %-6s %s\n", "TYPE", "NAME", "CONTENT", "PROXY", "TTL", "MANAGED")

	for iter.Next() {
		r := iter.Current()
		managed := ""
		if strings.Contains(r.Comment, "managed-by:cf-dns") {
			managed = "(managed)"
		}
		fmt.Printf("%-6s %-30s %-40s %-6v %-6.0f %s\n",
			r.Type, r.Name, r.Content, r.Proxied, float64(r.TTL), managed)
	}
	if err := iter.Err(); err != nil {
		log.Fatalf("Failed to list DNS records: %v", err)
	}
}

func dnsSyncCmd(args []string) {
	fs := flag.NewFlagSet("dns sync", flag.ExitOnError)
	configFile := fs.String("config", "", "Path to JSON config file (default: stdin)")
	apply := fs.Bool("apply", false, "Apply changes to Cloudflare")
	zoneOverride := fs.String("zone", "", "Override zone name from config")
	fs.Parse(args)

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
		cfg.Zone = os.Getenv("CLOUDFLARE_ZONE")
	}
	if cfg.Zone == "" {
		log.Fatal("Error: Zone name is required in config, via --zone flag, or CLOUDFLARE_ZONE env var")
	}

	client := newClient()

	zoneID, err := resolveZoneID(client, cfg.Zone)
	if err != nil {
		log.Fatal(err)
	}

	ctx := context.Background()

	// Fetch existing records
	existingMap := make(map[string]dns.RecordResponse)
	iter := client.DNS.Records.ListAutoPaging(ctx, dns.RecordListParams{
		ZoneID: cloudflare.F(zoneID),
	})
	for iter.Next() {
		r := iter.Current()
		key := fmt.Sprintf("%s|%s", r.Type, r.Name)
		existingMap[key] = r
	}
	if err := iter.Err(); err != nil {
		log.Fatalf("Failed to list DNS records: %v", err)
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
				body := makeRecordParam(desired, comment)
				if body == nil {
					log.Printf("Unsupported record type for create: %s", desired.Type)
					continue
				}
				_, err := client.DNS.Records.New(ctx, dns.RecordNewParams{
					ZoneID: cloudflare.F(zoneID),
					Body:   body,
				})
				if err != nil {
					log.Printf("Error creating record %s: %v", desired.Name, err)
				}
			}
		} else {
			// UPDATE check
			needsUpdate := false
			diffs := []string{}

			if existing.Content != desired.Content {
				needsUpdate = true
				diffs = append(diffs, fmt.Sprintf("content: %s -> %s", existing.Content, desired.Content))
			}

			if existing.Proxied != desired.Proxied {
				needsUpdate = true
				diffs = append(diffs, fmt.Sprintf("proxied: %v -> %v", existing.Proxied, desired.Proxied))
			}

			if int(existing.TTL) != desired.TTL {
				needsUpdate = true
				diffs = append(diffs, fmt.Sprintf("ttl: %d -> %d", int(existing.TTL), desired.TTL))
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
					body := makeUpdateRecordParam(desired, comment)
					if body == nil {
						log.Printf("Unsupported record type for update: %s", desired.Type)
						continue
					}
					_, err := client.DNS.Records.Update(ctx, existing.ID, dns.RecordUpdateParams{
						ZoneID: cloudflare.F(zoneID),
						Body:   body,
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

// makeRecordParam constructs the correct typed param for DNS record creation.
func makeRecordParam(r Record, comment string) dns.RecordNewParamsBodyUnion {
	ttl := dns.TTL(r.TTL)

	switch r.Type {
	case "A":
		return dns.ARecordParam{
			Name:    cloudflare.F(r.Name),
			Type:    cloudflare.F(dns.ARecordTypeA),
			Content: cloudflare.F(r.Content),
			TTL:     cloudflare.F(ttl),
			Proxied: cloudflare.F(r.Proxied),
			Comment: cloudflare.F(comment),
		}
	case "AAAA":
		return dns.AAAARecordParam{
			Name:    cloudflare.F(r.Name),
			Type:    cloudflare.F(dns.AAAARecordTypeAAAA),
			Content: cloudflare.F(r.Content),
			TTL:     cloudflare.F(ttl),
			Proxied: cloudflare.F(r.Proxied),
			Comment: cloudflare.F(comment),
		}
	case "CNAME":
		return dns.CNAMERecordParam{
			Name:    cloudflare.F(r.Name),
			Type:    cloudflare.F(dns.CNAMERecordTypeCNAME),
			Content: cloudflare.F(r.Content),
			TTL:     cloudflare.F(ttl),
			Proxied: cloudflare.F(r.Proxied),
			Comment: cloudflare.F(comment),
		}
	case "MX":
		return dns.MXRecordParam{
			Name:    cloudflare.F(r.Name),
			Type:    cloudflare.F(dns.MXRecordTypeMX),
			Content: cloudflare.F(r.Content),
			TTL:     cloudflare.F(ttl),
			Proxied: cloudflare.F(r.Proxied),
			Comment: cloudflare.F(comment),
		}
	case "TXT":
		return dns.TXTRecordParam{
			Name:    cloudflare.F(r.Name),
			Type:    cloudflare.F(dns.TXTRecordTypeTXT),
			Content: cloudflare.F(r.Content),
			TTL:     cloudflare.F(ttl),
			Proxied: cloudflare.F(r.Proxied),
			Comment: cloudflare.F(comment),
		}
	case "SRV":
		return dns.SRVRecordParam{
			Name:    cloudflare.F(r.Name),
			Type:    cloudflare.F(dns.SRVRecordTypeSRV),
			TTL:     cloudflare.F(ttl),
			Proxied: cloudflare.F(r.Proxied),
			Comment: cloudflare.F(comment),
		}
	default:
		return nil
	}
}

// makeUpdateRecordParam constructs the correct typed param for DNS record update.
func makeUpdateRecordParam(r Record, comment string) dns.RecordUpdateParamsBodyUnion {
	ttl := dns.TTL(r.TTL)

	switch r.Type {
	case "A":
		return dns.ARecordParam{
			Name:    cloudflare.F(r.Name),
			Type:    cloudflare.F(dns.ARecordTypeA),
			Content: cloudflare.F(r.Content),
			TTL:     cloudflare.F(ttl),
			Proxied: cloudflare.F(r.Proxied),
			Comment: cloudflare.F(comment),
		}
	case "AAAA":
		return dns.AAAARecordParam{
			Name:    cloudflare.F(r.Name),
			Type:    cloudflare.F(dns.AAAARecordTypeAAAA),
			Content: cloudflare.F(r.Content),
			TTL:     cloudflare.F(ttl),
			Proxied: cloudflare.F(r.Proxied),
			Comment: cloudflare.F(comment),
		}
	case "CNAME":
		return dns.CNAMERecordParam{
			Name:    cloudflare.F(r.Name),
			Type:    cloudflare.F(dns.CNAMERecordTypeCNAME),
			Content: cloudflare.F(r.Content),
			TTL:     cloudflare.F(ttl),
			Proxied: cloudflare.F(r.Proxied),
			Comment: cloudflare.F(comment),
		}
	case "MX":
		return dns.MXRecordParam{
			Name:    cloudflare.F(r.Name),
			Type:    cloudflare.F(dns.MXRecordTypeMX),
			Content: cloudflare.F(r.Content),
			TTL:     cloudflare.F(ttl),
			Proxied: cloudflare.F(r.Proxied),
			Comment: cloudflare.F(comment),
		}
	case "TXT":
		return dns.TXTRecordParam{
			Name:    cloudflare.F(r.Name),
			Type:    cloudflare.F(dns.TXTRecordTypeTXT),
			Content: cloudflare.F(r.Content),
			TTL:     cloudflare.F(ttl),
			Proxied: cloudflare.F(r.Proxied),
			Comment: cloudflare.F(comment),
		}
	case "SRV":
		return dns.SRVRecordParam{
			Name:    cloudflare.F(r.Name),
			Type:    cloudflare.F(dns.SRVRecordTypeSRV),
			TTL:     cloudflare.F(ttl),
			Proxied: cloudflare.F(r.Proxied),
			Comment: cloudflare.F(comment),
		}
	default:
		return nil
	}
}
