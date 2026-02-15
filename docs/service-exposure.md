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
- **DNS**: Managed via the `cf-dns` module, which creates A/AAAA records pointing to private internal IPs.

### When to use

- Administrative panels (Router, NAS, Unifi)
- Monitoring tools (ntopng)
- High-bandwidth services (Immich, Nextcloud)
- Services containing sensitive data that should never be public

### Steps to add a private service

1. Define a Caddy `virtualHost` in the relevant Nix module.
2. Add a `cf-dns` record pointing the subdomain to the internal IP.
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

Setting up a new tunnel requires a one-time manual process to link the local daemon with the Cloudflare account.

### Prerequisites

- A Cloudflare account with a configured domain
- The `cloudflared` CLI installed

### Steps

1. **Login**: Run `cloudflared tunnel login` to authenticate.
2. **Create**: Run `cloudflared tunnel create <name>` to generate the tunnel and credentials file.
3. **Encrypt**: Move the credentials JSON to `sops/cloudflared-tunnel.json` and ensure it is encrypted.
4. **Configure**: Set the `tunnelId` in the Nix configuration.
5. **DNS**: Create a CNAME record for the tunnel apex.

### Secrets

- **Tunnel Credentials**: Stored in `sops/cloudflared-tunnel.json`.
- **API Token**: Stored in `sops/secrets.yaml` for DNS record management.

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

### Private: cf-dns pattern

```nix
features.cf-dns.records = [
  { name = "service"; value = "10.0.0.1"; type = "A"; }
];
```

### Public: cloudflareTunnel.ingress pattern

```nix
features.cloudflareTunnel.ingress = {
  "service.prestonperanich.com" = "http://localhost:8080";
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
