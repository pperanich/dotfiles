# Common Dendritic Module Patterns

## Pattern 1: Module Registry with clan-core

Enable clean module imports in machine configurations by passing the module registry via `specialArgs`.

**Setup (in modules/flake-parts/clan.nix):**

```nix
{ inputs, config, ... }: {
  imports = [ inputs.clan-core.flakeModules.default ];

  flake.clan = {
    meta.name = "my-clan";

    # Pass module registry to all machine configurations
    specialArgs = {
      inherit inputs;
      inherit (config.flake) modules lib;
    };

    # Optional: Define inventory
    inventory = {
      machines."hostname".machineClass = "darwin";
      machines."hostname".tags = [ "laptop" ];
    };
  };
}
```

**Usage (in machines/hostname/configuration.nix):**

```nix
{ lib, modules, ... }: {
  imports = with modules.darwin; [
    # System modules
    base
    sops

    # User modules
    myuser

    # Development
    rust
    nvim

    # Desktop
    yabai
    skhd
    sketchybar
  ];

  clan.core.networking.targetHost = "root@hostname";
  networking.hostName = "hostname";
  nixpkgs.hostPlatform = "aarch64-darwin";
}
```

**Benefits:**

- Import modules by name, not path
- Self-documenting (see what features are enabled)
- No hardcoded file paths
- Works with clan-core's automatic configuration discovery

## Pattern 2: Module Registry without clan-core

For non-clan setups, manually pass the registry:

```nix
{ inputs, config, ... }: {
  flake.darwinConfigurations.hostname = inputs.darwin.lib.darwinSystem {
    system = "aarch64-darwin";
    modules = [ ./machines/hostname/configuration.nix ];
    specialArgs = {
      inherit inputs;
      inherit (config.flake) modules lib;
    };
  };

  flake.nixosConfigurations.hostname = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    modules = [ ./machines/hostname/configuration.nix ];
    specialArgs = {
      inherit inputs;
      inherit (config.flake) modules lib;
    };
  };
}
```

## Pattern 3: User Module with home-profiles

User modules bridge system-level user configuration with home-manager, importing user-specific configs from `home-profiles/`.

**User Module (modules/users/username.nix):**

```nix
_: {
  # NixOS user configuration
  flake.modules.nixos.username = { lib, pkgs, config, ... }: {
    # Create system user
    users.users.username = {
      openssh.authorizedKeys.keys = [
        (builtins.readFile ./username_id_ed25519.pub)
      ];
      shell = pkgs.zsh;
      packages = [ pkgs.home-manager ];
    };

    programs.zsh.enable = true;
    nix.settings.trusted-users = [ "username" ];

    # Import home-manager config from home-profiles/
    home-manager = {
      useUserPackages = true;
      extraSpecialArgs = { inherit pkgs; };
      users.username.imports = lib.flatten [
        (_: import (lib.my.relativeToRoot "home-profiles/username") {
          inherit pkgs;
          inherit (config.flake.modules) homeManager;  # Pass registry!
        })
      ];
    };
  };

  # Darwin user configuration
  flake.modules.darwin.username = { lib, pkgs, modules, ... }: {
    users.users.username = {
      openssh.authorizedKeys.keys = [
        (builtins.readFile ./username_id_ed25519.pub)
      ];
      shell = pkgs.zsh;
      home = "/Users/username";
    };

    nix.settings.trusted-users = [ "username" ];

    # Import home-manager config from home-profiles/
    home-manager = {
      useUserPackages = true;
      extraSpecialArgs = { inherit pkgs; };
      users.username.imports = lib.flatten [
        (_: import (lib.my.relativeToRoot "home-profiles/username") {
          inherit pkgs;
          inherit (modules) homeManager;  # Pass registry!
        })
      ];
    };
  };
}
```

**Home Profile (home-profiles/username/default.nix):**

```nix
{ homeManager, ... }: {
  imports = with homeManager; [
    # Core
    base
    sops

    # Shell
    zsh

    # Editors
    nvim
    vscode

    # Languages
    rust

    # Utilities
    networkUtilities
    fileExploration
    tools
  ];

  home.username = "username";
}
```

**How it works:**

1. **System User**: Module creates the system-level user account with SSH keys, shell, groups
1. **home-manager Integration**: Module configures home-manager for the user
1. **Registry Pass-Through**: `inherit (config.flake.modules) homeManager` passes the homeManager module registry
1. **Profile Import**: home-profile imports homeManager modules by name
1. **Separation of Concerns**:
    - `modules/users/` = system user + home-manager integration
    - `home-profiles/` = user-specific home-manager configuration
    - `modules/*/` = reusable homeManager modules

