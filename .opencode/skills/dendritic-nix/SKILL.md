---
name: dendritic-nix
description: Implement and manage Nix flakes using the dendritic pattern with flake-parts. Use this skill when creating new NixOS/home-manager/nix-darwin configurations with the dendritic pattern, refactoring existing flakes to dendritic, adding features to dendritic flakes, debugging dendritic configurations, or working with flake-parts modules that follow the file-as-module philosophy.
---

# Dendritic Nix

## Overview

Implement Nix flakes using the dendritic pattern, where every Nix file functions as a flake-parts module. This skill provides best practices, workflows, tools, and templates for creating maintainable, cross-platform Nix configurations that eliminate specialArgs complexity and enable feature co-location.

## When to Use This Skill

Use this skill when:

- Creating a new NixOS, home-manager, or nix-darwin configuration from scratch
- Refactoring a traditional Nix flake to use the dendritic pattern
- Adding new features or modules to an existing dendritic flake
- Debugging configuration issues in dendritic flakes
- Setting up cross-platform Nix configurations (Linux, macOS)
- Seeking guidance on flake-parts module structure and best practices

**Note**: This skill focuses on **flake structure and organization** (the dendritic pattern). For **clan-core infrastructure patterns** (inventory, roles, tags, distributed services like borgbackup), use the **clan-core** skill instead. The two skills are complementary and can be used together.

## Core Principles

The dendritic pattern follows these fundamental principles:

1. **Every file is a flake-parts module**: Modules export themselves via `flake.modules.<platform>.<name>`
1. **Auto-discovery with import-tree**: Files are automatically imported using the import-tree library
1. **Platform-specific exports**: Modules explicitly define which platform(s) they support (nixos/darwin/homeManager)
1. **Feature co-location**: Related NixOS, home-manager, and nix-darwin config can live in one file
1. **Path-based organization**: Directory structure documents intent and purpose
1. **No manual imports needed**: import-tree automatically discovers and loads all `.nix` files

## Quick Start

### Creating a New Dendritic Flake

To create a new flake from scratch:

1. **Copy the template**:

   ```bash
   cp -r assets/template-flake my-flake
   cd my-flake
   ```

1. **Initialize git** (required for flakes):

   ```bash
   git init
   git add .
   ```

1. **Enable direnv** (optional but recommended):

   ```bash
   direnv allow
   ```

   This automatically loads the dev shell when entering the directory.

1. **Edit flake.nix**: Update the description and configure systems

1. **Add feature modules**: Create modules in `modules/` for features

   ```bash
   python path/to/scripts/scaffold_module.py ssh-config -t with-options
   ```

1. **Test the flake**:

   ```bash
   nix flake check
   ```

### Adding a Feature to an Existing Flake

To add a new feature module:

1. **Scaffold the module**:

   ```bash
   python scripts/scaffold_module.py <feature-name> -t <type>
   ```

   Types: `simple`, `with-options`, `cross-platform`, `flake-module`

1. **Edit the generated module**: Add configuration following the pattern

1. **Validate**:

   ```bash
   python scripts/validate_dendritic.py .
   nix flake check
   ```

## Workflow Decision Tree

Use this decision tree to determine the appropriate workflow:

```
Starting point?
│
├─ New flake from scratch
│  └─> Follow "Creating a New Dendritic Flake" workflow
│
├─ Existing traditional flake to convert
│  └─> Follow "Migrating to Dendritic" workflow
│
├─ Existing dendritic flake to extend
│  └─> Follow "Adding Features" workflow
│
├─ Configuration not working
│  └─> Follow "Debugging Dendritic Flakes" workflow
│
└─ Need to search for packages/options
   └─> Use `nix_search.py` tool
```

## Creating a New Dendritic Flake

### Step 1: Set Up Project Structure

Start with the template or create manually:

```
my-flake/
├── flake.nix          # Entry point using flake-parts
├── modules/           # Feature modules (auto-imported)
│   └── example.nix
├── .envrc             # Direnv config (auto-loads dev shell)
└── .gitignore
```

Copy from `assets/template-flake/` or create from scratch.

**Note:** The `.envrc` file contains `use flake` which tells direnv to automatically load the flake's dev shell when entering the directory. Run `direnv allow` after copying the template to enable this.

### Step 2: Configure flake.nix

The flake entry point should use flake-parts with import-tree:

```nix
{
  description = "My dendritic configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    import-tree.url = "github:vic/import-tree";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; }
      (inputs.import-tree ./modules);
}
```

Note: `import-tree ./modules` automatically discovers and imports all `.nix` files in the modules directory, returning a flake-parts configuration.

### Step 3: Set Up Infrastructure Modules

