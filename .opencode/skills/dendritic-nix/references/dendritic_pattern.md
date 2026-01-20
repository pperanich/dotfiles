# The Dendritic Pattern for Nix Flakes

## Core Concept

The dendritic pattern is a flake-parts usage methodology where **every Nix file is automatically discovered and imported** using `import-tree`. Modules export themselves by defining attributes on `flake.modules.<platform>.<name>`, creating a self-organizing, tree-like structure.

### Key Principle

**Every file is a flake-parts module that:**

- Is automatically discovered by `import-tree` (no manual imports)
- Exports itself via `flake.modules.<platform>.<name>` attributes
- Can define platform-specific configurations (nixos, darwin, homeManager)
- Can access inputs and define flake-level outputs
- Organizes by path (directory structure = module namespace)

## Why Dendritic?

Traditional Nix flake organization faces several challenges:

1. **specialArgs Hell**: Passing values through `specialArgs` and `extraSpecialArgs` becomes unwieldy
1. **Scattered Features**: Related code dispersed across NixOS, home-manager, and utility files
1. **Import Complexity**: Manual import management and circular dependency risks
1. **Limited Reusability**: Difficult to share modules across different configuration types

The dendritic pattern solves these by:

- **Unified State**: `config` is the single source of truth
- **Feature Co-location**: All aspects of a feature in one file
- **Auto-discovery**: No manual imports needed
- **Cross-platform**: Single module works across NixOS, home-manager, and nix-darwin

## Directory Structure

The pattern doesn't enforce rigid structure, but common conventions include:

```
my-flake/
├── flake.nix                 # Entry point using flake-parts + import-tree
├── modules/                  # Feature modules (auto-imported by import-tree)
│   ├── flake-parts/         # Flake-level configuration
│   │   ├── nixpkgs.nix      # Nixpkgs configuration & overlays
│   │   ├── home.nix         # home-manager integration
│   │   └── clan.nix         # clan-core integration (if used)
│   ├── editors/             # Editor configurations
│   │   ├── nvim.nix
│   │   └── vscode.nix
│   ├── shell/               # Shell and CLI tools
│   │   ├── zsh.nix
│   │   └── tools.nix
│   ├── users/               # User account modules
│   │   ├── username.nix     # System user + home-manager integration
│   │   └── username_id_ed25519.pub
│   ├── network/             # Network services
│   │   ├── ssh-server.nix
│   │   └── tailscale.nix
│   └── _experimental.nix    # Underscore prefix = excluded from auto-import
├── home-profiles/            # User-specific home-manager configurations
│   ├── username/
│   │   └── default.nix      # Imports homeManager modules
│   └── generic/             # Shared/service account profile
│       └── default.nix
├── machines/                 # Machine-specific configurations
│   ├── hostname/
│   │   └── configuration.nix # Imports platform-specific modules
│   └── another-host/
│       └── configuration.nix
├── lib/                      # Helper functions
│   └── default.nix          # Custom library functions
└── overlays/                 # Package overlays
    └── default.nix
```

### Naming Conventions

- **Lowercase with hyphens**: `ssh-config.nix`, not `SSHConfig.nix`
- **Feature-based names**: Name reflects what it does, not how
- **Underscore prefix for exclusion**: `_test.nix` won't be auto-imported
- **Path reflects purpose**: Directory structure documents intent

## Module Pattern

Every module exports itself by defining flake attributes:

```nix
# modules/editors/nvim.nix
_: {
  # home-manager module
  flake.modules.homeManager.nvim = { pkgs, ... }: {
    programs.neovim.enable = true;
    home.packages = with pkgs; [ ripgrep fd ];
  };

  # NixOS module (optional)
  flake.modules.nixos.nvim = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.neovim ];
  };

  # Darwin module (optional)
  flake.modules.darwin.nvim = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.neovim ];
  };
}
```

The outer function takes `_` because import-tree provides flake-parts arguments, but individual modules usually don't need them—they export platform-specific sub-modules instead.

### Accessing Shared State

Read from `config`:

```nix
{ config, lib, ... }:
{
  config = {
    # Read another module's option
    services.nginx.enable = config.myFeature.enable;

    # Access flake-level config
    nixpkgs.overlays = config.myFeature.overlays;
  };
}
```

