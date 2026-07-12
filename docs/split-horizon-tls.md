# Split-Horizon TLS Routing for NAS Services

How `*.prestonperanich.com` service names route clients over the best path for
their network, with TLS on every wire segment.

## The problem this solves

NAS-hosted services (jellyfin, immich, nextcloud, ...) were originally reachable
only through Caddy on pp-router1. That had two costs:

1. **Hairpin bandwidth**: a LAN client streaming from the NAS sent every byte
   client → switch → router → switch → NAS and back. The 10G trunk carried all
   traffic twice.
2. **Plaintext backend hop**: the router terminated TLS, then proxied to the
   NAS over plain HTTP across the trunk.

The direct alternative (`pp-nas1.home.arpa:8096`) avoided the hairpin but was
plaintext end-to-end and used a different name than everywhere else.

## The solution

One name per service, resolved differently depending on where the client sits,
with a Caddy instance on both the router and the NAS holding valid Let's
Encrypt certificates for the same names (DNS-01 makes this possible; issuance
never depends on where the name points).

| Client                               | Resolver               | Answer                              | Path                                                                                    |
| ------------------------------------ | ---------------------- | ----------------------------------- | --------------------------------------------------------------------------------------- |
| LAN device                           | router DNS (from DHCP) | `A 10.0.0.105` (Unbound local-data) | direct to NAS Caddy through the switch. No hairpin, TLS terminates at the NAS.          |
| WireGuard phone                      | public DNS             | `AAAA <wg-prefix>::1`               | tunnel to router Caddy, then TLS re-proxy to the NAS Caddy. Encrypted on every segment. |
| LAN device with hardcoded public DNS | 8.8.8.8 etc.           | `A 10.0.0.1`                        | hairpin through router Caddy, same as WG path. Works, just not optimal.                 |

The router's Unbound serves the split horizon via `dns.extraLocalData` A
records. Unbound's transparent local-zone semantics return NODATA for AAAA
queries on names that have local A data, so IPv6-preferring LAN clients are
not pulled back to the router by the public AAAA record.

## Traffic flows

### LAN client (direct)

```
client ──TLS──> NAS Caddy (:443) ──localhost──> service port
```

DNS: client asks 10.0.0.1 → local-data answer 10.0.0.105. Router never sees
the traffic. The only plaintext is loopback inside the NAS.

### WireGuard client

```
phone ──TLS-in-WireGuard──> router Caddy ──TLS──> NAS Caddy ──localhost──> service
```

DNS: phone uses its normal resolver → public zone → `AAAA` = router's
WireGuard address (`A` = 10.0.0.1 is unroutable in the v6-only tunnel and
fails fast). The router vhost re-proxies with:

```caddyfile
reverse_proxy https://pp-nas1.home.arpa {
  transport http {
    tls_server_name jellyfin.prestonperanich.com
  }
}
```

It dials the stable `.home.arpa` name but pins SNI/cert verification to the
public name. Dialing the public name instead would resolve through the
router's own DNS and risk a self-loop back into the same vhost.

## Certificates

- Both Caddys obtain real Let's Encrypt certs via the Cloudflare DNS-01
  challenge (`caddy-dns/cloudflare` plugin, token from sops
  `cloudflare-api-token`, shared fleet secret).
- Renewals are independent per host. The blackbox target
  `https://jellyfin.prestonperanich.com` exercises the NAS cert (resolves to
  the NAS from the router) and the `CertExpiringSoon` alert fires under 14
  days remaining; other blackbox targets cover the router's certs.
- The NAS Caddy runs with `auto_https disable_redirects` because nginx
  (nextcloud) owns port 80 there. Consequence: `http://` requests to the NAS
  are not redirected; use `https://` explicitly.

## Where the config lives

| Concern                                                 | Location                                                                         |
| ------------------------------------------------------- | -------------------------------------------------------------------------------- |
| NAS Caddy + vhosts (`mkLocalProxy` helper, upload caps) | `machines/pp-nas1/configuration.nix`                                             |
| Router re-proxy vhosts (`mkNasProxy` helper)            | `machines/pp-router1/configuration.nix`                                          |
| Split-horizon A records                                 | `machines/pp-router1/configuration.nix` (`dns.extraLocalData`)                   |
| Public zone records (A 10.0.0.1 + AAAA wg)              | `machines/pp-router1/configuration.nix` (`my.cloudflareDns`, via `mkDnsRecords`) |
| Cert monitoring                                         | `my.observability.blackbox.httpTargets` + `CertExpiringSoon` rule                |

## Adding a new NAS-hosted service

1. **NAS**: add a vhost in `machines/pp-nas1/configuration.nix`:
   `"foo.prestonperanich.com" = mkLocalProxy <port> "";` (add `mkUpload "NG"`
   if large request bodies are expected).
2. **Router**: add the re-proxy vhost:
   `"foo.prestonperanich.com" = mkNasProxy "foo.prestonperanich.com" "";`
3. **Router**: add `"foo"` to the split-horizon list in `dns.extraLocalData`.
4. **Router**: add `"foo"` to the `mkDnsRecords` subdomain list (public zone).
5. If the service validates proxy headers, trust both `10.0.0.1` (router
   Caddy) and `127.0.0.1` (local Caddy) — see nextcloud/home-assistant
   `trustedProxies`.
6. Deploy both machines.

## Caveats and accepted tradeoffs

- **Raw service ports remain LAN-open** (e.g. `pp-nas1.home.arpa:8096` over
  plain HTTP). Deliberate: direct-by-IP access stays valid. Closing them
  would mean binding services to localhost once all clients migrate to the
  TLS names.
- **WireGuard clients must not use the router's DNS.** The split-horizon
  answer (10.0.0.105) is unroutable inside the v6-only tunnel. Generated peer
  configs (`docs/wireguard/*.conf`) set no DNS override, so phones use public
  DNS and get the correct AAAA. Keep it that way when adding peers.
- **Prometheus exporters** (9633 smartctl, 9640 node) are firewalled to the
  router only; they are scrape targets, not user services.
- The NAS's DHCP reservation pins 10.0.0.105; the local-data records assume
  it. If the NAS IP ever changes, update `dns.extraLocalData` alongside the
  reservation.
