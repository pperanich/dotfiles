# Flake-Parts Infrastructure Modules

## Overview

The `modules/flake-parts/` directory contains critical infrastructure modules that configure flake-level functionality. These modules are foundational and should be set up early in any dendritic flake.

## Essential Infrastructure Modules

### 1. flake-parts.nix - Module System Foundation

**Purpose**: Imports the flake-parts modules system, enabling the module export pattern.

**What it does**:

- Imports `flake-parts.flakeModules.modules` - enables `flake.modules.<platform>` exports
- Imports `home-manager.flakeModules.home-manager` - integrates home-manager at flake level

**Why it's critical**:
Without this, modules cannot export themselves via `flake.modules.<platform>.<name>`. This is the foundation that makes the dendritic pattern possible.

**Example**:

```nix
{ inputs, ... }: {
  imports = [
    inputs.flake-parts.flakeModules.modules
    inputs.home-manager.flakeModules.home-manager
  ];
}
```

**Must have**: ✅ Absolutely required for dendritic pattern

---

### 2. nixpkgs.nix - Package Configuration

**Purpose**: Configures nixpkgs, overlays, and extends lib with custom functions.

**What it does**:

- Sets up `perSystem.pkgs` with overlays and config
- Extends nixpkgs lib with custom functions
- Defines system list
- Provides default overlay exposing local packages

**Why it's critical**:

- Centralizes nixpkgs configuration (allowUnfree, overlays, etc.)
- Makes `pkgs` available to all modules with consistent configuration
- Extends lib with project-specific helper functions
- Ensures all systems use the same nixpkgs configuration

**Example**:

```nix
{
  inputs,
  withSystem,
  ...
}:
let
  overlays = import ../../overlays { inherit inputs; };

  extendedLib = inputs.nixpkgs.lib.extend (
    _self: _super: {
      my = import ../../lib { inherit (inputs.nixpkgs) lib; };
    }
  );
in {
  systems = import inputs.systems;
  _module.args.lib = extendedLib;

  perSystem = { system, ... }: {
    _module.args.pkgs = import inputs.nixpkgs {
      inherit system;
      config.allowUnfree = true;
      overlays = builtins.attrValues overlays;
    };
  };

  flake.lib = extendedLib;
}
```

**Must have**: ✅ Required for consistent package management

---

### 3. home.nix - Home Manager Integration

**Purpose**: Generates homeConfigurations from home-profiles directory.

**What it does**:

- Exports `flake.homeManagerModules` from the module registry
- Auto-generates homeConfigurations from `home-profiles/`
- Uses helper functions like `lib.my.mkHomeConfigurations`

**Why it's critical**:

- Enables standalone home-manager configurations (not just NixOS submodules)
- Auto-discovers user profiles from `home-profiles/`
- Passes module registry to home configurations
- Supports additional users via generic profile

**Example**:

```nix
{
  inputs,
  config,
  withSystem,
  ...
}: {
  flake.homeManagerModules = config.flake.modules.homeManager or {};

  flake.homeConfigurations = withSystem "x86_64-linux" ({ pkgs, ... }:
    lib.my.mkHomeConfigurations {
      homePath = ../../home-profiles;
      inherit inputs pkgs lib;
      inherit (inputs) home-manager;
      outputs = config.flake;
      extraSpecialArgs = {};
      additionalUsers = [ "generic-user" ];
    }
  );
}
```

**Must have**: ✅ If using standalone home-manager (not just NixOS submodules)

---

### 4. clan.nix - Infrastructure Orchestration (Optional)

**Purpose**: Integrates clan-core for multi-machine deployment and management.

**What it does**:

- Imports `clan-core.flakeModules.default`
- Passes module registry via `specialArgs`
- Defines machine inventory
- Configures clan modules and roles

**Why it's critical (if using clan-core)**:

- Enables declarative multi-machine management
- Provides secrets management with sops-nix
- Enables distributed services and roles
- Auto-generates nixosConfigurations from machines/
- Passes module registry to machine configurations

**Example**:

```nix
{
  inputs,
  config,
  ...
}: {
  imports = [ inputs.clan-core.flakeModules.default ];

  flake.clan = {
    meta.name = "my-clan";

    specialArgs = {
      inherit inputs;
      inherit (config.flake) modules lib;
    };

    inventory = {
      machines."hostname".machineClass = "darwin";
      machines."hostname".tags = [ "laptop" ];
    };
  };
}
```

**Must have**: ⚠️ Only if using clan-core for machine management

---

### 5. fmt.nix - Code Formatting

**Purpose**: Configures treefmt-nix for automatic code formatting and pre-commit hooks.

**What it does**:

- Imports `treefmt-nix.flakeModule` and `git-hooks.flakeModule`
- Configures formatters for Nix, JSON, YAML, shell scripts, etc.
- Sets up pre-commit hooks for automatic formatting
- Defines file exclusions

**Why it's important**:

- Ensures consistent code formatting across the codebase
- Automates formatting on commit (if pre-commit enabled)
- Provides `nix fmt` command for manual formatting
- Catches common issues with linters (statix, deadnix)

**Example**:

```nix
{
  inputs,
  lib,
  ...
}: {
  imports = [
    inputs.treefmt-nix.flakeModule
    inputs.git-hooks.flakeModule
  ];

  perSystem = { self', ... }: {
    treefmt = {
      projectRootFile = "flake.nix";

      programs = {
        deadnix.enable = true;
        nixfmt.enable = true;
        prettier.enable = true;
        shfmt.enable = true;
        statix.enable = true;
      };

      settings.global.excludes = [ "*.png" "*.svg" "LICENSE" ];
    };

    pre-commit.settings.hooks.nix-fmt = {
      enable = true;
      entry = lib.getExe self'.formatter;
    };
  };
}
```