Before creating feature modules, set up essential flake-parts infrastructure in `modules/flake-parts/`:

**Required:**

1. **flake-parts.nix** - Enable module system (copy from `assets/flake-parts-modules/`)
1. **nixpkgs.nix** - Configure nixpkgs and overlays

**Highly Recommended:**
3\. **fmt.nix** - Code formatting with treefmt (copy from `assets/flake-parts-modules/`)
4\. **shell.nix** - Development environment (copy from `assets/flake-parts-modules/`)
5\. **unfree-packages.nix** - Unfree package management (copy from `assets/flake-parts-modules/`)

**Conditional:**
6\. **home.nix** - If using standalone home-manager
7\. **clan.nix** - If using clan-core for machine management

- **For clan-specific patterns** (inventory, roles, tags, vars), use the **clan-core** skill
- Dendritic handles HOW to structure the flake; clan-core handles WHAT to configure for infrastructure

See `references/flake_parts_infrastructure.md` for detailed explanations.

### Step 4: Create Feature Modules

Create modules for each feature. Use the scaffold script:

```bash
python scripts/scaffold_module.py ssh -t cross-platform
```

Or see example modules in `assets/example-modules/`.

### Step 5: Validate and Test

```bash
# Validate dendritic conventions
python scripts/validate_dendritic.py .

# Check flake
nix flake check

# Format Nix files (if fmt.nix configured)
nix fmt

# Or use the Python wrapper
python scripts/format_nix.py .
```

## Adding Features to an Existing Dendritic Flake

### Step 1: Scaffold the Module

Generate boilerplate:

```bash
python scripts/scaffold_module.py <feature-name> -t <type>
```

Module types:

- **simple**: Basic configuration without options
- **with-options**: Module with enable option and configuration options
- **cross-platform**: Configures NixOS, home-manager, and nix-darwin
- **flake-module**: Flake-level outputs and configuration

### Step 2: Implement the Feature

Edit the generated module following the pattern:

```nix
{ config, lib, pkgs, ... }:
let
  cfg = config.features.myFeature;
in
{
  # Define options
  options.features.myFeature = {
    enable = lib.mkEnableOption "my feature";
    # Add more options as needed
  };

  # Conditional configuration
  config = lib.mkIf cfg.enable {
    # Add configuration here
  };
}
```

### Step 3: Reference Documentation

For detailed patterns and examples, read:

- `references/dendritic_pattern.md` - Core pattern explanation
- `references/flake_parts_modules.md` - Module writing guide
- `references/common_patterns.md` - Common module patterns
- `assets/example-modules/` - Complete example modules

### Step 4: Validate

```bash
python scripts/validate_dendritic.py .
nix flake check
```

## Migrating to Dendritic Pattern

### Overview

Converting a traditional flake to dendritic involves:

1. Adopting flake-parts
1. Converting files to modules
1. Replacing specialArgs with options
1. Consolidating scattered files
1. Enabling auto-import

### Step-by-Step Process

**Consult `references/migration_guide.md` for complete migration instructions.**

Key migration steps:

1. **Add flake-parts to inputs**:

   ```nix
   inputs.flake-parts.url = "github:hercules-ci/flake-parts";
   ```

1. **Convert outputs to flake-parts**:

   ```nix
   outputs = inputs@{ flake-parts, ... }:
     flake-parts.lib.mkFlake { inherit inputs; } { ... };
   ```

1. **Convert each file to module format**:

   ```nix
   # Before: Plain config
   { pkgs, ... }: { services.ssh.enable = true; }

   # After: flake-parts module
   { config, lib, pkgs, ... }: {
     config = { services.ssh.enable = true; };
   }
   ```

1. **Replace specialArgs with options**:
   See migration guide for detailed examples.

1. **Test incrementally**: After each module migration, run `nix flake check`

## Debugging Dendritic Flakes

### Common Issues and Solutions

#### Issue 1: Module Not Being Imported

**Symptoms**: Module exists but configuration not applied

**Solutions**:

- Ensure file doesn't start with `_` (excluded from import)
- Check file is in a directory covered by auto-import
- Verify module returns proper structure: `{ config, ... }: { }`

#### Issue 2: Infinite Recursion / Circular Dependency

**Symptoms**: `error: infinite recursion encountered`

**Solutions**:

- Check for options that default to other config values
- Use `lib.mkDefault` for option defaults that read from config
- Break cycles by introducing intermediate options

Example fix:

```nix
# Wrong: Circular
options.foo = lib.mkOption { default = config.bar; };
config.bar = config.foo + 1;

# Right: Break cycle
options.foo = lib.mkOption { default = 10; };
config.bar = config.foo + 1;
```

#### Issue 3: specialArgs Not Available

