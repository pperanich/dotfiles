# Dotfiles

Nix-based system configuration using the dendritic pattern with [flake-parts](https://flake.parts/) and [clan-core](https://docs.clan.lol/).

## Quick Start

```bash
# Clone
git clone https://github.com/pperanich/dotfiles.git ~/dotfiles
cd ~/dotfiles

# Enter dev shell
nix develop

# Deploy to a machine
clan vars upload <hostname>
clan machines update <hostname>
```

## Machines

| Hostname     | OS     | Type    | Description                      |
| ------------ | ------ | ------- | -------------------------------- |
| pp-ml1       | Darwin | Laptop  | Personal MacBook (Apple Silicon) |
| pp-ll1       | NixOS  | Laptop  | Personal Linux laptop            |
| pp-ld1       | NixOS  | Desktop | Personal Linux desktop           |
| pp-nas1      | NixOS  | Server  | NAS (BeeLink)                    |
| pp-router1   | NixOS  | Server  | Router                           |
| pp-rpi1      | NixOS  | SBC     | Raspberry Pi                     |
| pp-wsl1      | NixOS  | VM      | WSL instance                     |
| peranpl1-ml1 | Darwin | Laptop  | Work MacBook                     |
| peranpl1-ml2 | Darwin | Laptop  | Work MacBook                     |

## Architecture

```
dotfiles/
├── machines/           # Host-specific configurations
├── modules/            # Reusable NixOS/Darwin/home-manager modules
│   └── flake-parts/    # Flake infrastructure (clan, nixpkgs, shell)
├── home-profiles/      # User environment compositions
├── sops/               # Secrets (machine keys, app secrets)
├── vars/               # Clan-managed variables
└── docs/               # Documentation
```

### Key Concepts

| Concept               | Description                                                            |
| --------------------- | ---------------------------------------------------------------------- |
| **Dendritic pattern** | Auto-discovery of modules via `import-tree` - no manual imports needed |
| **Clan-core**         | Infrastructure-as-code machine deployment with inventory and roles     |
| **Hybrid secrets**    | Clan vars for machine bootstrap, traditional sops-nix for app secrets  |

### Module Export Pattern

```nix
# modules/example/foo.nix
_: {
  flake.modules.homeManager.foo = { pkgs, ... }: { ... };
  flake.modules.nixos.foo = { ... }: { ... };
  flake.modules.darwin.foo = { ... }: { ... };
}
```

## Common Commands

```bash
# Development
nix develop                           # Enter dev shell
nix fmt                               # Format all files
nix flake check                       # Validate flake

# Machine deployment
clan machines list                    # List all machines
clan machines update <hostname>       # Deploy to machine
clan vars upload <hostname>           # Upload secrets only

# Secrets
clan vars list <hostname>             # List vars for machine
clan secrets get <secret>             # Decrypt a secret

# Manual builds
sudo nixos-rebuild switch --flake .#<hostname>    # NixOS
darwin-rebuild switch --flake .#<hostname>        # Darwin
home-manager switch --flake .#<username>          # Home-manager
```

## Documentation

Detailed guides are available in the [docs/](docs/) directory:

- **[Adding New Machines](docs/adding-new-machines.md)** - Complete onboarding guide
- **[Troubleshooting](docs/clan-machines-update-troubleshooting.md)** - Debug deployment issues

To browse documentation locally:

```bash
nix run nixpkgs#zensical -- serve
```

## Secrets Management

This repo uses a **hybrid approach**:

| System                   | Purpose                                           | Location                 |
| ------------------------ | ------------------------------------------------- | ------------------------ |
| **Clan vars**            | Machine bootstrap (age keys, SSH keys, passwords) | `vars/`, `sops/secrets/` |
| **Traditional sops-nix** | App secrets (tailscale, borg, k3s)                | `sops/secrets.yaml`      |

### Adding a Machine to Secrets

```bash
# Generate vars (creates age keypair, SSH keys, etc.)
clan vars generate <hostname>

# Add to secrets.yaml recipients (edit sops/.sops.yaml, then:)
cd sops && sops updatekeys secrets.yaml

# Enable self-upload (optional)
clan secrets machines add-secret <hostname> <hostname>-age.key
```

See [Adding New Machines](docs/adding-new-machines.md) for complete steps.

## Installation

### Prerequisites

```bash
# Install Nix (Determinate Systems installer)
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
```

### First-Time Setup

**NixOS:**

```bash
sudo nixos-rebuild switch --flake .#<hostname>
```

**Darwin:**

```bash
nix run nix-darwin -- switch --flake .#<hostname>
```

**Home-manager (standalone):**

```bash
nix run home-manager/release-25.05 -- switch --flake .#<username>
```

## Project Structure

<details>
<summary>Click to expand full directory structure</summary>

```
modules/
├── flake-parts/         # Flake infrastructure
│   ├── clan.nix           # Machine inventory & services
│   ├── home.nix           # Home-manager integration
│   ├── nixpkgs.nix        # Nixpkgs config & overlays
│   └── shell.nix          # Development shell
├── containers/          # k3s, podman
├── database/            # couchdb
├── desktop/             # fonts, yabai, skhd, sketchybar
├── editors/             # emacs, nvim, vscode
├── languages/           # rust, tex
├── network/             # tailscale, ssh, home-assistant
├── router/              # firewall, NAT, DHCP
├── shell/               # zsh, tools, environment
├── system/              # nix config, sops, borgbackup
├── users/               # user account modules
└── virtualization/      # docker, qemu, lxd

machines/
├── pp-*/                # Personal machines
└── peranpl1-*/          # Work machines

home-profiles/
├── pperanich/           # Primary user (NixOS)
├── peranpl1/            # Primary user (Darwin)
└── generic/             # Shared/service accounts

sops/
├── .sops.yaml           # SOPS config for secrets.yaml
├── secrets.yaml         # App secrets (traditional sops-nix)
├── machines/            # Machine public keys
└── secrets/             # Encrypted age keys

vars/
├── per-machine/         # Machine-specific vars
└── shared/              # Cross-machine vars (user passwords)
```

</details>

## References

- [Flake-parts](https://flake.parts/)
- [Clan-core](https://docs.clan.lol/)
- [sops-nix](https://github.com/Mic92/sops-nix)
- [NixOS](https://nixos.org/manual/nixos/stable/)
- [nix-darwin](https://github.com/LnL7/nix-darwin)
- [home-manager](https://nix-community.github.io/home-manager/)

## License

MIT
