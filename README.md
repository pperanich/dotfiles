# Nix Configuration

A modular and maintainable Nix configuration for both NixOS and Darwin systems, with a focus on developer experience and system management.

## Organization

The configuration is organized into four main categories:

### Modules (`/modules`)

Modules are system-level configurations that define core functionality and services. They are:

- Stateless and reusable
- System-wide in scope
- Often require privileged access
- Handle service definitions and system defaults

Structure:

```
modules/
├── shared/           # Shared between NixOS and Darwin
│   ├── development.nix  # Development tools and settings
│   ├── security.nix     # Security features and hardening
│   ├── shell.nix       # Shell configuration and utilities
│   └── user.nix        # User account management
├── darwin/           # Darwin-specific modules
│   ├── default.nix     # Core Darwin settings
│   └── wm/            # Window management
│       ├── yabai.nix     # Tiling window manager
│       ├── skhd.nix      # Hotkey daemon
│       └── sketchybar.nix # Status bar
└── nixos/            # NixOS-specific modules
    └── desktop.nix     # Desktop environment settings
```

### Home Manager (`/home-manager`)

Home Manager configurations manage user environments through Nix:

- User package management
- Application configurations
- Environment setup
- Feature management

Structure:

```
home-manager/
├── default.nix      # Base home-manager configuration
├── features/        # User environment features
│   ├── desktop/     # Desktop customization
│   │   ├── shared/  # Shared desktop configs
│   │   └── darwin/  # macOS-specific features
│   ├── development/ # Development environments
│   │   ├── editors/   # Editor configurations
│   │   ├── languages/ # Language-specific setups
│   │   └── tools/     # Development tools
│   ├── shell/      # Shell customization
│   └── work/       # Work-specific setups
└── global/         # Shared home-manager modules
```

### Home (`/home`)

Raw application configurations not managed by Nix:

- Dotfiles
- Application-specific configs
- Manual customizations
- Legacy configurations

Structure:

```
home/
├── .config/         # XDG config directory
├── .ssh/           # SSH configurations
├── .npmrc          # npm configuration
└── [other dotfiles]
```

### Hosts (`/hosts`)

Host configurations define machine-specific settings:

- Hardware configurations
- System-specific overrides
- Host-specific features

Structure:

```
hosts/
├── darwin/          # Darwin hosts
│   └── peranpl1-ml2/  # Specific host configuration
│       ├── default.nix  # Main configuration
│       └── hardware.nix # Hardware-specific settings
└── nixos/           # NixOS hosts
    └── example-host/   # Specific host configuration
        ├── default.nix  # Main configuration
        └── hardware.nix # Hardware-specific settings
```

## When to Use Each

### Use Modules When

- Configuring system-wide services
- Setting up core system functionality
- Managing system defaults
- Implementing security policies
- Defining service dependencies
- Setting up hardware configurations

### Use Home Manager When

- Managing user packages
- Configuring applications through Nix
- Setting up development environments
- Defining user features
- Organizing work environments
- Managing shell configurations

### Use Home When

- Storing traditional dotfiles
- Managing configs not yet in Nix
- Keeping application-specific settings
- Maintaining legacy configurations

### Use Hosts When

- Defining machine-specific settings
- Configuring hardware
- Setting up system-specific overrides
- Managing host-specific features

## Implementation Details

### System Configuration (`flake.nix`)

The system configuration is built using a flexible `mkSystem` function that:

- Supports both NixOS and Darwin systems
- Integrates home-manager
- Provides consistent module structure
- Allows for system-specific customization

### Module System

Modules follow the Nix module system pattern:

- Options are declared using `lib.mkOption`
- Configurations are conditionally applied using `lib.mkIf`
- Dependencies are managed through imports
- Settings are merged using `lib.mkMerge`

### Darwin-Specific Features

Special attention is given to Darwin systems with:

- Window management (yabai, skhd, sketchybar)
- macOS system defaults
- Homebrew integration
- Application management

## Inspiration

This configuration draws inspiration from several excellent Nix configurations:

- [hlissner/dotfiles](https://github.com/hlissner/dotfiles)

  - Module organization
  - Feature separation

- [LnL7/nix-darwin](https://github.com/LnL7/nix-darwin)

  - Darwin system management
  - macOS integration

- [nix-community/home-manager](https://github.com/nix-community/home-manager)

  - User environment management
  - Feature organization

- [kclejeune/system](https://github.com/kclejeune/system)
  - Darwin configuration
  - Homebrew integration

## Usage

1. Clone the repository:

```bash
git clone https://github.com/yourusername/dotfiles.git
```

2. Install Nix:

```bash
# For NixOS, it's already installed
# For Darwin (macOS):
sh <(curl -L https://nixos.org/nix/install)
```

3. Enable flakes:

```bash
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
```

4. Build and activate:

```bash
# For Darwin:
nix build .#darwinConfigurations.peranpl1-ml2.system
./result/sw/bin/darwin-rebuild switch --flake .

# For NixOS:
sudo nixos-rebuild switch --flake .#hostname
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

MIT
