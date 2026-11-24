# Dotfiles Documentation

Nix-based system configuration using the dendritic pattern with flake-parts. Hosts are built by `modules/flake-parts/hosts.nix`, NixOS hosts are deployed with deploy-rs, secrets are per-host sops files, and remote access runs over Headscale and Tailscale.

## Guides

### Machine Management

- [Adding New Machines](adding-new-machines.md) - Onboarding a NixOS or Darwin host: host config, SSH host key, sops file, deploy node, Headscale enrollment
- [Private Machines](private-machines.md) - Running hosts from a private flake that consumes this one
- [Operating the Fleet](operations.md) - How changes are made from pp-ml1, snapshots before upgrades, restore tests, known traps
- [Atuin Daemon Troubleshooting](atuin-daemon-troubleshooting.md) - Fix the daemon when it stops logging (stale socket)

### Secrets

- [Secrets and Key Management](secrets-and-key-management.md) - Per-host sops files, the key inventory, editing, rotation and recovery
- [Backups](backups.md) - ZFS snapshots, router-to-NAS Borg, restic to Google Drive; enabling a host, restoring, the offline copy
- [To do](todo.md) - Open work and the backlog

### Modules

- [Router Module](router-module.md) - Complete router with VLAN, WiFi, firewall, DHCP, DNS, SQM

### Services

- [Git Pages](git-pages.md) - Self-hosted static repo docs (`*.pages.prestonperanich.com`) via `git-pages`, Caddy, and Gitea Actions
- [Hermes coordinator](hermes.md) - Phone login, ChatGPT authentication and the first Rex worker on WSL
- [OpenClaw](openclaw.md) - Gateway next to Hermes: Control UI token and pairing, ChatGPT login, its own WSL worker
- [Service Exposure Pathways](service-exposure.md) - Private (Caddy over LAN and tailnet) and public (Cloudflare Tunnel) service access
- [Split-Horizon TLS](split-horizon-tls.md) - How service names route over the best path for each client
- [Web Hosting Setup](web-hosting-setup.md) - Self-hosting websites via DDNS + reverse proxy (in progress)

### Decisions

- [0001: Headscale replaces the WireGuard mesh](decisions/0001-headscale-replaces-wireguard-mesh.md)
- [0002: Kanidm as the identity provider (withdrawn)](decisions/0002-kanidm-identity-provider.md)
- [0003: Git history is not purged](decisions/0003-git-history-is-not-purged.md)
- [0004: Google Drive is the only off-site tier](decisions/0004-google-drive-is-the-only-offsite-tier.md)
- [0005: Every host follows nixpkgs-unstable](decisions/0005-nixpkgs-unstable-for-every-host.md)
- [0006: Credentials left unrotated](decisions/0006-credentials-left-unrotated.md)
- [0007: Accepted root-equivalent access](decisions/0007-accepted-root-equivalents.md)
- [0008: Deploys log in as root with the admin key](decisions/0008-deploys-log-in-as-root.md)
- [0009: hermes-agent keeps its own nixpkgs](decisions/0009-hermes-agent-keeps-its-own-nixpkgs.md)

## Quick Start

Run these from `pp-ml1`, inside `nix develop` at the repo root.

### Deploy to a Machine

```bash
deploy .#pp-wsl1                                  # target pp-wsl1.pp-ts
deploy --hostname pp-nas1.pp-ts .#pp-nas1
deploy --hostname pp-router1.pp-ts .#pp-router1
nh darwin switch . -H pp-ml1                      # the Mac switches locally
```

deploy-rs logs in as root with `pp-ml1`'s key ([decision 0008](decisions/0008-deploys-log-in-as-root.md)), builds on the target, and rolls back if it cannot reconnect. Nodes are defined in `modules/flake-parts/deploy.nix`. Use the tailnet names: ssh launched by Nix on the Mac cannot resolve `home.arpa` ([Operating the Fleet](operations.md#traps)).

### Add a New Machine

1. Create `machines/<hostname>/configuration.nix` and add the name to `expectedHosts` in `modules/flake-parts/hosts.nix`
2. Create its SSH host key and add its age recipient and creation rule to `sops/.sops.yaml`
3. Create `sops/machines/<hostname>.yaml`
4. Install it; for NixOS, add a node to `modules/flake-parts/deploy.nix`
5. Enroll it in Headscale with a tagged pre-auth key

See [Adding New Machines](adding-new-machines.md) for the commands.

## Architecture

```
dotfiles/
├── machines/           # Host-specific configurations
├── modules/            # Reusable NixOS/Darwin/home-manager modules
│   └── flake-parts/    # Flake infrastructure (hosts, deploy, nixpkgs, shell, fmt)
├── home-profiles/      # User environment compositions
├── lib/                # Library functions and pinned SSH keys
│   ├── default.nix     # sshKeys (login keys) and helpers
│   └── ssh-host-keys.nix  # Pinned host public keys
├── templates/          # Flake templates (dendritic, private)
└── sops/               # Encrypted secrets
    ├── .sops.yaml      # Recipients and creation rules
    ├── machines/       # One file per host
    ├── users/          # pperanich-desktop.yaml (home-manager API keys)
    └── cloudflared-tunnel.json
```

## Secret Management

All secrets are sops-nix secrets encrypted with age. Each host has its own file, `sops/machines/<host>.yaml`, readable by the admin age key, a YubiKey and that host's SSH-derived age key. Hosts decrypt with `/etc/ssh/ssh_host_ed25519_key`; home-manager decrypts with `~/.config/sops/age/keys.txt`.

## Access

- `pperanich` logs in over SSH with `pp-ml1`'s key (`sshKeys` in `lib/default.nix`). Root accepts that key only, for deploy-rs (`deploySshKeys`); passwords are off for both.
- Remote access is Headscale on `pp-router1` with a Tailscale client on every host. Tailnet names are `<host>.pp-ts`. `home.arpa` names resolve on the LAN only.
- Host public keys are pinned in `known_hosts` from `lib/ssh-host-keys.nix`.

## Common Commands

```bash
# Development
nix develop                           # Enter dev shell
nix fmt                               # Format all files
nix flake check --no-build            # Evaluate the flake and its checks

# Secrets
sops --config sops/.sops.yaml sops/machines/<hostname>.yaml
sops --config sops/.sops.yaml updatekeys sops/machines/<hostname>.yaml

# Headscale (on pp-router1, with sudo)
sudo headscale nodes list
sudo headscale preauthkeys create --user 1 --expiration 1h --tags tag:<tag>
```

## Machines

| Hostname   | Type   | OS     | Description                                          |
| ---------- | ------ | ------ | ---------------------------------------------------- |
| pp-ml1     | Laptop | Darwin | Personal MacBook, the only admin machine             |
| pp-nas1    | Server | NixOS  | NAS (BeeLink)                                        |
| pp-router1 | Server | NixOS  | Router and Headscale server                          |
| pp-rpi1    | SBC    | NixOS  | Raspberry Pi 3B+ GPIO debugger (off until re-imaged) |
| pp-wsl1    | VM     | NixOS  | WSL instance                                         |
