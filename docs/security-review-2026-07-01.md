# Security Review — 2026-07-01

Scope: full homelab flake — pp-router1 (router + services), pp-nas1 (NAS + services),
all other machines (pp-ld1, pp-ll1, pp-ml1, pp-rpi1, pp-wsl1), shared modules
(base, sops, users, clan inventory), and a secrets hygiene sweep of `sops/` and `vars/`.

## TL;DR

Secrets discipline, firewall design, and SSH hardening are strong: no plaintext
credentials anywhere, everything sops-encrypted, default-drop nftables. The real
risks are structural: one SSH key is fleet-wide root and lives on the least-trusted
machines, and the public repo carries offline-crackable password hashes and a stale
decryption key.

## Act on these first

### 1. Fleet-wide root from a single key on untrusted hosts (High)

`modules/users/pperanich.nix:26-32` deploys the personal SSH private key to every
machine, and its pubkey is authorized for root everywhere (via clan's sshd module).
That includes pp-wsl1 (filesystem fully readable by the Windows host) and pp-rpi1
(unencrypted, physically accessible SD card). Windows malware or a lifted SD card
equals root on the entire fleet, including the router and Vaultwarden host.

**Fix:** stop deploying the personal key to non-workstation hosts; use SSH agent
forwarding or per-host keys, and authorize root only from admin machines.

### 2. Emergency-access password hashes committed plaintext to a public repo (High)

`vars/per-machine/*/emergency-access/password-hash/value` holds sha512crypt hashes
of the initrd recovery password, unencrypted, in github.com/pperanich/dotfiles
(public — verified). Anyone can run an offline crack against them; if the xkcdpass
wordlist/length is guessable, that password works at any console.

**Fix:** rotate the emergency password with a stronger one; reconsider whether the
repo should be public given how much infrastructure detail it exposes.

### 3. Decommissioned work machine's age key can still decrypt live secrets (High)

`sops/cloudflared-tunnel.json`, `sops/secrets/flakehub-token/secret`, and
`sops/secrets/pperanich-password/secret` are still encrypted to the old JHUAPL
`peranpl1` key that commit `fdc5283` was supposed to remove (verified present).

**Fix:** `sops updatekeys` to drop the recipient, then rotate the Cloudflare tunnel
credential and FlakeHub token (that key's whereabouts are unknown). Git history
still lets rotated-out keys read historical ciphertext, so re-encryption without
rotation isn't enough.

### 4. Unencrypted disks on machines holding fleet credentials (Medium)

pp-ll1 (laptop, plain ext4 + unencrypted swap) and pp-rpi1 (SD card) both carry the
personal SSH key and their sops age keys. Laptop theft is the realistic scenario.

**Fix:** LUKS on the laptop; for the Pi, stop deploying the personal key there.

## Worth fixing soon

- **NAS services bypass Caddy (Medium):** Nextcloud (`0.0.0.0:80`), Immich
  (`:2283`), scanservjs (`:8080`, no auth at all), and OpenCloud (`:9200`,
  `OC_INSECURE=true`) are all reachable plaintext from the whole LAN, not just the
  router's reverse proxy. One shared nftables rule restricting those four ports to
  source `10.0.0.1` (plus the WireGuard prefix if needed) closes all of them.
  scanservjs is the worst: anyone on the LAN can browse and download scans today.
- **Shared root password across all seven machines (Medium):** `users-root` in
  `modules/flake-parts/clan.nix:106-120` uses `share = true`. Set `share = false`
  for per-machine passwords. Same for `user-pperanich`, which also grants the
  root-equivalent `docker` group everywhere.
- **macOS sshd unhardened (Medium):** `modules/system/base.nix:153` enables Remote
  Login on pp-ml1 with Apple defaults (password auth on); clan's hardening is
  NixOS-only. Add `PasswordAuthentication no` or disable Remote Login.
- **Monolithic `secrets.yaml` (Medium):** all 36 secrets (WiFi, admin passwords,
  phone WireGuard keys) are decryptable by every machine including pp-wsl1 and
  pp-rpi1. Split per-scope or migrate to clan vars (already per-machine scoped).
- **ntopng default `admin/admin` (Medium):** reachable from LAN + all VPN peers
  with full traffic visibility (`modules/router/monitoring.nix`; login documented
  as admin/admin at `machines/pp-router1/configuration.nix:281`).

## Lower priority

- Radicale `http_x_remote_user` auth is header-trust impersonation if its bind
  address ever leaves loopback; add an assertion. Side effect: loopback-only bind
  means the router's Caddy can't reach it, so the vhost is likely broken anyway.
- ProtonVPN module: kill switch defaults to `"none"` in host mode (fails open);
  the persistent chain's blanket RFC1918 allowance leaks DNS via the LAN resolver
  when the tunnel is down. Namespace mode is properly fail-closed.
- Vaultwarden login is internet-facing via the Cloudflare tunnel; `/admin` is
  blocked, signups off, rate-limited, but Cloudflare Access in front would remove
  unauthenticated internet reach entirely.
- DMARC `p=none` / SPF `~all` leave the domain spoofable (already TODO'd) —
  `machines/pp-router1/configuration.nix:414-419`.
- `homepage-dashboard.allowedHosts = "*"` disables Host validation; pin to real
  hostnames (`machines/pp-router1/configuration.nix:519`).
- WireGuard DNS ACL `${wgPrefix}::/40` wider than the actual peer `/64`
  (`machines/pp-router1/configuration.nix:234`).
- `.sops.yaml` drift: undeclared `pperanich-pp-ll1` recipient on
  `cloudflared-tunnel.json`; unused `pp-ml1-ssh` anchor. Run `sops updatekeys`.
- `validateSopsFiles = false` in `modules/system/sops.nix:9`.
- Dotfiles clone uses `StrictHostKeyChecking=accept-new` (TOFU) —
  `modules/system/base.nix:276`.
- pp-ll1 deploys to bare IP `root@192.168.0.181`, bypassing SSH-CA hostname certs.
- WAN accepts unsolicited `icmp echo-reply` (`modules/router/firewall.nix:264`);
  conntrack covers legitimate replies.
- OpenOCD template services on pp-rpi1 run as root with no sandboxing (localhost
  bind limits exposure).

## Addendum: WAN attack-surface review (pp-router1)

Focused re-review of everything reachable from the public IP.

**Enumerated WAN surface (verified in `modules/router/firewall.nix`):**

| Exposure | Verdict |
|---|---|
| UDP 51820 (WireGuard) | Only open port. Rate-limited (100/s new). WG is silent to scanners without a valid peer key. |
| ICMP echo-request | Rate-limited 10/s. |
| ICMPv6 ND/PMTUD types, RA from ISP, DHCPv6-client | Required for IPv6 operation; accepted. |
| Everything else | `policy drop` + BCP38 bogon drops + XMAS/NULL/FIN-SYN scan drops + strict `rp_filter=1`. |
| DNAT / port forwards | None defined (`machines = []`), so no forwarded services. |
| UPnP (miniupnpd) | Not enabled. Module has 1024+ ACL if ever enabled. |
| SSH, DNS, NTP, Caddy, Kea, Avahi, SSDP, ntopng, UniFi | All gated to LAN/VLAN/WireGuard interfaces only; none accept from WAN. Unbound/Blocky bind specific internal IPs — not an open resolver. |
| Public web (site, vault) | Outbound-only Cloudflare Tunnel; no listening WAN socket. |

**Findings:**

- **Low — apex/www dyndns A records point directly at the home IP**
  (`modules/flake-parts/clan.nix:202-221`): `prestonperanich.com` and
  `www.prestonperanich.com` get unproxied A records to the WAN IP every 5 min,
  while the same hostnames are supposed to be served via the Cloudflare Tunnel
  CNAMEs. This publishes the home IP to anyone (defeating the tunnel's
  IP-hiding) and the two mechanisms fight over the same records. `vpn.` must
  stay unproxied by design; drop apex/www from dyndns (tunnel manages them) or
  set the Cloudflare `proxied` flag.
- **Info — IPv6 forward chain has no VLAN rules**: the comment in
  `firewall.nix:417` says "LAN IPv6 forwarding is handled by vlans.nix", but
  vlans.nix injects `forwardRules` only into `filterV4`. Consequence: WAN→LAN
  IPv6 is dropped (good), but LAN→WAN IPv6 also fails closed, so delegated-prefix
  clients have no working v6 egress. Not a vulnerability today; if you ever fix
  v6 egress, add only `iifname br-* oifname wan` accepts, never the reverse.
- **Info — DHCPv6-client accept not source-scoped** (`firewall.nix:397`):
  accepts sport 547 from any global address; could add `ip6 saddr fe80::/10`.
- **Info — unsolicited `icmp echo-reply` accepted on WAN**
  (`firewall.nix:264`): conntrack already covers real replies; drop the rule.
- **Reminder (High, from main review)**: WireGuard is the WAN front door, and
  `trustedInterfaces = ["pp-wg"]` grants tunnel peers full network access —
  so WAN security reduces to the security of every WG private key, including
  the ones sitting on unencrypted disks (pp-rpi1, pp-ll1) and readable-by-Windows
  storage (pp-wsl1). Peer key hygiene is the WAN perimeter.

**Verdict:** WAN posture is excellent. A scanner sees a host answering rate-limited
pings and nothing else. The perimeter's weakest link is not the firewall — it's
WG key custody on the fleet (main review, finding 1).

## Verified healthy

- Router firewall: default-drop input/forward, BCP38 bogon filtering (v4+v6), TCP
  scan-flag drops, L2 RA-guard, conn rate limiting, logged drops. Only WAN port:
  WireGuard 51820/udp.
- Key-only SSH fleet-wide on NixOS (clan sshd: `PasswordAuthentication no`, root
  `prohibit-password`); no passwordless sudo.
- No plaintext secrets in files or git history (pickaxe checked); all 40 `vars`
  secrets + sops files genuinely age-encrypted; phone WG configs redacted.
- WireGuard external peers pinned to `/128` AllowedIPs; clan mesh uses scoped ULA
  AllowedIPs (no 0.0.0.0/0).
- Grafana/Loki/Prometheus loopback-bound, sops-backed creds, signups off.
- Stalwart relays only from 127.0.0.1 (no open relay), TLS to Resend verified.
- Gitea `git` user: forced-command, publickey-only, no TTY/forwarding.
- Vaultwarden admin token Argon2id-hashed at runtime; `/admin` blocked on the
  public tunnel listener.
- ntopng runs with `cap_net_raw` only (no `cap_net_admin`).
- pp-rpi1 WiFi PSK via sops template, out of Nix store.
- Nextcloud `trusted_proxies` correctly limited to router; local-only DB/Redis.
