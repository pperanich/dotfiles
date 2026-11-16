# To do

Open work. Remove an item when it is done; record a decision in `docs/decisions/` when one is dropped.

## Now

- Delete `~/.config/sops/age/keys-old.txt` once nothing needs the old history decrypted: its retired admin key (`age10djyw…`) is a recipient in no current file.

## Backlog

### Inputs and builds

- UniFi's MongoDB is pinned to 7.0.43 (`nixpkgs-mongodb`, the build already on the router), because nixpkgs' MongoDB is unfree, never cached, and compiles for hours on the N150. Move to the binary `mongodb-ce` once UniFi 10.x's supported MongoDB range is confirmed; MongoDB 8.0 and 8.2 warn about Linux 6.19 to 7.0.13 (the router runs 6.18). It is a database major upgrade: UniFi backup first.
- CI: a weekly `bin/update-inputs.sh` pull request with `bin/build-report.sh` output; add a private cache only if the report keeps showing heavy builds (closures include unfree packages, so a public cache is out).

### Security

- Rotate the 16 values in `feed-me`'s `.env.sops`: the retired shared SSH key could read them.
- Per-person logins for apps that lack them: Homepage and ntopng have none, scanservjs and Radicale share one `basic_auth` hash, and the Vaultwarden admin page has only its token. Kanidm was tried and withdrawn (decision 0002).
- Mail: tighten SPF from `~all` and DMARC from `p=none` once Resend delivery is confirmed.
- Homepage: replace `allowedHosts = "*"` with its real host names.
- The router's WAN DHCPv6 accept rule (`modules/router/firewall.nix`) only matches link-local sources (`fe80::/10`). If the ISP's server ever replies from a global address, the reply is dropped and the router loses its delegated prefix at the next renew. Capture a DHCPv6 exchange on the WAN to confirm, or drop the source match.
- Decide whether hosts get distinct sudo passwords (decision 0006 keeps the current one).
- `pp-nas1` bridges both NICs into `br0` on the main VLAN, so anything plugged into `enp2s0` is on the LAN. Remove `enp2s0` unless a trusted device uses it, and add `ip6 daddr { fc00::/7, fe80::/10 } drop` to the `container-isolation` forward chain, which drops only IPv4 private ranges.
- Move `permittedInsecurePackages` out of `modules/system/base.nix` into the owning module or machine (design rules 1 and 3).

### Larger pieces

- NAS disk encryption: starts from the local branch `nas-zfs-encryption`. Its migration script leaves the space reservation dropped and a partial copy, with no recovery path, if the baseline copy fails; fix that and rehearse on a throwaway pool first.
- macOS backup: starts from the local branch `darwin-drive-backup`. Its script runs `restic init` on any failed repository probe, so a stale lock stops backups for good; fix that first.
- Re-image `pp-ld1` and `pp-rpi1`, give them deploy nodes, and decide where `pp-rpi1` builds.

### Code health

Departures from the design rules in `AGENTS.md`, to fix when the code is next touched.

- `modules/flake-parts/hosts.nix` sets `networking.hostId = "8425e349"` (the NAS pool's ID) as the default for every NixOS host; a second ZFS host would collide. Move it to `machines/pp-nas1`.
- Dead transition options: `allowUnauthenticated` in `modules/services/scanservjs.nix` (the NAS sets the password) and `deploySshPrivateKey` in `modules/users/pperanich.nix` (no host sets it, no sops file holds the key).
- `my.pperanich.desktop` and `my.desktop.enable` both mean "this is a desktop", one feeding the other.
- About 20 cross-module `config.my.x or false` probes remain (`sops.nix`, `tailscale.nix`, `observability.nix`, `borg-client.nix`, `router/dns.nix`, `router/core.nix`).
- Programs over 30 lines inside Nix strings: kea-unbound-sync in `router/ddns.nix`, the ProtonVPN verify scripts, the netdev drop converter in `observability.nix`, the stow activation in `base.nix`.
- Host names in shared code: `lib/default.nix` (Gitea's known_hosts name), `services/headscale.nix` (router addresses as defaults), `system/tailscale.nix` (an option description).
- Repeated literals: `10.0.0.1` in the NAS and router configs, the public domain in `observability.nix` and `pp-wsl1` despite `lib.my.homelab`, and `10.0.0.0/8` / `100.64.0.0/10` in four places.
- Every new service is still added by hand to the router's DNS subdomain list (`caddy.nix`), the blackbox probe lists and the NAS's `logShipping.keepUnits`.
- `router/dns.nix` takes `extraLocalData` as raw Unbound record strings and splits them apart again to find owner names.
- Unused files: `pkgs/dmg-app.nix`; `bin/kproc.sh`, `bin/sunshine-ufw.sh` and `bin/install-gnome-term-profile.sh` are referenced nowhere.
- Large modules: `observability.nix` (about 1,200 lines), `protonvpn.nix` (about 800), `firewall.nix` (about 660, IPv4 and IPv6 rules side by side).

### Tooling

- `pp-wsl1` goes offline when the Windows PC sleeps or nobody is signed in: `bin/wsl-keepalive.ps1` (run once on `pp-wd1`, elevated) fixes both if that becomes a problem.
- Renew the Headplane API key before 2027-02-14 (`ssh -t pperanich@pp-router1.pp-ts 'sudo headscale apikeys create --expiration 90d'`) and update Bitwarden "Headplane API key: pp-router1"; a longer `--expiration` would make this rarer.
- Headless hosts: link core CLI dotfiles from the store instead of stowing the whole `home/`.
- API keys: load them on demand (a `with-keys` helper) instead of exporting every key in every shell, and discover keys from the sops file instead of a static list.
- `cf`: fall back to the sops-held token when `CLOUDFLARE_API_TOKEN` is unset.
- Per-machine SSH keys: publish them to GitHub and Gitea from the `lib.my.sshKeys` registry, and generate an `allowed_signers` file.
