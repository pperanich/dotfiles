package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"log"
	"os"
	"sort"
	"strings"

	cloudflare "github.com/cloudflare/cloudflare-go/v6"
	"github.com/cloudflare/cloudflare-go/v6/zero_trust"
)

const accessTag = "managed-by:cf-access"

// AccessConfig is the JSON schema nix generates for `cf access sync`.
type AccessConfig struct {
	Apps []AccessApp `json:"apps"`
}

// AccessApp is one desired self-hosted Access application with an email allowlist.
type AccessApp struct {
	Domain          string   `json:"domain"`
	Name            string   `json:"name"`
	SessionDuration string   `json:"sessionDuration"`
	Emails          []string `json:"emails"`
}

// emailIncludeRules builds an allowlist include block from email addresses.
func emailIncludeRules(emails []string) []zero_trust.AccessRuleUnionParam {
	include := make([]zero_trust.AccessRuleUnionParam, 0, len(emails))
	for _, e := range emails {
		include = append(include, zero_trust.EmailRuleParam{
			Email: cloudflare.F(zero_trust.EmailRuleEmailParam{Email: cloudflare.F(e)}),
		})
	}
	return include
}

// createAccessAppWithPolicy creates a reusable allowlist policy and a self-hosted
// app linking it. The v6.7.0 inline policy union carries no decision/include, so
// the policy is created separately and linked by ID. On app-create failure the
// orphaned policy is rolled back.
func createAccessAppWithPolicy(ctx context.Context, client *cloudflare.Client, acctID, domain, name, sessionDuration string, emails, tags []string) (appID, policyID string, err error) {
	pol, err := client.ZeroTrust.Access.Policies.New(ctx, zero_trust.AccessPolicyNewParams{
		AccountID: cloudflare.F(acctID),
		Decision:  cloudflare.F(zero_trust.DecisionAllow),
		Name:      cloudflare.F(name + " allowlist"),
		Include:   cloudflare.F(emailIncludeRules(emails)),
	})
	if err != nil {
		return "", "", fmt.Errorf("create policy: %w", err)
	}

	body := zero_trust.AccessApplicationNewParamsBodySelfHostedApplication{
		Domain:          cloudflare.F(domain),
		Type:            cloudflare.F(zero_trust.ApplicationTypeSelfHosted),
		Name:            cloudflare.F(name),
		SessionDuration: cloudflare.F(sessionDuration),
		Policies: cloudflare.F([]zero_trust.AccessApplicationNewParamsBodySelfHostedApplicationPolicyUnion{
			zero_trust.AccessApplicationNewParamsBodySelfHostedApplicationPoliciesAccessAppPolicyLink{
				ID: cloudflare.F(pol.ID),
			},
		}),
	}
	if len(tags) > 0 {
		body.Tags = cloudflare.F(tags)
	}

	app, err := client.ZeroTrust.Access.Applications.New(ctx, zero_trust.AccessApplicationNewParams{
		AccountID: cloudflare.F(acctID),
		Body:      body,
	})
	if err != nil {
		if _, delErr := client.ZeroTrust.Access.Policies.Delete(ctx, pol.ID, zero_trust.AccessPolicyDeleteParams{
			AccountID: cloudflare.F(acctID),
		}); delErr != nil {
			fmt.Fprintf(os.Stderr, "Warning: failed to clean up policy %s: %v\n", pol.ID, delErr)
		}
		return "", "", fmt.Errorf("create application: %w", err)
	}
	return app.ID, pol.ID, nil
}

// managedAccessApp is the flattened view of a self-hosted Access app we care about.
type managedAccessApp struct {
	id              string
	domain          string
	name            string
	sessionDuration string
	tags            []string
	policyID        string
	emails          []string
}

func (m managedAccessApp) managed() bool {
	for _, t := range m.tags {
		if t == accessTag {
			return true
		}
	}
	return false
}

// listSelfHostedApps returns self-hosted apps keyed by domain, pulling the first
// policy's allowlist emails so drift can be detected.
func listSelfHostedApps(ctx context.Context, client *cloudflare.Client, acctID string) (map[string]managedAccessApp, error) {
	apps := make(map[string]managedAccessApp)
	iter := client.ZeroTrust.Access.Applications.ListAutoPaging(ctx, zero_trust.AccessApplicationListParams{
		AccountID: cloudflare.F(acctID),
	})
	for iter.Next() {
		raw := iter.Current()
		if raw.Type != zero_trust.ApplicationTypeSelfHosted {
			continue
		}
		sh, ok := raw.AsUnion().(zero_trust.AccessApplicationListResponseSelfHostedApplication)
		if !ok {
			continue
		}
		m := managedAccessApp{
			id:              sh.ID,
			domain:          sh.Domain,
			name:            sh.Name,
			sessionDuration: sh.SessionDuration,
			tags:            sh.Tags,
		}
		// Use the first policy as the allowlist we manage.
		if len(sh.Policies) > 0 {
			p := sh.Policies[0]
			m.policyID = p.ID
			m.emails = policyEmails(p.Include)
		}
		apps[sh.Domain] = m
	}
	if err := iter.Err(); err != nil {
		return nil, fmt.Errorf("list applications: %w", err)
	}
	return apps, nil
}

