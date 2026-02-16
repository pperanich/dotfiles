# Service Exposure Pathways

Services in this infrastructure are exposed through two primary pathways: a private pathway for secure, high-performance local access and a public pathway for convenient access from anywhere without a VPN.

| Pathway     | Transport         | Access From    | DNS                     | Reverse Proxy | WAN Ports |
| ----------- | ----------------- | -------------- | ----------------------- | ------------- | --------- |
| **Private** | Caddy + LAN/WG    | LAN, WireGuard | Cloudflare (Private IP) | Caddy         | None      |
| **Public**  | Cloudflare Tunnel | Internet       | Cloudflare (CNAME)      | cloudflared   | None      |

## Private Pathway (Caddy + LAN/WG)

The private pathway is the primary method for accessing administrative interfaces and high-bandwidth services. It relies on Caddy acting as a reverse proxy that is only accessible from the local network or via WireGuard.

### How it works

- **Binding**: Caddy binds to the LAN IP (10.0.0.1) and the WireGuard interface address.
- **TLS**: Certificates are obtained via the DNS-01 challenge, allowing for valid HTTPS even on a private network without opening port 80.
- **DNS**: Managed via the `cloudflareDns` module, which uses `cf dns sync` to create A/AAAA records pointing to private internal IPs.

### When to use

- Administrative panels (Router, NAS, Unifi)
- Monitoring tools (ntopng)
- High-bandwidth services (Immich, Nextcloud)
- Services containing sensitive data that should never be public

### Steps to add a private service

1. Define a Caddy `virtualHost` in the relevant Nix module.
2. Add a `cloudflareDns` record pointing the subdomain to the internal IP.
3. Add an entry to the `homepage` dashboard for easy access.

## Public Pathway (Cloudflare Tunnel)

The public pathway provides access to select services from the public internet without requiring a VPN or opening any ports on the WAN interface.

### How it works

- **Connection**: The `cloudflared` daemon establishes an outbound connection to Cloudflare's edge.
- **Security**: No inbound WAN ports are required. Traffic is proxied through Cloudflare.
- **DNS**: A CNAME record points the desired subdomain to the `cfargotunnel.com` address associated with the tunnel.

### When to use

- Mobile access when a VPN is inconvenient
- Public-facing websites
- Password managers (Vaultwarden)
- Sharing specific services with external users

### Steps to add a public service

1. Add an `ingress` entry to the `cloudflareTunnel` configuration.
2. Create a CNAME record in Cloudflare pointing to the tunnel URL.
3. (Optional) Configure Caddy for fast local access (Hybrid).

## Hybrid (Dual-Path) Services

Some services benefit from being available on both pathways. This provides the convenience of public access with the performance and security of local access when on the network.

| Service         | Access Path     | Latency | Security            |
| --------------- | --------------- | ------- | ------------------- |
| **Vaultwarden** | Public (Tunnel) | Medium  | Cloudflare Auth/WAF |
| **Vaultwarden** | Private (Caddy) | Low     | LAN/WG Only         |

> **Note:** Administrative panels and highly sensitive services are strictly restricted to the private path only.

## One-Time Setup: Cloudflare Tunnel

Provisioning a Cloudflare Tunnel is a **one-time, manual step** required before deploying any machine that uses the public pathway. It cannot be fully automated within Nix because the upstream `services.cloudflared` module needs the tunnel UUID at **Nix evaluation time** — it's used as an attrset key for the systemd service name, credential path, and cloudflared config. Since Nix evaluation is pure, it can't make API calls, so the UUID must exist as a committed file before `nixos-rebuild` runs.

The `cf` CLI tool automates this provisioning step.

### What it produces

| File                   | Location                         | Contents                         | Committed as                   |
| ---------------------- | -------------------------------- | -------------------------------- | ------------------------------ |
| **Tunnel metadata**    | `machines/<host>/cf-tunnel.json` | Tunnel UUID + name               | Plaintext (no secrets)         |
| **Tunnel credentials** | `sops/cloudflared-tunnel.json`   | Account tag, UUID, tunnel secret | sops-encrypted (binary format) |

The metadata file sits next to `configuration.nix` so it can be read with a relative path:

```nix
tunnelMeta = builtins.fromJSON (builtins.readFile ./cf-tunnel.json);
# → { tunnelId = "abc12345-..."; tunnelName = "homelab"; }
```

A nil-UUID placeholder (`00000000-...`) is committed initially. An assertion in `cloudflare-tunnel.nix` will block any build that still has the placeholder, reminding you to run the provisioning step.

### Prerequisites

