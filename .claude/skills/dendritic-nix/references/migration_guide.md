# Migrating to the Dendritic Pattern

This guide walks through converting a traditional Nix flake to use the dendritic pattern with flake-parts.

## Overview

The migration process involves:

1. Adopting flake-parts as the flake framework
1. Converting files to flake-parts modules
1. Replacing `specialArgs` with options
1. Consolidating scattered feature files
1. Enabling auto-import for modules
1. Testing and validation

## Step 1: Adopt flake-parts

### Before: Traditional Flake

```nix
# flake.nix
{
  description = "My NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, ... }@inputs: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };
      modules = [
        ./configuration.nix
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
        }
      ];
    };
  };
}
```

### After: flake-parts

```nix
# flake.nix
{
  description = "My NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ];

      imports = [
        # Auto-import all modules from these directories
        inputs.flake-parts.flakeModules.easyOverlay
        ./modules
      ];

      flake = {
        # Flake outputs defined in modules
      };
    };
}
```

## Step 2: Convert Files to Modules

### Before: Plain Nix Configuration

```nix
# modules/ssh.nix
{ config, pkgs, ... }:
{
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
    };
  };

  users.users.myuser.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAA..."
  ];
}
```

### After: flake-parts Module

```nix
# modules/ssh.nix
{ config, lib, pkgs, ... }:
let
  cfg = config.features.ssh;
in
{
  options.features.ssh = {
    enable = lib.mkEnableOption "SSH configuration";

    publicKeys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "ssh-ed25519 AAAA..."
      ];
      description = "SSH public keys for authorized_keys";
    };
  };

  config = lib.mkIf cfg.enable {
    # NixOS configuration
    nixosConfigurations = lib.mapAttrs (name: nixosConfig: {
      services.openssh = {
        enable = true;
        settings = {
          PermitRootLogin = "no";
          PasswordAuthentication = false;
        };
      };

      users.users.myuser.openssh.authorizedKeys.keys = cfg.publicKeys;
    }) config.nixosConfigurations or {};
  };
}
```

## Step 3: Replace specialArgs with Options

### Before: specialArgs Pass-Through

```nix
# flake.nix
{
  outputs = { nixpkgs, ... }@inputs: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      specialArgs = {
        inherit inputs;
        myCustomValue = "production";
        mySecrets = import ./secrets.nix;
      };
      modules = [ ./configuration.nix ];
    };
  };
}

# modules/app.nix
{ config, pkgs, myCustomValue, mySecrets, ... }:
{
  services.myapp = {
    enable = true;
    environment = myCustomValue;
    apiKey = mySecrets.apiKey;
  };
}
```

### After: Options in flake-parts

```nix
# modules/config.nix - Define shared options
{ config, lib, ... }:
{
  options = {
    environment = lib.mkOption {
      type = lib.types.enum [ "production" "staging" "development" ];
      default = "production";
      description = "Deployment environment";
    };

    secrets = lib.mkOption {
      type = lib.types.attrs;
      default = {};
      description = "Secrets configuration";
    };
  };

  config = {
    secrets = import ./secrets.nix;
  };
}

# modules/app.nix - Use options instead of specialArgs
{ config, lib, pkgs, ... }:
let
  cfg = config.features.myapp;
in
{
  options.features.myapp = {
    enable = lib.mkEnableOption "myapp";
  };

  config = lib.mkIf cfg.enable {
    services.myapp = {
      enable = true;
      environment = config.environment;
      apiKey = config.secrets.apiKey;
    };
  };
}
```

## Step 4: Consolidate Scattered Files

### Before: Feature Split Across Multiple Files

```
modules/
├── nixos/
│   ├── vim.nix         # NixOS vim config
│   └── packages.nix    # System packages
├── home-manager/
│   ├── vim.nix         # home-manager vim config
│   └── packages.nix    # User packages
└── shared/
    └── vim-plugins.nix # Shared vim plugins
```

```nix
# modules/nixos/vim.nix
{ config, pkgs, ... }:
{
  environment.systemPackages = [ pkgs.vim ];
}

# modules/home-manager/vim.nix
{ config, pkgs, vimPlugins, ... }:
{
  programs.vim = {
    enable = true;
    plugins = vimPlugins;
  };
}

# modules/shared/vim-plugins.nix
{ pkgs, ... }:
{
  vimPlugins = with pkgs.vimPlugins; [ vim-airline vim-fugitive ];
}
```

### After: Unified Feature Module

```
modules/
├── vim.nix             # All vim config in one place
├── packages.nix        # Shared package lists
└── _experimental.nix   # Excluded from auto-import
```

```nix
# modules/vim.nix
{ config, lib, pkgs, ... }:
let
  cfg = config.features.vim;

  # Define plugins once
  myVimPlugins = with pkgs.vimPlugins; [
    vim-airline
    vim-fugitive
    vim-nix
  ];
in
{
  options.features.vim = {
    enable = lib.mkEnableOption "Vim configuration";

    extraPlugins = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [];
      description = "Additional vim plugins";
    };
  };

  config = lib.mkIf cfg.enable {
    # NixOS: Install vim system-wide
    environment.systemPackages = [ pkgs.vim ];

    # home-manager: Configure vim for users
    home-manager.users = lib.mapAttrs (user: _: {
      programs.vim = {
        enable = true;
        plugins = myVimPlugins ++ cfg.extraPlugins;
        extraConfig = ''
          set number
          set relativenumber
          syntax on
        '';
      };
    }) config.home-manager.users or {};
  };
}
```

## Step 5: Enable Auto-Import

### Manual Import (Before)

```nix
# flake.nix
{
  outputs = inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        ./modules/vim.nix
        ./modules/ssh.nix
        ./modules/packages.nix
        ./modules/networking/vpn.nix
        ./modules/networking/firewall.nix
        # ... many more manual imports
      ];
    };
}
```