### Contributing to Shared State

Write to `config`:

```nix
{ config, lib, ... }:
{
  options.myFeature.overlays = lib.mkOption {
    type = lib.types.listOf lib.types.anything;
    default = [];
  };

  config.myFeature.overlays = [
    (final: prev: { myPackage = ...; })
  ];
}
```

## Cross-Platform Modules

A single module can configure multiple platforms:

```nix
{ config, lib, pkgs, ... }:
{
  # NixOS configuration
  nixosConfigurations.myhost.config = {
    services.openssh.enable = true;
  };

  # home-manager configuration (works on any platform)
  home-manager.users.myuser = {
    programs.ssh.enable = true;
    programs.ssh.matchBlocks = {
      "github.com" = {
        identityFile = "~/.ssh/id_ed25519";
      };
    };
  };

  # nix-darwin configuration (macOS)
  darwinConfigurations.mymac.config = {
    services.nix-daemon.enable = true;
  };
}
```

## Auto-Discovery with import-tree

The dendritic pattern uses `import-tree` for automatic module discovery:

```nix
# flake.nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    import-tree.url = "github:vic/import-tree";
  };

  outputs = inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; }
      (inputs.import-tree ./modules);
}
```

**How import-tree works:**

1. Recursively scans `./modules` for all `.nix` files
1. Imports each file as a flake-parts module
1. Merges all module exports into the flake configuration
1. Files starting with `_` are excluded from import

**Benefits:**

- Zero manual imports - just add a file and it's automatically included
- Files can be freely moved and renamed
- Directory structure organizes features naturally
- No import order concerns - flake-parts handles merging

Files can be moved and reorganized without updating any import statements.

## Anti-Patterns

### ❌ Don't Use specialArgs for Module Communication

```nix
# Avoid: Passing custom values via specialArgs between modules
specialArgs = { myCustomValue = "foo"; };
```

Instead, export values via flake attributes or use flake-level options.

**Note:** `specialArgs` is still appropriate for passing flake-level context (like `inputs`, `outputs`) to platform-specific configurations (NixOS, home-manager, darwin). This is seen in helper functions like `mkHomeConfigurations` where `extraSpecialArgs` passes the module registry.

### ❌ Don't Scatter Related Code

```nix
# Bad: Scattered across multiple files
modules/nixos/ssh.nix      # NixOS SSH config
modules/home/ssh.nix        # home-manager SSH config
modules/common/ssh-keys.nix # Shared SSH keys
```

Instead, co-locate in one module:

```nix
# Good: Single feature module
modules/ssh.nix  # Handles NixOS, home-manager, and shared state
```

### ❌ Don't Hardcode Imports

```nix
# Bad: Manual imports
imports = [
  ./modules/ssh.nix
  ./modules/vim.nix
  ./modules/networking/vpn.nix
];
```

Instead, use auto-discovery:

```nix
# Good: Auto-import configured in flake-parts
# No manual import list needed
```

## Best Practices

1. **One Feature Per File**: Each module implements a single, cohesive feature
1. **Use Options for Configuration**: Define options for values other modules need
1. **Leverage Config for State**: Read and write to `config` for shared data
1. **Name by Purpose**: File names reflect the feature, not the implementation
1. **Organize by Feature**: Group related modules in directories
1. **Exclude WIP Files**: Use underscore prefix for experimental modules
1. **Document Module Purpose**: Brief comment at top of each module
1. **Keep Modules Small**: Break large features into sub-modules
1. **Test Incrementally**: Add `nix flake check` to CI
1. **Use Assertions**: Validate configuration assumptions with `assertions`

## Migration from Traditional Flakes

### Step 1: Adopt flake-parts

```nix
# Before: Traditional flake
outputs = { self, nixpkgs, ... }: {
  nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
    # ...
  };
};

# After: flake-parts
outputs = inputs@{ flake-parts, ... }:
  flake-parts.lib.mkFlake { inherit inputs; } {
    # ...
  };
```

### Step 2: Convert Files to Modules

```nix
# Before: Plain Nix file
{ pkgs, ... }:
{
  services.openssh.enable = true;
}

# After: flake-parts module
{ config, lib, pkgs, ... }:
{
  config = {
    services.openssh.enable = true;
  };
}
```