// policyEmails extracts allowlisted addresses from a policy's include rules.
func policyEmails(include []zero_trust.AccessRule) []string {
	var out []string
	for _, r := range include {
		if er, ok := r.AsUnion().(zero_trust.EmailRule); ok {
			out = append(out, er.Email.Email)
		}
	}
	return out
}

// emailsEqual compares two email sets order-insensitively.
func emailsEqual(a, b []string) bool {
	if len(a) != len(b) {
		return false
	}
	as := append([]string(nil), a...)
	bs := append([]string(nil), b...)
	sort.Strings(as)
	sort.Strings(bs)
	for i := range as {
		if !strings.EqualFold(as[i], bs[i]) {
			return false
		}
	}
	return true
}

func accessListCmd(args []string) {
	fs := flag.NewFlagSet("access list", flag.ExitOnError)
	accountID := fs.String("account-id", "", "Cloudflare account ID (overrides CLOUDFLARE_ACCOUNT_ID)")
	fs.Parse(args)

	acctID := resolveAccountID(*accountID)
	client := newClient()
	ctx := context.Background()

	apps, err := listSelfHostedApps(ctx, client, acctID)
	if err != nil {
		log.Fatal(err)
	}

	domains := make([]string, 0, len(apps))
	for d := range apps {
		domains = append(domains, d)
	}
	sort.Strings(domains)

	fmt.Printf("Self-hosted Access applications for %s:\n", acctID)
	fmt.Printf("%-40s %-8s %s\n", "DOMAIN", "MANAGED", "EMAILS")
	for _, d := range domains {
		app := apps[d]
		managed := ""
		if app.managed() {
			managed = "(managed)"
		}
		fmt.Printf("%-40s %-8s %s\n", d, managed, strings.Join(app.emails, ", "))
	}
}

func accessSyncCmd(args []string) {
	fs := flag.NewFlagSet("access sync", flag.ExitOnError)
	configFile := fs.String("config", "", "Path to JSON config file (default: stdin)")
	apply := fs.Bool("apply", false, "Apply changes to Cloudflare")
	prune := fs.Bool("prune", false, "Delete managed apps (managed-by:cf-access) absent from config")
	accountID := fs.String("account-id", "", "Cloudflare account ID (overrides CLOUDFLARE_ACCOUNT_ID)")
	fs.Parse(args)

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

	var cfg AccessConfig
	if err := json.Unmarshal(configData, &cfg); err != nil {
		log.Fatalf("Failed to parse JSON config: %v", err)
	}

	acctID := resolveAccountID(*accountID)
	client := newClient()
	ctx := context.Background()

	existing, err := listSelfHostedApps(ctx, client, acctID)
	if err != nil {
		log.Fatal(err)
	}

	created := 0
	updated := 0
	unchanged := 0
	deleted := 0
	changesNeeded := false

	fmt.Printf("Syncing Access applications for %s...\n", acctID)
	if !*apply {
		fmt.Println("(DRY RUN - No changes will be applied)")
	}

	desiredDomains := make(map[string]bool)
	for _, d := range cfg.Apps {
		name := d.Name
		if name == "" {
			name = "cf-access: " + d.Domain
		}
		sessionDuration := d.SessionDuration
		if sessionDuration == "" {
			sessionDuration = "24h"
		}
		desiredDomains[d.Domain] = true

		app, found := existing[d.Domain]

		if !found {
			fmt.Printf("  CREATE  %-40s (%d emails)\n", d.Domain, len(d.Emails))
			created++
			changesNeeded = true
			if *apply {
				if _, _, err := createAccessAppWithPolicy(ctx, client, acctID, d.Domain, name, sessionDuration, d.Emails, []string{accessTag}); err != nil {
					log.Printf("Error creating app %s: %v", d.Domain, err)
				}
			}
			continue
		}

		if !app.managed() {
			fmt.Printf("  SKIP    %-40s (unmanaged)\n", d.Domain)
			continue
		}

		// Drift check on allowlist emails and session duration.
		diffs := []string{}
		if !emailsEqual(app.emails, d.Emails) {
			diffs = append(diffs, fmt.Sprintf("emails: %d -> %d", len(app.emails), len(d.Emails)))
		}
		if app.sessionDuration != sessionDuration {
			diffs = append(diffs, fmt.Sprintf("session: %s -> %s", app.sessionDuration, sessionDuration))
		}

		if len(diffs) == 0 {
			fmt.Printf("  OK      %-40s (%d emails)\n", d.Domain, len(d.Emails))
			unchanged++
			continue
		}

		fmt.Printf("  UPDATE  %-40s (%s)\n", d.Domain, strings.Join(diffs, ", "))
		updated++
		changesNeeded = true
		if *apply {
			if err := updateManagedApp(ctx, client, acctID, app, name, sessionDuration, d.Emails); err != nil {
				log.Printf("Error updating app %s: %v", d.Domain, err)
			}
		}
	}

	// Prune managed apps whose domain is gone from config. Sorted for stable output.
	if *prune {
		staleDomains := []string{}
		for domain, app := range existing {
			if !desiredDomains[domain] && app.managed() {
				staleDomains = append(staleDomains, domain)
			}
		}
		sort.Strings(staleDomains)
		for _, domain := range staleDomains {
			app := existing[domain]
			fmt.Printf("  DELETE  %-40s (stale managed app)\n", domain)
			deleted++
			changesNeeded = true
			if *apply {
				if _, err := client.ZeroTrust.Access.Applications.Delete(ctx, app.id, zero_trust.AccessApplicationDeleteParams{
					AccountID: cloudflare.F(acctID),
				}); err != nil {
					log.Printf("Error deleting app %s: %v", domain, err)
					continue
				}
				if app.policyID != "" {
					if _, err := client.ZeroTrust.Access.Policies.Delete(ctx, app.policyID, zero_trust.AccessPolicyDeleteParams{
						AccountID: cloudflare.F(acctID),
					}); err != nil {
						log.Printf("Error deleting policy for %s: %v", domain, err)
					}
				}
			}
		}
	}

	fmt.Printf("\nSummary: %d create, %d update, %d unchanged, %d delete\n", created, updated, unchanged, deleted)

	if !*apply {
		fmt.Println("Run with --apply to execute changes.")
		if changesNeeded {
			os.Exit(2)
		}
	}
}