**Benefits:**

- Clean separation: system config vs. user config
- Reusable home-manager modules across users
- Each user has their own profile with different module selections
- No duplication of system user setup logic

## Pattern 4: Cross-Platform Feature Module

Configure a feature across NixOS, home-manager, and nix-darwin from a single file.

```nix
{ config, lib, pkgs, ... }:
let
  cfg = config.features.ssh;
in
{
  options.features.ssh = {
    enable = lib.mkEnableOption "SSH configuration";

    publicKeys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "SSH public keys";
    };
  };

  config = lib.mkIf cfg.enable {
    # NixOS: Enable sshd
    nixosConfigurations = lib.mapAttrs (name: nixosConfig: {
      services.openssh = {
        enable = true;
        settings.PermitRootLogin = "no";
        settings.PasswordAuthentication = false;
      };

      users.users.myuser.openssh.authorizedKeys.keys = cfg.publicKeys;
    }) config.nixosConfigurations or {};

    # home-manager: Configure SSH client
    home-manager.users = lib.mapAttrs (user: homeConfig: {
      programs.ssh = {
        enable = true;
        matchBlocks = {
          "*.github.com" = {
            identityFile = "~/.ssh/id_ed25519";
            identitiesOnly = true;
          };
        };
      };
    }) config.home-manager.users or {};

    # nix-darwin: macOS SSH configuration
    darwinConfigurations = lib.mapAttrs (name: darwinConfig: {
      services.nix-daemon.enable = true;
    }) config.darwinConfigurations or {};
  };
}
```

## Pattern 2: Input Management Module

Manage flake inputs and their configuration in a dedicated module.

```nix
{ config, lib, inputs, ... }:
{
  # Dedupe inputs (prevent duplication)
  options.inputOverrides = lib.mkOption {
    type = lib.types.attrs;
    default = {};
    description = "Input override configuration";
  };

  config = {
    # Configure common overlays from inputs
    nixpkgs.overlays = [
      inputs.rust-overlay.overlays.default
      inputs.neovim-nightly.overlay
    ];

    # Track which inputs are deduplication-only
    inputOverrides = {
      # Inputs prefixed with dedupe_ exist only for .follows
      dedupe_nixpkgs.follows = "nixpkgs";
      dedupe_flake-utils.follows = "flake-utils";
    };
  };
}
```

## Pattern 3: Shared Package Overlays

Create overlays that can be used across all configurations.

```nix
{ config, lib, inputs, ... }:
{
  options.customOverlays = lib.mkOption {
    type = lib.types.listOf lib.types.anything;
    default = [];
    description = "Custom package overlays";
  };

  config = {
    customOverlays = [
      # Custom package overlay
      (final: prev: {
        myapp = prev.callPackage ./packages/myapp.nix {};

        # Override existing package
        vim = prev.vim.overrideAttrs (old: {
          configureFlags = old.configureFlags or [] ++ [ "--enable-python3interp" ];
        });
      })

      # Patch overlay
      (final: prev: {
        nginx = prev.nginx.overrideAttrs (old: {
          patches = (old.patches or []) ++ [ ./patches/nginx-custom.patch ];
        });
      })
    ];

    # Apply to nixpkgs
    nixpkgs.overlays = config.customOverlays;
  };
}
```

## Pattern 4: User-Specific home-manager Config

Configure home-manager for specific users with shared and per-user settings.

```nix
{ config, lib, pkgs, ... }:
let
  cfg = config.features.userEnv;
in
{
  options.features.userEnv = {
    enable = lib.mkEnableOption "user environment";

    commonPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = with pkgs; [ vim git htop ];
      description = "Packages for all users";
    };

    users = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          extraPackages = lib.mkOption {
            type = lib.types.listOf lib.types.package;
            default = [];
          };
          shell = lib.mkOption {
            type = lib.types.package;
            default = pkgs.bash;
          };
        };
      });
      default = {};
    };
  };

  config = lib.mkIf cfg.enable {
    home-manager.users = lib.mapAttrs (username: userCfg: {
      home.packages = cfg.commonPackages ++ userCfg.extraPackages;

      programs.${userCfg.shell.pname} = {
        enable = true;
      };
    }) cfg.users;
  };
}
```

## Pattern 5: Generated Files Module

Generate files (README, LICENSE, CI configs) from configuration.