### Step 3: Replace specialArgs with Options

```nix
# Before: specialArgs
specialArgs = { myValue = "foo"; };

# After: Options in module
options.myValue = lib.mkOption {
  type = lib.types.str;
  default = "foo";
};
```

### Step 4: Enable Auto-Import

Configure flake-parts to auto-import modules from directories.

### Step 5: Consolidate Related Files

Merge scattered NixOS, home-manager, and utility files into unified feature modules.

## Using Modules in Configurations

The key to the dendritic pattern is how exported modules are consumed. Modules export themselves via `flake.modules.<platform>.<name>`, creating a module registry. This registry is then passed to machine/home configurations via `specialArgs`:

### With clan-core

```nix
# modules/flake-parts/clan.nix
{ inputs, config, ... }: {
  imports = [ inputs.clan-core.flakeModules.default ];

  flake.clan = {
    meta.name = "my-clan";

    specialArgs = {
      inherit inputs;
      inherit (config.flake) modules lib;  # Pass module registry
    };
  };
}
```

Machine configurations can then import modules cleanly:

```nix
# machines/hostname/configuration.nix
{ lib, modules, ... }: {
  imports = with modules.darwin; [
    base        # from modules/system/base.nix
    sops        # from modules/system/sops.nix
    peranpl1    # from modules/users/peranpl1.nix
    rust        # from modules/languages/rust.nix
    yabai       # from modules/desktop/yabai.nix
    skhd        # from modules/desktop/skhd.nix
  ];

  clan.core.networking.targetHost = "root@hostname";
  networking.hostName = "hostname";
  nixpkgs.hostPlatform = "aarch64-darwin";
}
```

### Without clan-core

For non-clan setups, pass the module registry directly:

```nix
# modules/flake-parts/configurations.nix
{ inputs, config, ... }: {
  flake.darwinConfigurations.hostname = inputs.darwin.lib.darwinSystem {
    modules = [ ./machines/hostname/configuration.nix ];
    specialArgs = {
      inherit inputs;
      inherit (config.flake) modules lib;
    };
  };
}
```

### Why This Works

1. **Module Discovery**: import-tree loads all modules from `./modules`
1. **Module Export**: Each module exports via `flake.modules.<platform>.<name>`
1. **Registry Creation**: flake-parts merges all exports into `config.flake.modules`
1. **Registry Injection**: `specialArgs` passes the registry to configurations
1. **Clean Imports**: Configurations import by name, not file path

This pattern eliminates hardcoded paths and creates a self-documenting module system where:

- Adding a module = creating a file (auto-discovered)
- Using a module = referencing its name (from registry)
- No import boilerplate or path management needed

### User Modules and home-profiles

A key architectural pattern separates system-level user configuration from user-specific home-manager configuration:

**User Module (modules/users/username.nix):**

- Creates system user account (UID, groups, shell, SSH keys)
- Configures system-level user settings
- Integrates home-manager by importing from `home-profiles/username/`
- Passes homeManager module registry to the profile

**Home Profile (home-profiles/username/default.nix):**

- Imports homeManager modules by name
- Defines user-specific package selections
- Configures user-specific program settings
- Sets up user dotfiles and environment

This separation allows:

- Reusable home-manager modules across different users
- Different users with different package/program selections
- Consistent system user setup across NixOS and Darwin
- Clean separation of concerns (system vs. user level)

## Real-World Examples

- **pperanich/dotfiles**: Full dendritic setup with clan-core integration
- **mightyiam/dotfiles**: Personal dotfiles using dendritic
- **mightyiam/infra**: Infrastructure configuration with dendritic
- **Pol Dellaiera's configs**: Documented adoption and benefits
- **Gaétan Lepage's configs**: Large-scale dendritic usage

## Further Reading

- [flake-parts documentation](https://flake.parts/)
- [Dendritic pattern discussion](https://github.com/mightyiam/dendritic)
- [flake-parts modules tutorial](https://flake.parts/module-arguments.html)
- [clan-core documentation](https://docs.clan.lol/)
- [import-tree library](https://github.com/vic/import-tree)