### Auto-Import (After)

```nix
# flake.nix
{
  outputs = inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } ({
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ];

      imports = [
        # Auto-import using flake-parts' autoModules
        # or custom auto-import solution
      ];

      flake.autoModules = {
        # Automatically import all .nix files from these dirs
        modulesPath = ./modules;
        exclude = [ "^_" ]; # Exclude files starting with _
      };
    });
}
```

For auto-import, you might use a helper function:

```nix
# lib/auto-import.nix
{ lib }:
let
  # Recursively import all .nix files from a directory
  importDir = dir:
    let
      entries = builtins.readDir dir;
      nixFiles = lib.filterAttrs (name: type:
        (type == "regular" && lib.hasSuffix ".nix" name && !(lib.hasPrefix "_" name))
        || (type == "directory")
      ) entries;
    in
    lib.concatMap (name:
      let path = dir + "/${name}";
      in if entries.${name} == "directory"
         then importDir path
         else [ path ]
    ) (lib.attrNames nixFiles);
in
{
  inherit importDir;
}
```

```nix
# Use in flake.nix
let
  autoImport = import ./lib/auto-import.nix { inherit lib; };
in
{
  imports = autoImport.importDir ./modules;
}
```

## Step 6: Migration Checklist

Use this checklist when migrating each module:

### Per-Module Checklist

- [ ] Convert file to flake-parts module format (`{ config, lib, ... }: { }`)
- [ ] Replace direct configuration with options where appropriate
- [ ] Move hardcoded values to option defaults
- [ ] Remove specialArgs usage
- [ ] Add conditional logic with `lib.mkIf` if using enable options
- [ ] Consolidate related files into single feature module
- [ ] Add assertions for configuration validation
- [ ] Update imports (if not using auto-import)
- [ ] Test module independently with `nix flake check`

### Flake-Level Checklist

- [ ] Add flake-parts to inputs
- [ ] Convert `outputs` to use `flake-parts.lib.mkFlake`
- [ ] Set up `systems` list
- [ ] Configure auto-import or import all modules
- [ ] Remove all specialArgs usage
- [ ] Test with `nix flake check`
- [ ] Rebuild and test actual configuration
- [ ] Validate all features work as before

## Common Migration Pitfalls

### Pitfall 1: Forgetting lib.mkIf

```nix
# Wrong: Always applies configuration
{ config, lib, ... }:
{
  options.features.myapp.enable = lib.mkEnableOption "myapp";

  config = {
    services.myapp.enable = true;  # Always enabled!
  };
}

# Right: Conditional configuration
{ config, lib, ... }:
let
  cfg = config.features.myapp;
in
{
  options.features.myapp.enable = lib.mkEnableOption "myapp";

  config = lib.mkIf cfg.enable {
    services.myapp.enable = true;  # Only when enabled
  };
}
```

### Pitfall 2: Circular Dependencies

```nix
# Wrong: Circular dependency
{ config, lib, ... }:
{
  options.foo = lib.mkOption { default = config.bar; };
  config.bar = config.foo + 1;
}

# Right: Break the cycle
{ config, lib, ... }:
{
  options.foo = lib.mkOption { default = 10; };
  config.bar = config.foo + 1;
}
```

### Pitfall 3: Not Using let Bindings

```nix
# Wrong: Repetitive
{ config, lib, ... }:
{
  config = lib.mkIf config.features.myapp.enable {
    services.myapp.port = config.features.myapp.port;
    services.myapp.host = config.features.myapp.host;
  };
}

# Right: Use let binding
{ config, lib, ... }:
let
  cfg = config.features.myapp;
in
{
  config = lib.mkIf cfg.enable {
    services.myapp.port = cfg.port;
    services.myapp.host = cfg.host;
  };
}
```

### Pitfall 4: Missing Type Specifications

```nix
# Wrong: No type (defaults to anything)
options.myValue = lib.mkOption {
  default = "foo";
};

# Right: Explicit type
options.myValue = lib.mkOption {
  type = lib.types.str;
  default = "foo";
  description = "My configuration value";
};
```

## Testing the Migration

### 1. Incremental Testing

Migrate one module at a time:

```bash
# Test after each module migration
nix flake check

# Build specific configuration
nix build .#nixosConfigurations.myhost.config.system.build.toplevel

# Test in VM
nixos-rebuild build-vm --flake .#myhost
./result/bin/run-myhost-vm
```

### 2. Comparison Testing

Compare before and after:

```bash
# Before migration
nix build .#nixosConfigurations.myhost.config.system.build.toplevel -o result-before

# After migration
nix build .#nixosConfigurations.myhost.config.system.build.toplevel -o result-after

# Compare
nix-store --query --requisites result-before > before.txt
nix-store --query --requisites result-after > after.txt
diff before.txt after.txt
```

### 3. Validation Script

```bash
#!/usr/bin/env bash
# validate-migration.sh

set -e

echo "Running flake check..."
nix flake check

echo "Building all configurations..."
for config in $(nix flake show --json | jq -r '.nixosConfigurations | keys[]'); do
  echo "Building $config..."
  nix build ".#nixosConfigurations.$config.config.system.build.toplevel"
done

echo "Running dendritic validation..."
python scripts/validate_dendritic.py .

echo "All validation passed!"
```

## Example: Complete Migration

See the `examples/migration/` directory for a complete before-and-after example of migrating a traditional flake to dendritic pattern.

## Further Resources

- [flake-parts documentation](https://flake.parts/)
- [flake-parts module arguments](https://flake.parts/module-arguments.html)
- [Dendritic pattern repository](https://github.com/mightyiam/dendritic)
- [Example migrations](https://github.com/mightyiam/infra)