// updateManagedApp reconciles a managed app's allowlist and session duration.
// The policy include-rules are updated in place when the app already has a policy;
// otherwise a fresh policy is created and linked (app config is never dropped).
func updateManagedApp(ctx context.Context, client *cloudflare.Client, acctID string, app managedAccessApp, name, sessionDuration string, emails []string) error {
	policyID := app.policyID
	if policyID == "" {
		pol, err := client.ZeroTrust.Access.Policies.New(ctx, zero_trust.AccessPolicyNewParams{
			AccountID: cloudflare.F(acctID),
			Decision:  cloudflare.F(zero_trust.DecisionAllow),
			Name:      cloudflare.F(name + " allowlist"),
			Include:   cloudflare.F(emailIncludeRules(emails)),
		})
		if err != nil {
			return fmt.Errorf("create policy: %w", err)
		}
		policyID = pol.ID
	} else {
		if _, err := client.ZeroTrust.Access.Policies.Update(ctx, policyID, zero_trust.AccessPolicyUpdateParams{
			AccountID: cloudflare.F(acctID),
			Decision:  cloudflare.F(zero_trust.DecisionAllow),
			Name:      cloudflare.F(name + " allowlist"),
			Include:   cloudflare.F(emailIncludeRules(emails)),
		}); err != nil {
			return fmt.Errorf("update policy: %w", err)
		}
	}

	_, err := client.ZeroTrust.Access.Applications.Update(ctx, app.id, zero_trust.AccessApplicationUpdateParams{
		AccountID: cloudflare.F(acctID),
		Body: zero_trust.AccessApplicationUpdateParamsBodySelfHostedApplication{
			Domain:          cloudflare.F(app.domain),
			Type:            cloudflare.F(zero_trust.ApplicationTypeSelfHosted),
			Name:            cloudflare.F(name),
			SessionDuration: cloudflare.F(sessionDuration),
			Tags:            cloudflare.F([]string{accessTag}),
			Policies: cloudflare.F([]zero_trust.AccessApplicationUpdateParamsBodySelfHostedApplicationPolicyUnion{
				zero_trust.AccessApplicationUpdateParamsBodySelfHostedApplicationPoliciesAccessAppPolicyLink{
					ID: cloudflare.F(policyID),
				},
			}),
		},
	})
	if err != nil {
		return fmt.Errorf("update application: %w", err)
	}
	return nil
}
