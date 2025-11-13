# Nix Configuration

A modular and maintainable Nix configuration for both NixOS and Darwin systems, built using the dendritic pattern with flake-parts and clan-core for scalable machine deployment.

## Architecture Overview

This configuration leverages modern Nix tooling to create a highly modular and maintainable system:

- **flake-parts**: Composable flake architecture for better organization
- **clan-core**: Infrastructure-as-code machine deployment and management
- **import-tree**: Automatic module discovery and loading (dendritic pattern)
- **Extended library**: Custom functions for configuration generation

### The Dendritic Pattern

The dendritic pattern uses automatic module discovery via `import-tree`, where all `.nix` files under `/modules` are automatically imported and made available. Each module exports itself by defining attributes on `flake.modules.<platform>.<moduleName>`, creating a tree-like structure that grows organically.

**Key benefits:**

- No manual module imports required
- Self-organizing module structure
- Platform-specific module segregation (nixos, darwin, homeManager)
- Scalable as configuration grows

## Directory Structure

### `/modules` - Modular Components

All system, home-manager, and flake configuration modules, organized by category and automatically imported via `import-tree`:

```
modules/
├── flake-parts/         # Flake-parts integration modules
│   ├── flake-parts.nix    # Base flake-parts configuration
│   ├── clan.nix           # Clan-core machine deployment
│   ├── home.nix           # Home-manager integration
│   ├── nixpkgs.nix        # Nixpkgs configuration & overlays
│   ├── fmt.nix            # Code formatting
│   └── shell.nix          # Development shell
├── containers/          # Container runtimes (k3s, podman)
├── database/            # Database services (couchdb)
├── desktop/             # Desktop applications & window managers
│   ├── applications.nix   # Desktop applications
│   ├── fonts.nix          # Font configurations
│   ├── yabai.nix          # Tiling WM (Darwin)
│   ├── skhd.nix           # Hotkey daemon (Darwin)
│   └── sketchybar.nix     # Status bar (Darwin)
├── editors/             # Editor configurations (emacs, nvim, vscode)
├── languages/           # Language-specific tools (rust, tex)
├── network/             # Network services & utilities
│   ├── tailscale.nix      # VPN mesh network
│   ├── ssh-server.nix     # SSH server configuration
│   ├── home-assistant.nix # Home automation
│   └── utilities.nix      # Network tools
├── shell/               # Shell environments & tools
│   ├── zsh.nix            # Zsh configuration
│   ├── tools.nix          # CLI utilities
│   └── environment.nix    # Environment variables
├── system/              # Core system configurations
│   ├── nix-configuration.nix  # Base Nix settings
│   ├── sops.nix           # Secrets management
│   ├── borgbackup.nix     # Backup system
│   └── file-exploration.nix # File managers
├── users/               # User account modules (pperanich, peranpl1)
├── virtualization/      # Virtualization (docker, qemu, lxd)
└── work/                # Work-specific configurations
```

**Module Structure:**
Each module exports itself by defining flake attributes:

```nix
# Example: modules/shell/zsh.nix
_: {
  flake.modules.homeManager.zsh = { ... };  # Home-manager module
  flake.modules.nixos.zsh = { ... };        # NixOS module (if needed)
  flake.modules.darwin.zsh = { ... };       # Darwin module (if needed)
}
```

### `/home-profiles` - User Environments

Pre-configured user profiles that compose homeManager modules into complete user environments:

```
home-profiles/
├── generic/         # Generic profile for shared/service accounts
├── pperanich/       # Primary user profile (NixOS)
└── peranpl1/        # Primary user profile (Darwin)
```

Profiles automatically generate `homeConfigurations` via the `lib.my.mkHomeConfigurations` function, which:

- Auto-discovers profile directories
- Generates configurations for each user
- Supports additional users via the `generic` profile

### `/machines` - Host Configurations

Individual machine configurations managed by clan-core:

```
machines/
├── peranpl1-ml1/            # Darwin laptop
│   └── configuration.nix
├── peranpl1-ml2/            # Darwin laptop
│   └── configuration.nix
├── pperanich-ll1/           # NixOS laptop (MacBook w/ T2)
│   ├── configuration.nix
│   └── hardware-configuration.nix
├── pperanich-ld1/           # NixOS desktop
├── pperanich-wsl1/          # WSL instance
└── pperanich-raspi1/        # Raspberry Pi
```

Machine configurations import modules by referencing:

```nix
imports = [ ] ++ (with modules.nixos; [
  base           # Core system config
  rust           # Language support
  pperanich      # User account
]);
```