**Symptoms**: `error: attribute 'myCustomArg' missing`

**Solutions**:

- Don't use specialArgs in dendritic pattern
- Define options for shared values:
  ```nix
  options.myCustomValue = lib.mkOption { ... };
  config.myCustomValue = "value";
  ```

#### Issue 4: Configuration Not Conditional

**Symptoms**: Feature enabled when it shouldn't be

**Solutions**:

- Wrap config in `lib.mkIf`:
  ```nix
  config = lib.mkIf cfg.enable { ... };
  ```

### Validation Tools

Use the validation script to catch common issues:

```bash
python scripts/validate_dendritic.py .
```

This checks for:

- Files that don't follow flake-parts module pattern
- Hardcoded import statements
- specialArgs usage (anti-pattern)
- File naming conventions

## Searching for Packages and Options

Use the lightweight search tool instead of web search:

```bash
# Search packages and options
python scripts/nix_search.py vim

# Search only packages
python scripts/nix_search.py vim -t packages

# Search only options
python scripts/nix_search.py networking -t options

# Limit results
python scripts/nix_search.py python -l 5

# JSON output
python scripts/nix_search.py rust -j
```

This searches NixOS packages and options using the search.nixos.org API.

## Formatting Nix Files

Format Nix files consistently:

```bash
# Format current directory
python scripts/format_nix.py .

# Format specific files
python scripts/format_nix.py modules/ssh.nix modules/vim.nix

# Use specific formatter
python scripts/format_nix.py . -f nixpkgs-fmt
```

Available formatters (tried in order):

1. treefmt (respects treefmt.toml)
1. nixpkgs-fmt
1. alejandra
1. nixfmt

## Module Patterns and Best Practices

### Pattern: Module Export Structure

Modules export themselves by defining `flake.modules.<platform>.<name>`:

```nix
# modules/editors/nvim.nix
_: {
  flake.modules.homeManager.nvim = { pkgs, ... }: {
    home.sessionVariables.EDITOR = "nvim";

    home.packages = with pkgs; [
      ripgrep
      fd
      fzf
    ];

    programs.neovim = {
      enable = true;
      package = pkgs.neovim;
    };
  };
}
```

### Pattern: Cross-Platform Module

A single module can export for multiple platforms:

```nix
# modules/network/ssh.nix
_: {
  # NixOS SSH server
  flake.modules.nixos.ssh-server = { config, lib, ... }: {
    services.openssh = {
      enable = true;
      settings.PermitRootLogin = "no";
    };
  };

  # macOS SSH client
  flake.modules.darwin.ssh-client = _: {
    programs.ssh.extraConfig = ''
      Host *
        Protocol 2
    '';
  };

  # home-manager SSH tools
  flake.modules.homeManager.ssh-tools = { pkgs, ... }: {
    home.packages = with pkgs; [ openssh mosh ];
  };
}
```

See `references/common_patterns.md` for 12+ complete patterns.

### Pattern: Using Modules in Machine Configurations

The exported modules are made available to machine configurations via `specialArgs`:

```nix
# modules/flake-parts/clan.nix (or similar for non-clan setups)
{ inputs, config, ... }: {
  flake.clan = {
    specialArgs = {
      inherit inputs;
      inherit (config.flake) modules lib;  # Pass module registry!
    };
  };
}
```

**Note**: This pattern shows HOW to integrate dendritic modules with clan's specialArgs. For clan-specific infrastructure patterns (inventory, roles, tags, distributed services), use the **clan-core** skill.

Then in machine configurations:

```nix
# machines/hostname/configuration.nix
{ lib, modules, ... }: {
  imports = with modules.darwin; [
    # Import exported modules by name
    base
    sops
    rust
    yabai
    skhd
  ];

  networking.hostName = "hostname";
}
```

**How it works:**

1. Modules export themselves via `flake.modules.<platform>.<name>`
1. `specialArgs` passes the module registry to machine configs
1. Machine configs import modules with `with modules.<platform>; [ ... ]`
1. Clean, declarative imports without file paths

### Pattern: User Modules with home-profiles

User modules bridge system-level user configuration with home-manager:

```nix
# modules/users/username.nix
_: {
  flake.modules.nixos.username = { lib, pkgs, config, ... }: {
    # System user
    users.users.username = {
      openssh.authorizedKeys.keys = [ ... ];
      shell = pkgs.zsh;
    };

    # home-manager integration
    home-manager.users.username.imports = lib.flatten [
      (_: import (lib.my.relativeToRoot "home-profiles/username") {
        inherit pkgs;
        inherit (config.flake.modules) homeManager;  # Pass registry!
      })
    ];
  };
}
```

Then in home-profiles:

