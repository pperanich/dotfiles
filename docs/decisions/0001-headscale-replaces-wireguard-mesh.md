# 0001: Headscale with Tailscale clients replaces the unified WireGuard mesh

## Status

Accepted 2026-11-11. Written after the implementation, because the choice was not recorded when it was made.

## Context

A security audit of the fleet in November 2026 found that the flat `pp-wg` WireGuard mesh is trusted as a whole. The router lists `pp-wg` in `@trusted_ifaces`, which gives every peer unrestricted access to the router's input chain and forwarding to `br-main`. Any peer (`pp-wsl1`, `pp-rpi1`, `phone1`, `phone2`) could reach Loki on `:3100`, CUPS on `:631` and ntopng on `:3000`. The audit also found that the phones' WireGuard private keys sit in `sops/secrets.yaml`, readable by every machine.

The remediation plan that followed proposed keeping WireGuard and replacing its three separate pieces (the clan module, `wg-external-peers.json`, the observability matcher) with one module, `modules/system/wireguard.nix`. It would hold one peer inventory with a `role` and `alwaysOn` per peer, and two nftables sets, `@wg_admin_peers` and `@wg_client_peers`, with different port access.

## Decision

Run a self-hosted Headscale server on `pp-router1` and put a Tailscale client on every host (`modules/services/headscale.nix`, `modules/system/tailscale.nix`). Access is decided by tag in a declarative policy file:

- `tag:admin` (workstations): everything.
- `tag:mobile`: router `:53` and `:443`, NAS `:443`.
- `tag:dev`: router `:53` and `:443`.
- `tag:iot` and `tag:server`: router `:53`.
- `tag:router`: NAS `:22` and `:443`.
- `tag:nas` is defined as a tag and is only a destination.

Headscale listens on loopback `127.0.0.1:8085`. Caddy terminates TLS for it on public TCP `:9443` at `hs.prestonperanich.com`, a gray-cloud DNS record, because Cloudflare Tunnel does not pass the `Upgrade: tailscale-control-protocol` handshake. The router also opens UDP `41641` on the WAN for direct peer connections. Tailnet names live under `pp-ts`, kept apart from the LAN-only `home.arpa`, which Headscale does not resolve over the tailnet.

## Alternatives considered

The unified WireGuard module from section 6.2 of the plan. No written comparison exists from the time the choice was made, so this record does not claim one.

## Consequences

Costs:

- A public TCP port (`9443`) and a public UDP port (`41641`) on the router.
- NAT traversal depends on Tailscale's relay servers: `headscale.nix` sets `derp.server.enabled = false` and loads the DERP map from `https://controlplane.tailscale.com/derpmap/default`. Hosts that cannot connect directly relay through Tailscale's servers.
- One more service on the router, with its SQLite database in `/var/lib/headscale`.
- Phones use the Tailscale app, not a WireGuard profile.
- The first enrolled node gets `100.64.0.1`, and `my.headscale.routerTailscaleIpv4` assumes that, so the router must enroll first.

Gains:

- Per-tag access rules instead of one trusted interface.
- MagicDNS under `pp-ts`, with no split DNS: `home.arpa` resolves only on the LAN.
- Enrollment uses short-lived tagged pre-auth keys ([Adding New Machines](../adding-new-machines.md)) instead of per-peer WireGuard keys stored in `sops/secrets.yaml`.