```nix
{ config, lib, pkgs, ... }:
let
  cfg = config.features.generatedFiles;

  generateReadme = pkgs.writeText "README.md" ''
    # ${config.flake.description}

    ## Systems
    ${lib.concatStringsSep "\n" (map (s: "- ${s}") config.systems)}

    ## Configurations
    ${lib.concatStringsSep "\n" (lib.mapAttrsToList (n: v: "- ${n}") config.nixosConfigurations)}
  '';

  generateGitHubWorkflow = pkgs.writeText "ci.yml" ''
    name: CI
    on: [push, pull_request]
    jobs:
      ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: check: ''
        ${name}:
          runs-on: ubuntu-latest
          steps:
            - uses: actions/checkout@v3
            - uses: cachix/install-nix-action@v20
            - run: nix build .#${name}
      '') config.flake.checks.x86_64-linux or {})}
  '';
in
{
  options.features.generatedFiles = {
    enable = lib.mkEnableOption "generated files";
  };

  config = lib.mkIf cfg.enable {
    # Make files available as flake outputs
    flake.generatedFiles = {
      readme = generateReadme;
      ciWorkflow = generateGitHubWorkflow;
    };
  };
}
```

## Pattern 6: Per-System Configuration

Handle system-specific configuration (x86_64-linux, aarch64-darwin, etc).

```nix
{ config, lib, ... }:
{
  perSystem = { config, pkgs, system, ... }: {
    # System-specific packages
    packages = {
      myapp = pkgs.callPackage ./packages/myapp.nix {};

      # System-specific build
      myapp-static = pkgs.pkgsStatic.callPackage ./packages/myapp.nix {};
    };

    # Development shells
    devShells = {
      default = pkgs.mkShell {
        buildInputs = with pkgs; [
          config.packages.myapp
          rust-analyzer
          clippy
        ];

        shellHook = ''
          echo "Development environment for ${system}"
        '';
      };

      minimal = pkgs.mkShell {
        buildInputs = [ pkgs.hello ];
      };
    };

    # System-specific checks
    checks = {
      myapp-test = config.packages.myapp.overrideAttrs (old: {
        doCheck = true;
      });
    };
  };
}
```

## Pattern 7: Assertion and Validation Module

Centralize configuration validation and warnings.

```nix
{ config, lib, ... }:
{
  config = {
    assertions = [
      # Ensure required options are set
      {
        assertion = config.networking.hostName != "";
        message = "networking.hostName must be set";
      }

      # Validate dependencies
      {
        assertion = config.services.nginx.enable -> config.services.postgresql.enable;
        message = "nginx requires postgresql to be enabled";
      }

      # Check for conflicting options
      {
        assertion = !(config.services.myapp.useSSL && config.services.myapp.plaintext);
        message = "myapp cannot use both SSL and plaintext modes";
      }

      # Version constraints
      {
        assertion = lib.versionAtLeast pkgs.linux.version "5.10";
        message = "Linux kernel >= 5.10 required";
      }
    ];

    warnings = lib.optionals config.services.myapp.debug [
      "myapp.debug is enabled - not recommended for production"
    ]
    ++ lib.optionals (config.services.myapp.port < 1024) [
      "myapp.port < 1024 requires root privileges"
    ];
  };
}
```

## Pattern 8: Module with Private Options

Use internal options for module-private state.

```nix
{ config, lib, pkgs, ... }:
let
  cfg = config.features.myFeature;

  # Private options not exposed to users
  internal = config.features.myFeature._internal;
in
{
  options.features.myFeature = {
    enable = lib.mkEnableOption "my feature";

    # Public option
    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
    };

    # Private options (convention: prefix with _)
    _internal = {
      computedValue = lib.mkOption {
        type = lib.types.str;
        internal = true;
        description = "Computed value (internal)";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # Compute internal value
    features.myFeature._internal.computedValue =
      "computed-${toString cfg.port}";

    # Use internal value
    services.myapp.config = internal.computedValue;
  };
}
```

## Pattern 9: Conditional Module Loading

Load modules conditionally based on configuration.

```nix
{ config, lib, ... }:
{
  options.features.platform = lib.mkOption {
    type = lib.types.enum [ "desktop" "server" "minimal" ];
    default = "minimal";
  };

  config = {
    imports = []
      # Desktop-specific modules
      ++ lib.optionals (config.features.platform == "desktop") [
        ./desktop/gui.nix
        ./desktop/audio.nix
        ./desktop/fonts.nix
      ]
      # Server-specific modules
      ++ lib.optionals (config.features.platform == "server") [
        ./server/nginx.nix
        ./server/monitoring.nix
        ./server/backup.nix
      ]
      # Always load
      ++ [
        ./core/base.nix
        ./core/nix.nix
      ];
  };
}
```

