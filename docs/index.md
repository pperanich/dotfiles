# Dotfiles Documentation

Nix-based system configuration using the dendritic pattern with flake-parts and clan-core.

## Guides

### Machine Management

- [Adding New Machines](adding-new-machines.md) - Complete guide for onboarding new NixOS/Darwin machines
- [Troubleshooting Clan Commands](clan-machines-update-troubleshooting.md) - Debug common deployment issues

### Secrets

- [Secrets and Key Management](secrets-and-key-management.md) - Machine keys vs user keys, SSH-derived keys, anti-patterns

### Modules

- [Router Module](router-module.md) - Complete router with VLAN, WiFi, firewall, DHCP, DNS, SQM

### Networking

- [WireGuard Split Tunneling](wireguard-split-tunneling.md) - Route specific services through a VPN using network namespaces

### Services (TODO)

- [Service Exposure Pathways](service-exposure.md) - Private (Caddy/LAN/WG) and public (Cloudflare Tunnel) service access
- [Web Hosting Setup](web-hosting-setup.md) - Self-hosting websites via DDNS + reverse proxy (in progress)

## Quick Start

### Deploy to a Machine

```bash
# From admin workstation
clan vars upload <hostname>
clan machines update <hostname>
```

### Add a New Machine

1. Create `machines/<hostname>/configuration.nix`
2. Add to `modules/flake-parts/clan.nix` inventory
3. Generate secrets: `clan vars generate <hostname>`
4. Deploy: `clan machines update <hostname>`

See [Adding New Machines](adding-new-machines.md) for detailed steps.

## Architecture

```
dotfiles/
├── machines/           # Host-specific configurations
├── modules/            # Reusable NixOS/Darwin/home-manager modules
│   └── flake-parts/    # Flake infrastructure (clan, nixpkgs, shell)
├── home-profiles/      # User environment compositions
├── sops/               # Secrets management
│   ├── machines/       # Machine public keys
│   ├── secrets/        # Encrypted secrets (age keys, passwords)
│   └── secrets.yaml    # App secrets (traditional sops-nix)
└── vars/               # Clan-managed variables
    ├── per-machine/    # Machine-specific vars
    └── shared/         # Cross-machine vars
```

## Secret Management

This repo uses a **hybrid approach**:

| System                   | Purpose                                     | Location                                   |
| ------------------------ | ------------------------------------------- | ------------------------------------------ |
| **Clan vars**            | Machine bootstrap, user passwords, SSH keys | `vars/`, `sops/secrets/<machine>-age.key/` |
| **Traditional sops-nix** | App secrets (tailscale, borg, etc.)         | `sops/secrets.yaml`                        |

### Key Concepts

- **Clan-generated keys**: Fresh age keypairs created by clan, stored encrypted in repo
- **Machine key.json**: Public key used to encrypt secrets FOR a machine
- **Self-upload**: Machine can decrypt its own bootstrap secrets
- **Admin upload**: Admin workstation decrypts and uploads to machine

## Common Commands

```bash
# Machine deployment
clan machines list                    # List all machines
clan machines update <hostname>       # Deploy to machine
clan vars upload <hostname>           # Upload secrets only

# Secrets management
clan vars list <hostname>             # List vars for machine
clan vars generate <hostname>         # Generate vars
clan secrets get <secret>             # Decrypt a secret
clan secrets machines add-secret <m> <s>  # Add machine as recipient

# Development
nix develop                           # Enter dev shell
nix fmt                               # Format all files
nix flake check                       # Validate flake
```

## Machines

| Hostname   | Type    | OS     | Description                    |
| ---------- | ------- | ------ | ------------------------------ |
| pp-ml1     | Laptop  | Darwin | Personal MacBook               |
| pp-ll1     | Laptop  | NixOS  | Personal Linux laptop          |
| pp-ld1     | Desktop | NixOS  | Personal Linux desktop         |
| pp-nas1    | Server  | NixOS  | NAS (BeeLink)                  |
| pp-router1 | Server  | NixOS  | Router                         |
| pp-rpi1    | SBC     | NixOS  | Raspberry Pi 3B+ GPIO debugger |
| pp-wsl1    | VM      | NixOS  | WSL instance                   |