### `/home` - Traditional Dotfiles

Raw configuration files managed outside of Nix, deployed via GNU Stow:

```
home/
├── .config/         # XDG config directory
├── .ssh/           # SSH configurations
└── [other dotfiles]
```

These are automatically stowed to `$HOME` via home-manager activation:

```nix
home.activation.stowHome = lib.hm.dag.entryAfter ["writeBoundary"] ''
  ${pkgs.stow}/bin/stow home
'';
```

### Supporting Directories

- `/lib` - Custom library functions (extended as `lib.my`)
- `/overlays` - Nixpkgs overlays and patches
- `/pkgs` - Custom package definitions
- `/sops` - Encrypted secrets (managed by sops-nix)
- `/vars` - Non-secret configuration variables

## Flake-Parts Integration

The flake entry point delegates all configuration to flake-parts modules:

```nix
# flake.nix
{
  outputs = inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; }
      (inputs.import-tree ./modules);
}
```

**How it works:**

1. `import-tree` recursively imports all `.nix` files in `/modules`
2. Each file can define flake-parts configuration
3. Files under `modules/flake-parts/` wire together the complete system
4. Modules export themselves into `flake.modules.<platform>.<name>`

**Key flake-parts modules:**

- `nixpkgs.nix`: Configures nixpkgs with overlays, extends lib with custom functions
- `clan.nix`: Defines machine inventory and clan-core deployment settings
- `home.nix`: Auto-generates homeConfigurations from profiles
- `shell.nix`: Development environment with formatting tools

## Clan-Core Deployment