```nix
# home-profiles/username/default.nix
{ homeManager, ... }: {
  imports = with homeManager; [
    base nvim rust zsh tools
  ];
  home.username = "username";
}
```

**Architecture:**

- `modules/users/` - System user + home-manager integration
- `home-profiles/` - User-specific home-manager configuration
- `modules/*/` - Reusable homeManager modules

This separates system-level user config from user-specific package/dotfile selections.

### Pattern: Shared Package Overlays

Create overlays accessible to all configurations:

```nix
# modules/overlays/custom.nix
{ inputs, ... }: {
  flake.overlays.custom = final: prev: {
    myapp = prev.callPackage ../../pkgs/myapp.nix {};
  };
}
```

### Best Practices

1. **One feature per module**: Keep modules focused and cohesive
1. **Use options for configuration**: Define clear interfaces
1. **Namespace options**: Use `config.features.myFeature` not `config.myFeature`
1. **Document options**: Add description and example
1. **Validate early**: Use assertions to catch configuration errors
1. **Name by purpose**: File names reflect what, not how
1. **Use let bindings**: `let cfg = config.features.myFeature;` for readability
1. **Conditional config**: Wrap in `lib.mkIf cfg.enable` when using enable options
1. **Test incrementally**: Run `nix flake check` after changes
1. **Keep modules small**: Break large features into sub-modules

## Resources

### scripts/

Lightweight Python tools for Nix development:

- **nix_search.py**: Search NixOS packages and options
- **validate_dendritic.py**: Validate flake follows dendritic conventions
- **scaffold_module.py**: Generate new module boilerplate
- **format_nix.py**: Format Nix files with available formatters

Execute scripts directly:

```bash
python scripts/nix_search.py <query>
python scripts/validate_dendritic.py <path>
python scripts/scaffold_module.py <name> -t <type>
python scripts/format_nix.py <paths>
```

### references/

Detailed documentation loaded as needed:

- **dendritic_pattern.md**: Complete pattern explanation with philosophy and conventions
- **flake_parts_modules.md**: Guide to writing flake-parts modules with all patterns
- **common_patterns.md**: 12+ complete module patterns for common use cases
- **migration_guide.md**: Step-by-step guide for converting traditional flakes

Read these when:

- First learning the dendritic pattern → `dendritic_pattern.md`
- Writing complex modules → `flake_parts_modules.md`
- Looking for specific patterns → `common_patterns.md`
- Converting existing flakes → `migration_guide.md`
- Setting up infrastructure → `flake_parts_infrastructure.md`

### assets/

Templates and examples for quick starts:

- **template-flake/**: Minimal working dendritic flake template
- **example-modules/**: Complete example modules (ssh.nix, vim.nix, git.nix)
- **flake-parts-modules/**: Essential infrastructure modules
  - `fmt.nix` - treefmt configuration for code formatting
  - `shell.nix` - Development shell template
  - `unfree-packages.nix` - Centralized unfree package management
  - `flake-parts.nix` - Module system foundation

Use these to:

- Bootstrap new flakes → copy `template-flake/`
- Reference complete examples → study `example-modules/`
- Set up infrastructure → copy from `flake-parts-modules/`
- Learn module structure → examine working code

## Example Workflows

### Example 1: Creating SSH Configuration

```bash
# Scaffold the module
python scripts/scaffold_module.py ssh -t cross-platform -o modules/ssh.nix

# Edit modules/ssh.nix - or reference assets/example-modules/ssh.nix

# Validate
python scripts/validate_dendritic.py .
nix flake check

# Format
python scripts/format_nix.py modules/ssh.nix
```

### Example 2: Finding and Adding a Package

```bash
# Search for package
python scripts/nix_search.py neovim -t packages

# Add to module
cat >> modules/editor.nix << 'EOF'
{ config, lib, pkgs, ... }:
{
  config = {
    environment.systemPackages = [ pkgs.neovim ];
  };
}
EOF

# Test
nix flake check
```

### Example 3: Debugging Configuration Issue

```bash
# Validate dendritic conventions
python scripts/validate_dendritic.py .

# Check for common issues:
# - Files starting with _ (excluded)
# - specialArgs usage
# - Hardcoded imports

# Run flake check
nix flake check

# Check specific configuration
nix eval .#nixosConfigurations.myhost.config.services.openssh.enable
```

## Further Reading

- [flake-parts documentation](https://flake.parts/)
- [Dendritic pattern repository](https://github.com/mightyiam/dendritic)
- [mightyiam/infra example](https://github.com/mightyiam/infra)
- [NixOS manual](https://nixos.org/manual/nixos/stable/)
- [home-manager manual](https://nix-community.github.io/home-manager/)
- [nix-darwin manual](https://daiderd.com/nix-darwin/)