**Must have**: ⭐ Highly recommended for code quality

---

### 6. shell.nix - Development Environment

**Purpose**: Defines development shell with tools and utilities.

**What it does**:

- Creates `devShells.default` with necessary packages
- Includes tools for working with secrets, Nix, and the flake
- Provides treefmt wrapper for formatting
- Can include flake input tools (home-manager, clan-core, etc.)

**Why it's important**:

- Provides consistent development environment across machines
- Makes necessary tools available without global installation
- Includes project-specific utilities
- Enables `nix develop` for quick environment setup

**Example**:

```nix
{
  perSystem = {
    config,
    inputs',
    pkgs,
    ...
  }: {
    devShells.default = pkgs.mkShellNoCC {
      name = "dotfiles-shell";

      packages = [
        pkgs.sops
        pkgs.age
        pkgs.nix-tree
        config.treefmt.build.wrapper
        inputs'.home-manager.packages.home-manager
      ];

      shellHook = ''
        echo "Development environment loaded"
      '';
    };
  };
}
```

**Must have**: ⭐ Highly recommended for contributor experience

---

### 7. unfree-packages.nix - Unfree Package Management

**Purpose**: Centralized management of allowed unfree packages.

**What it does**:

- Defines `nixpkgs.allowedUnfreePackages` option
- Creates predicate function to check package allowlist
- Applies to all configurations (NixOS, Darwin, home-manager)
- Exports allowlist as flake metadata

**Why it's important**:

- Single source of truth for unfree packages
- Prevents accidental inclusion of undesired unfree packages
- Explicit, documented allowlist
- Consistent across all platforms

**Example**:

```nix
{
  lib,
  config,
  ...
}: {
  options.nixpkgs.allowedUnfreePackages = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [];
  };

  config.flake.modules = let
    predicate = pkg: builtins.elem (lib.getName pkg) config.nixpkgs.allowedUnfreePackages;
  in {
    nixos.base.nixpkgs.config.allowUnfreePredicate = predicate;
    homeManager.base = _: {
      nixpkgs.config.allowUnfreePredicate = predicate;
    };
  };
}

# Usage in another module:
# config.nixpkgs.allowedUnfreePackages = [ "vscode" "slack" ];
```

**Must have**: ⭐ Recommended for unfree package management

---

### 8. flake.nix - Flake Metadata

**Purpose**: Defines flake-level metadata and information.

**What it does**:

- Defines `flake.meta` option
- Sets flake URI or other metadata

**Why it's useful**:

- Provides flake identification
- Can store arbitrary metadata
- Useful for documentation and tooling

**Example**:

```nix
{ lib, ... }: {
  options.flake.meta = lib.mkOption {
    type = with lib.types; lazyAttrsOf anything;
  };

  config.flake.meta.uri = "github:username/dotfiles";
}
```

**Must have**: 💡 Optional, but useful for metadata

---

## Recommended Setup Order

When setting up a new dendritic flake, configure these modules in order:

1. **flake-parts.nix** - Enable module system ✅ Required
1. **nixpkgs.nix** - Configure nixpkgs ✅ Required
1. **fmt.nix** - Set up formatting ⭐ Highly recommended
1. **shell.nix** - Development environment ⭐ Highly recommended
1. **unfree-packages.nix** - Unfree management ⭐ Recommended
1. **home.nix** - If using home-manager ✅ Conditional
1. **clan.nix** - If using clan-core ⚠️ Conditional
1. **flake.nix** - Metadata 💡 Optional

## Template Structure

```
modules/flake-parts/
├── flake-parts.nix      # ✅ Required: Module system foundation
├── nixpkgs.nix          # ✅ Required: Package configuration
├── fmt.nix              # ⭐ Recommended: Code formatting
├── shell.nix            # ⭐ Recommended: Dev environment
├── unfree-packages.nix  # ⭐ Recommended: Unfree management
├── home.nix             # ✅ If using home-manager
├── clan.nix             # ⚠️ If using clan-core
└── flake.nix            # 💡 Optional: Metadata
```

## Common Patterns

### Adding Unfree Packages

In any module, add to the allowlist:

```nix
{ config, ... }: {
  config.nixpkgs.allowedUnfreePackages = [
    "vscode"
    "slack"
    "zoom-us"
  ];
}
```

### Extending Lib

In nixpkgs.nix, extend lib with custom functions:

```nix
let
  extendedLib = inputs.nixpkgs.lib.extend (
    _self: _super: {
      my = import ../../lib { inherit (inputs.nixpkgs) lib; };
    }
  );
in {
  _module.args.lib = extendedLib;
}
```

Then use in modules:

```nix
{ lib, ... }: {
  # Use custom lib functions
  imports = [ (lib.my.relativeToRoot "path/to/file") ];
}
```

### Running Formatters

With fmt.nix configured:

```bash
# Format all files
nix fmt

# Check formatting
nix fmt -- --check

# Format specific files
nix fmt path/to/file.nix
```

### Using Dev Shell

With shell.nix configured:

```bash
# Enter dev shell
nix develop

# Run command in dev shell
nix develop -c treefmt

# Use direnv for automatic activation
echo "use flake" > .envrc
direnv allow
```

## Further Reading

- [flake-parts documentation](https://flake.parts/)
- [treefmt-nix documentation](https://github.com/numtide/treefmt-nix)
- [clan-core documentation](https://docs.clan.lol/)
- [home-manager flake module](https://nix-community.github.io/home-manager/index.xhtml#sec-flakes-standalone)
