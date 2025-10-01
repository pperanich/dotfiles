This guide provides step-by-step instructions for converting your existing modules from the traditional NixOS module system to the dendritic flake-parts pattern.

Table of Contents

1. #understanding-the-transformation
2. #pre-conversion-checklist
3. #step-by-step-conversion-process
4. #common-patterns--examples
5. #troubleshooting-guide

Understanding the Transformation

Core Architectural Changes

| Aspect             | Old System                                                | New System                                                |
| ------------------ | --------------------------------------------------------- | --------------------------------------------------------- |
| File Purpose       | Direct NixOS/Darwin/Home-Manager module                   | Flake-parts module that exports multiple platform modules |
| Function Signature | {pkgs, config, lib, ...}:                                 | {\_}: or {inputs, ...}:                                   |
| Module Output      | Direct configuration (environment.systemPackages = [...]) | Flake outputs (flake.modules.nixos.name = {...})          |
| Platform Support   | One platform per file                                     | Multiple platforms per file                               |
| Import Method      | Manual imports via default.nix aggregators                | Automatic discovery via import-tree                       |
| Enable Options     | Required (lib.mkEnableOption, lib.mkIf)                   | Optional (import = enable)                                |

Pre-Conversion Checklist

1. Backup Current Working State

git add -A && git commit -m "backup: before module conversion"
git tag backup-pre-conversion

2. Identify Module Categories

Categorize your existing modules:

System-Only Modules:

- Services (SSH, networking, virtualization)
  - System packages
  - Hardware configuration

  User-Only Modules:
  - Dotfile configuration
  - User applications
  - Shell customization

  Cross-Platform Modules:
  - Development tools
  - Productivity applications
  - Mixed system/user functionality

  Platform-Specific Modules:
  - Darwin window management (yabai, sketchybar)
  - Linux desktop environments
  - Platform-specific packages
  3. Dependency Analysis

  Map module dependencies:

  # Find import relationships

  grep -r "import.\*\.nix" modules/ | grep -v default.nix

  Step-by-Step Conversion Process

  Step 1: Function Signature Transformation

  Old Pattern:
  {
  config,
  lib,
  pkgs,
  inputs, # if needed
  outputs, # if needed
  ...
  }: let
  cfg = config.my.features.someFeature;
  in {

  # module content

  }

  New Pattern:
  {\_}: # For simple modules

  # OR

  {inputs, ...}: # If you need flake inputs
  {

  # flake-parts outputs

  }

  Step 2: Options Declaration Conversion

  Old Pattern (Enable-Heavy):
  {
  options.my.features.someFeature = {
  enable = lib.mkEnableOption "Some feature";

      setting1 = lib.mkOption {
        type = lib.types.str;
        default = "default-value";
      };

  };

  config = lib.mkIf cfg.enable {

  # actual configuration

  };
  }

  New Pattern (Import-Based):
  {\_}: {

  # Option 1: No options (import = enable)

  flake.modules.nixos.someFeature = { pkgs, ... }: {

  # Direct configuration

  };

  # Option 2: Keep essential options only

  flake.modules.nixos.someFeature = { config, lib, pkgs, ... }:
  let
  cfg = config.features.someFeature; # Flatter namespace
  in {
  options.features.someFeature.setting1 = lib.mkOption {
  type = lib.types.str;
  default = "default-value";
  };

      config = {
        # Direct configuration using cfg.setting1
      };

  };
  }

  Step 3: Platform-Specific Output Creation

  For System-Only Modules:
  {\_}: {
  flake.modules.nixos.moduleName = { config, pkgs, ... }: {

  # NixOS system configuration

  };

  # Add Darwin support if applicable

  flake.modules.darwin.moduleName = { config, pkgs, ... }: {

  # Darwin system configuration

  };
  }

  For User-Only Modules:
  {\_}: {
  flake.modules.home.moduleName = { config, pkgs, ... }: {

  # Home Manager configuration

  };
  }

  For Cross-Platform Modules:
  {\_}: {
  flake.modules.nixos.moduleName = { pkgs, ... }: {

  # System-level packages and services

      environment.systemPackages = [ pkgs.someSystemTool ];

  };

  flake.modules.home.moduleName = { pkgs, ... }: {

  # User-level packages and configuration

      home.packages = [ pkgs.someUserTool ];
      programs.someProgram.enable = true;

  };

  flake.modules.darwin.moduleName = { pkgs, ... }: {

  # macOS-specific system configuration

      environment.systemPackages = [ pkgs.darwinSpecificTool ];

  };
  }

  Step 4: Platform-Specific Package Handling

  Old Pattern (Separate Files):

  # modules/nixos/features/someFeature.nix

  {pkgs, ...}: {
  environment.systemPackages = [ pkgs.linuxTool ];
  }

  # modules/darwin/features/someFeature.nix

  {pkgs, ...}: {
  environment.systemPackages = [ pkgs.darwinTool ];
  }

  New Pattern (Conditional Logic):
  {\_}: {
  flake.modules.home.someFeature = { pkgs, ... }: {
  home.packages = with pkgs; [

  # Cross-platform packages

        universalTool
        anotherTool
      ] ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
        # Linux-specific packages
        linuxOnlyTool
      ] ++ lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
        # macOS-specific packages
        darwinOnlyTool
      ];

  };
  }

  Step 5: File Organization and Naming

  Old Structure:
  modules/
  ├── nixos/features/someFeature.nix
  ├── darwin/features/someFeature.nix
  └── home-manager/features/someFeature.nix

  New Structure:
  modules/
  └── some-feature.nix # Single file, multiple platform outputs

  Naming Convention:
  - Use kebab-case: rust-development.nix, container-tools.nix
  - Be descriptive: macos-window-management.nix not wm.nix
  - Group related functionality: git-workflow.nix not separate gh.nix, glab.nix

  Common Patterns & Examples

  Pattern 1: Simple Package Collection

  Before:

  # modules/home-manager/features/shell/tools.nix

  {config, lib, pkgs, ...}: let
  cfg = config.my.home.features.shell;
  in {
  config = lib.mkIf cfg.tools.enable {
  home.packages = [ pkgs.bat pkgs.fd pkgs.ripgrep ];
  };
  }

  After:

  # modules/file-tools.nix

  {\_}: {
  flake.modules.home.fileTools = { pkgs, ... }: {
  home.packages = [ pkgs.bat pkgs.fd pkgs.ripgrep ];
  };
  }

  Pattern 2: Cross-Platform Development Environment

  Before (Multiple Files):

  # modules/nixos/features/rust.nix

  {pkgs, ...}: {
  environment.systemPackages = [ pkgs.lldb ];
  }

  # modules/home-manager/features/development/languages/rust.nix

  {config, lib, pkgs, ...}: {
  home.packages = [ pkgs.rustc pkgs.cargo ];
  }

  # modules/darwin/features/rust.nix

  {pkgs, ...}: {
  environment.systemPackages = [ pkgs.libiconv ];
  }

  After (Single File):

  # modules/rust-development.nix

  {\_}: {
  flake.modules.nixos.rust = { pkgs, ... }: {
  environment.systemPackages = [ pkgs.lldb pkgs.gdb ];

  # Enable cross-compilation

      boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  };

  flake.modules.home.rust = { pkgs, ... }: {
  home.packages = with pkgs; [
  (rust-bin.nightly.latest.default.override {
  extensions = ["rust-src" "rustfmt" "rust-analyzer"];
  targets = ["aarch64-apple-darwin" "x86_64-unknown-linux-gnu"];
  })
  cargo-edit
  cargo-watch
  ];

      home.sessionVariables.RUST_SRC_PATH =
        "${pkgs.rust.packages.stable.rustPlatform.rustLibSrc}";

  };

  flake.modules.darwin.rust = { pkgs, ... }: {
  environment.systemPackages = [ pkgs.libiconv ];
  environment.variables = {
  PKG_CONFIG_PATH = "${pkgs.openssl.dev}/lib/pkgconfig";
    LIBRARY_PATH = "${pkgs.libiconv}/lib";
  };
  };
  }

  Pattern 3: Service with Configuration

  Before:

  # modules/nixos/features/virtualization/podman.nix

  {config, lib, pkgs, ...}: let
  cfg = config.my.features.virtualization.podman;
  in {
  options.my.features.virtualization.podman = {
  enable = lib.mkEnableOption "Podman container runtime";
  dockerCompat = lib.mkEnableOption "Docker-compatible socket";
  };

  config = lib.mkIf cfg.enable {
  virtualisation.podman = {
  enable = true;
  dockerCompat = cfg.dockerCompat;
  };
  };
  }

  After:

  # modules/container-development.nix

  {\_}: {
  flake.modules.nixos.containers = { config, lib, pkgs, ... }: let
  cfg = config.features.containers;
  in {
  options.features.containers = {
  runtime = lib.mkOption {
  type = lib.types.enum ["podman" "docker"];
  default = "podman";
  };
  dockerCompat = lib.mkOption {
  type = lib.types.bool;
  default = true;
  };
  };

      config = {
        virtualisation.${cfg.runtime} = {
          enable = true;
          dockerCompat = cfg.dockerCompat;
        };
        environment.systemPackages = [ pkgs.${cfg.runtime}-compose ];
      };

  };

  flake.modules.home.containers = { pkgs, ... }: {
  home.packages = [ pkgs.kubectl pkgs.lazydocker ];
  programs.vscode.extensions = [
  vscode-extensions.ms-vscode-remote.remote-containers
  ];
  };

  flake.modules.darwin.containers = { pkgs, ... }: {
  homebrew.casks = [ "podman-desktop" ];
  };
  }

  Pattern 4: Platform-Specific Feature

  Before:

  # modules/darwin/features/yabai.nix

  {config, lib, pkgs, ...}: let
  cfg = config.my.features.yabai;
  in {
  options.my.features.yabai.enable = lib.mkEnableOption "Yabai window manager";

  config = lib.mkIf cfg.enable {
  services.yabai.enable = true;
  };
  }

  After:

  # modules/macos-window-management.nix

  {\_}: {
  flake.modules.darwin.windowManagement = { pkgs, ... }: {
  services = {
  yabai.enable = true;
  sketchybar.enable = true;
  skhd.enable = true;
  };

      system.defaults.NSGlobalDomain._HIHideMenuBar = true;

      # Debugging configuration
      launchd.user.agents.yabai.serviceConfig = {
        StandardErrorPath = "/tmp/yabai.err.log";
        StandardOutPath = "/tmp/yabai.out.log";
      };

  };

  flake.modules.home.windowManagement = { ... }: {
  xdg.configFile = {
  "yabai/yabairc".source = ./config/yabai;
  "skhd/skhdrc".source = ./config/skhd;
  "sketchybar/sketchybarrc".source = ./config/sketchybar;
  };
  };
  }

  Troubleshooting Guide

  Common Error: "attribute 'flake' missing"

  Cause: Not using flake-parts properly in flake.nix

  Solution:

  # flake.nix must use flake-parts

  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } {
  imports = [ (inputs.import-tree ./modules) ];

  # ... rest of config

  };

  Common Error: "infinite recursion encountered"

  Cause: Circular imports or incorrect module structure

  Solution:
  - Remove circular dependencies between modules
  - Check that module files don't import each other directly
  - Verify flake-parts module syntax is correct

  Common Error: "value is a function while a set was expected"

  Cause: Incorrect function signature or missing parameter handling

  Solution:

  # Wrong

  {\_}: {
  flake.modules.nixos.name = { pkgs, ... }: {

  # This creates a function, not a set

  };
  }

  # Correct

  {\_}: {
  flake.modules.nixos.name = { pkgs, ... }: {

  # Configuration set

      environment.systemPackages = [];

  };
  }

  Common Error: "Package not found"

  Cause: Package moved from system to user scope or vice versa

  Solution:
  - Check if packages are available in the target scope (nixos vs home-manager)
  - Use nix search nixpkgs packageName to verify package exists
  - Check platform-specific availability with lib.optionals

  Common Error: "Option does not exist"

  Cause: Options namespace changed during conversion

  Solution:
  - Update option paths: config.my.features.X.enable → config.features.X.enable
  - Remove options that are no longer needed (enable flags)
  - Check NixOS/home-manager documentation for correct option names

  Migration Checklist

  Per-Module Conversion Checklist
  - Function signature updated ({\_}: or {inputs, ...}:)
  - Platform modules defined (flake.modules.nixos.name, etc.)
  - Enable options removed or simplified
  - Platform-specific logic consolidated
  - Package lists deduplicated
  - Configuration tested individually
  - Dependencies verified

  Post-Conversion Validation
  - All hosts build successfully
  - No functionality regressions
  - Performance comparable or improved
  - Module imports simplified in host configs
  - Documentation updated
  - CI/CD pipelines passing

  Best Practices
  1. Module Naming and Organization
  - Use descriptive, hyphenated names: rust-development.nix
  - Group related functionality: git-workflow.nix not separate gh.nix, glab.nix
  - Avoid generic names: development-tools.nix not dev.nix
  2. Platform Support Strategy
  - Start with cross-platform modules
  - Add platform-specific modules only when necessary
  - Use conditional logic for minor platform differences
  - Create separate platform modules for major differences
  3. Option Design Philosophy
  - Eliminate enable options where possible (import = enable)
  - Keep options for legitimate configuration choices
  - Use flatter namespaces: config.features.X not config.my.home.features.X
  - Provide sensible defaults
  4. Gradual Migration Strategy

  1. Convert utility/tool modules first (low risk)
  1. Convert development environment modules
  1. Convert desktop/GUI modules
  1. Convert system service modules last (highest risk)
  1. Create profile modules to bundle converted modules