Machine deployment and management is handled by [clan-core](https://docs.clan.lol/), providing:

- **Inventory management**: Centralized machine definitions
- **Role-based configuration**: Shared settings across machine groups
- **Secret management**: Integration with sops for encrypted secrets
- **Remote deployment**: Standardized deployment workflows

**Configuration** (`modules/flake-parts/clan.nix`):

```nix
flake.clan = {
  meta.name = "pperanich-clan";

  inventory = {
    machines."peranpl1-ml1".machineClass = "darwin";
    machines."peranpl1-ml1".tags = [ "laptop" ];

    # Instances define shared services/roles
    instances = {
      clan-cache = { ... };      # Nix binary cache
      sshd-basic = { ... };      # SSH configuration
      users-root = { ... };      # Root user setup
      emergency-access = { ... }; # Emergency access
    };
  };
};
```

## Usage Guide

### When to Use Each Component

| Component                 | Use For                                                |
| ------------------------- | ------------------------------------------------------ |
| **Modules (NixOS)**       | System services, hardware config, system-wide settings |
| **Modules (Darwin)**      | macOS system preferences, homebrew, system services    |
| **Modules (homeManager)** | User packages, application configs, dev environments   |
| **Home Profiles**         | Complete user environment definitions                  |
| **Machines**              | Host-specific configuration, hardware settings         |
| **Home (dotfiles)**       | Configs not yet nixified, legacy dotfiles              |

### Adding a New Module

1. Create a file in the appropriate category under `/modules`:

   ```nix
   # modules/editors/helix.nix
   _: {
     flake.modules.homeManager.helix = { pkgs, ... }: {
       programs.helix.enable = true;
     };
   }
   ```

2. Reference it in a profile or machine:
   ```nix
   # home-profiles/pperanich/default.nix
   imports = with outputs.homeManagerModules; [
     helix  # Automatically available!
   ];
   ```

### Adding a New Machine

1. Create machine directory and configuration:

   ```nix
   # machines/new-host/configuration.nix
   { modules, ... }: {
     imports = with modules.nixos; [ base pperanich ];
     networking.hostName = "new-host";
   }
   ```

2. Add to clan inventory:

   ```nix
   # modules/flake-parts/clan.nix
   inventory.machines."new-host".machineClass = "nixos";
   ```

3. Deploy:
   ```bash
   clan machines update new-host
   ```

### Building Configurations

```bash
# NixOS system
sudo nixos-rebuild switch --flake .#pperanich-ll1

# Darwin system
darwin-rebuild switch --flake .#peranpl1-ml1

# Home-manager only
home-manager switch --flake .#pperanich

# Via clan-core
clan machines update pperanich-ll1
```

### Development Workflow

```bash
# Enter development shell (includes formatters, linters)
nix develop

# Format all Nix files
nix fmt

# Check flake
nix flake check

# Update all inputs
nix flake update

# Update specific input
nix flake update nixpkgs
```

## Installation

### Prerequisites

Install Nix with flakes enabled:

```bash
# Install Nix (Determinate Systems installer - recommended)
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install

# Or traditional installer with flakes
sh <(curl -L https://nixos.org/nix/install) --daemon

# Enable flakes (traditional installer only)
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
```

### Initial Setup

1. **Clone the repository:**

   ```bash
   git clone https://github.com/pperanich/dotfiles.git ~/dotfiles
   cd ~/dotfiles
   ```

2. **For NixOS:**

   ```bash
   # First time (may need to bootstrap minimal config first)
   sudo nixos-rebuild switch --flake .#your-hostname

   # Subsequent updates
   sudo nixos-rebuild switch --flake .
   ```

3. **For Darwin (macOS):**

   ```bash
   # Install nix-darwin
   nix run nix-darwin -- switch --flake .#your-hostname

   # Subsequent updates
   darwin-rebuild switch --flake .
   ```

4. **Home-manager standalone:**

   ```bash
   # First time
   nix run home-manager/release-25.05 -- switch --flake .#your-username

   # Subsequent updates
   home-manager switch --flake .
   ```

### Using Clan-Core

Clan-core provides advanced deployment capabilities:

```bash
# Install clan CLI
nix profile install git+https://git.clan.lol/clan/clan-core

# List all machines
clan machines list

# Show machine info
clan machines show pperanich-ll1

# Update/deploy a machine
clan machines update pperanich-ll1

# Update all machines with a tag
clan machines update --tag laptop
```

## Secrets Management

Secrets are managed using [sops-nix](https://github.com/Mic92/sops-nix) with age encryption:

```bash
# Edit secrets (requires proper age key)
sops secrets/example.yaml

# Secrets are automatically deployed with system configuration
# and available at runtime in /run/secrets/
```

**Supported age plugins:**

- `age-plugin-yubikey` - Hardware key storage
- `age-plugin-fido2-hmac` - FIDO2 authentication

## Project Philosophy

### Design Principles

1. **Modularity**: Every component is a self-contained module
2. **Composability**: Modules combine to create complete systems
3. **Discoverability**: Automatic module loading via dendritic pattern
4. **Type Safety**: Leverage Nix's type system for configuration validation
5. **Reproducibility**: Pinned inputs ensure consistent builds
6. **Scalability**: Easy to add new machines and modules

### Module Guidelines

- Keep modules focused on a single responsibility
- Use appropriate platform (nixos/darwin/homeManager)
- Provide sensible defaults with override options
- Document complex configuration choices
- Minimize cross-module dependencies

### Best Practices

- **Testing**: Test changes locally before committing
- **Commits**: Use conventional commits (feat:, fix:, docs:, etc.)
- **Secrets**: Never commit secrets; use sops-nix
- **Pinning**: Pin dependencies for reproducibility
- **Documentation**: Keep README synchronized with structure

## Troubleshooting

### Common Issues

**Module not found:**

- Ensure the module file exports to the correct `flake.modules.<platform>` namespace
- Check that the file is in the `/modules` directory (auto-imported)
- Verify the module name matches what you're importing

**Build failures:**

- Check `nix flake check` for errors
- Review flake inputs are up to date: `nix flake update`
- Verify no conflicts in overlays or module options

**Home-manager activation fails:**

- Check for file conflicts: `home-manager switch --flake . --show-trace`
- Review stow conflicts in `/home` directory
- Ensure state version matches

**Clan deployment issues:**

- Verify SSH access to target machine
- Check machine is in clan inventory
- Review clan configuration: `clan machines show <hostname>`

## Inspiration & References

This configuration draws inspiration from:

- **[hlissner/dotfiles](https://github.com/hlissner/dotfiles)** - Module organization patterns
- **[Mic92/dotfiles](https://github.com/Mic92/dotfiles)** - Clan-core usage and sops integration
- **[berberman/flakes](https://github.com/berberman/flakes)** - Flake-parts architecture
- **[LnL7/nix-darwin](https://github.com/LnL7/nix-darwin)** - Darwin system management
- **[nix-community/home-manager](https://github.com/nix-community/home-manager)** - User environment management

**Documentation:**

- [Flake-parts documentation](https://flake.parts/)
- [Clan-core documentation](https://docs.clan.lol/)
- [NixOS manual](https://nixos.org/manual/nixos/stable/)
- [Nix-darwin manual](https://daiderd.com/nix-darwin/manual/)
- [Home-manager manual](https://nix-community.github.io/home-manager/)

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Follow the module guidelines above
4. Test your changes locally
5. Commit with conventional commits
6. Push to your branch
7. Open a Pull Request

## License

MIT License - See LICENSE file for details