## Pattern 10: Secrets Management with Options

Handle secrets without storing them in the Nix store.

```nix
{ config, lib, pkgs, ... }:
let
  cfg = config.features.secrets;
in
{
  options.features.secrets = {
    # Don't use type = lib.types.str for secrets!
    apiKeyFile = lib.mkOption {
      type = lib.types.path;
      description = "Path to API key file";
      example = "/run/secrets/api-key";
    };

    dbPasswordFile = lib.mkOption {
      type = lib.types.path;
      description = "Path to database password file";
    };
  };

  config = {
    # Use systemd credentials or LoadCredential
    systemd.services.myapp = {
      serviceConfig = {
        LoadCredential = [
          "apikey:${cfg.apiKeyFile}"
          "dbpass:${cfg.dbPasswordFile}"
        ];

        # Access via %d/credential-name
        ExecStart = ''
          ${pkgs.myapp}/bin/myapp \
            --api-key-file=%d/apikey \
            --db-password-file=%d/dbpass
        '';
      };
    };

    # Or use environment files
    systemd.services.myapp2 = {
      serviceConfig = {
        EnvironmentFile = cfg.apiKeyFile;
      };
    };
  };
}
```

## Pattern 11: Build-Time Code Generation

Generate code at build time that gets included in the configuration.

```nix
{ config, lib, pkgs, ... }:
let
  cfg = config.features.codegen;

  # Generate configuration file
  generatedConfig = pkgs.writeText "app.conf" ''
    listen ${cfg.host}:${toString cfg.port}
    workers ${toString cfg.workers}
    ${lib.concatStringsSep "\n" (map (u: "upstream ${u}") cfg.upstreams)}
  '';

  # Generate Nix code from JSON
  generatedModule = pkgs.runCommand "generated-module.nix" {
    buildInputs = [ pkgs.jq ];
  } ''
    jq -r 'to_entries | map("  \(.key) = \(.value);") | join("\n")' \
      ${cfg.jsonConfig} > $out
  '';
in
{
  options.features.codegen = {
    enable = lib.mkEnableOption "code generation";
    host = lib.mkOption { type = lib.types.str; default = "localhost"; };
    port = lib.mkOption { type = lib.types.port; default = 8080; };
    workers = lib.mkOption { type = lib.types.int; default = 4; };
    upstreams = lib.mkOption { type = lib.types.listOf lib.types.str; default = []; };
  };

  config = lib.mkIf cfg.enable {
    # Use generated config
    services.myapp.configFile = generatedConfig;

    # Import generated module
    imports = [ generatedModule ];
  };
}
```

## Pattern 12: Testing and CI Integration

Set up flake checks for automated testing.

```nix
{ config, lib, pkgs, inputs, ... }:
{
  perSystem = { config, pkgs, system, ... }: {
    checks = {
      # Formatting check
      format = pkgs.runCommand "check-format" {
        buildInputs = [ pkgs.nixpkgs-fmt ];
      } ''
        nixpkgs-fmt --check ${./.}
        touch $out
      '';

      # Lint check
      lint = pkgs.runCommand "check-lint" {
        buildInputs = [ pkgs.statix ];
      } ''
        statix check ${./.}
        touch $out
      '';

      # Build all packages
      all-packages = pkgs.linkFarm "all-packages"
        (lib.mapAttrsToList (n: v: { name = n; path = v; }) config.packages);

      # Integration test
      myapp-test = pkgs.nixosTest {
        name = "myapp-integration-test";
        nodes.machine = {
          imports = [ config.nixosModules.myapp ];
          services.myapp.enable = true;
        };
        testScript = ''
          machine.wait_for_unit("myapp.service")
          machine.succeed("curl http://localhost:8080")
        '';
      };
    };
  };

  # GitHub Actions generator
  flake.githubActions = {
    jobs = lib.mapAttrs' (name: check: {
      name = "check-${name}";
      value = {
        runs-on = "ubuntu-latest";
        steps = [
          { uses = "actions/checkout@v3"; }
          { uses = "cachix/install-nix-action@v20"; }
          { run = "nix build .#checks.x86_64-linux.${name}"; }
        ];
      };
    }) config.flake.checks.x86_64-linux or {};
  };
}
```