- `CLOUDFLARE_API_TOKEN` — API token with **Tunnel:Edit** and **DNS:Edit** permissions
- `CLOUDFLARE_ACCOUNT_ID` — your Cloudflare account ID
- `sops` configured with a creation rule matching `cloudflared-tunnel.json` in `sops/.sops.yaml`
- The `cf` tool (available in the devshell via `nix develop`)

### Steps

```bash
# 1. Enter the devshell (provides cf + sops)
nix develop

# 2. Export credentials (both are REQUIRED — tunnel sync will fail without them)
export CLOUDFLARE_API_TOKEN="your-token"
export CLOUDFLARE_ACCOUNT_ID="your-account-id"  # Found in Cloudflare dashboard: Account Home → Overview (right sidebar)

# 3. Dry run — shows what would be created
cf tunnel sync \
  --name homelab \
  --hostname vault.prestonperanich.com \
  --zone prestonperanich.com

# 4. Apply — creates tunnel, encrypts creds, writes metadata, creates CNAME
cf tunnel sync \
  --name homelab \
  --hostname vault.prestonperanich.com \
  --zone prestonperanich.com \
  --apply

# 5. Commit both generated files
git add machines/pp-router1/cf-tunnel.json sops/cloudflared-tunnel.json
git commit -m "feat: provision cloudflare tunnel"

# 6. Deploy
clan machines update pp-router1
```

### Re-running is safe

`cf tunnel sync` is idempotent. If the tunnel already exists and matches, it reports "Nothing to do." Pass additional `--hostname` flags to create new CNAME records for the same tunnel.

### Recovery scenarios

| Situation                               | What happens                                                                 |
| --------------------------------------- | ---------------------------------------------------------------------------- |
| Tunnel exists, metadata + creds present | Verifies match, updates CNAMEs if needed                                     |
| Tunnel exists, metadata missing         | Reconstructs metadata from API                                               |
| Tunnel exists, creds missing            | **FATAL** — tunnel secret can't be recovered. Delete tunnel and re-provision |
| No tunnel, stale metadata + creds       | Requires `--force` to overwrite and re-create                                |

### Secrets

- **Tunnel Credentials** (`sops/cloudflared-tunnel.json`): sops-encrypted, binary format. Contains the tunnel secret needed by cloudflared at runtime. Decrypted on the target machine by sops-nix.
- **API Token** (`sops/secrets.yaml`): Used by the `cf-dns` systemd service for DNS record management.
- **Tunnel Metadata** (`machines/<host>/cf-tunnel.json`): Plaintext. Contains only the tunnel UUID and name — no secrets. Read by Nix at eval time.

## Architecture Diagram

```text
      [ Internet ]          [ LAN / WireGuard ]
           |                        |
           v                        |
  [ Cloudflare Edge ]               |
           |                        |
    (Outbound Tunnel)               |
           |                        |
           v                        v
    [ cloudflared ] <------> [ Caddy Proxy ]
           |                        |
           +-----------+------------+
                       |
                       v
                [ Localhost ]
           (Service A, Service B, ...)
```

## Decision Matrix

| Criterion       | Private Pathway | Public Pathway | Hybrid |
| --------------- | --------------- | -------------- | ------ |
| Admin Panel     | Yes             | No             | No     |
| Mobile (No VPN) | No              | Yes            | Yes    |
| High Bandwidth  | Yes             | No             | Yes    |
| Public Sharing  | No              | Yes            | No     |
| Max Security    | Yes             | Medium         | Medium |

## Configuration Reference

### Private: Caddy virtualHost pattern

```nix
services.caddy.virtualHosts."service.prestonperanich.com".extraConfig = ''
  reverse_proxy http://127.0.0.1:8080
'';
```

### Private: cloudflareDns pattern

```nix
my.cloudflareDns.records = [
  { name = "service.example.com"; content = "10.0.0.1"; type = "A"; }
];
```

### Public: cloudflareTunnel.ingress pattern

```nix
my.cloudflareTunnel.ingress = {
  "service.example.com" = "http://localhost:8080";
};
```

## Current Services

| Service     | Pathway | Host       | Port  |
| ----------- | ------- | ---------- | ----- |
| ntopng      | Private | pp-router1 | :3000 |
| unifi       | Private | pp-router1 | :8443 |
| homepage    | Private | pp-router1 | :8082 |
| vaultwarden | Hybrid  | pp-router1 | :8222 |
| nextcloud   | Private | pp-nas1    | :80   |
| opencloud   | Private | pp-nas1    | :9200 |
| immich      | Private | pp-nas1    | :2283 |
