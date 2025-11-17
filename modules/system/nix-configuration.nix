# Unified Nix configuration module for all platforms
{ inputs, ... }:
{
  # NixOS Nix configuration
  flake.modules.nixos.base =
    {
      ...
    }:
    {
      imports = [
        inputs.home-manager.nixosModules.home-manager
        inputs.nix-index-database.nixosModules.nix-index
        inputs.determinate.nixosModules.default
        inputs.nix-ld.nixosModules.nix-ld
      ];

      system.stateVersion = "25.11";

      home-manager.backupFileExtension = "hm-back";

      # nix = {
      #   settings = {
      #     # Trust configuration
      #     trusted-users = [
      #       "root"
      #       "@wheel"
      #     ];
      #     experimental-features = [
      #       "nix-command"
      #       "flakes"
      #     ];
      #     warn-dirty = false;
      #     system-features = [
      #       "kvm"
      #       "big-parallel"
      #       "nixos-test"
      #     ];
      #
      #     # Disable global flake registry
      #     flake-registry = "";
      #
      #     # Substituters - include common ones that might be used across machines
      #     substituters = [
      #       "https://cache.nixos.org/"
      #       "https://nix-community.cachix.org"
      #       "https://t2linux.cachix.org" # T2Linux support for MacBooks
      #     ];
      #     trusted-public-keys = [
      #       "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      #       "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      #       "t2linux.cachix.org-1:P733c5Gt1qTcxsm+Bae0renWnT8OLs0u9+yfaK2Bejw=" # T2Linux support
      #     ];
      #   };
      #
      #   # Garbage collection
      #   gc = {
      #     automatic = true;
      #     dates = "weekly";
      #     options = "--delete-older-than 7d";
      #   };
      #
      #   # Store optimization
      #   optimise = {
      #     automatic = true;
      #     dates = [ "03:45" ];
      #   };
      #
      #   # Registry will be configured by the flake itself
      #   # No need to configure inputs here since they're not available
      # };

      # System auto-upgrade (NixOS specific) - disabled by default
      # system.autoUpgrade.enable = false;

      nixpkgs = {
        config = {
          allowUnfree = true;
          allowUnfreePredicate = _: true;
          allowBroken = true;
        };
        overlays = builtins.attrValues (import ../../overlays { inherit inputs; });
      };
      programs.nix-ld.dev.enable = true;
    };

  # Darwin Nix configuration
  flake.modules.darwin.base =
    {
      pkgs,
      ...
    }:
    {
      imports = [
        inputs.home-manager.darwinModules.home-manager
        inputs.mac-app-util.darwinModules.default
        inputs.nix-index-database.darwinModules.nix-index
        inputs.determinate.darwinModules.default
      ];
      system.stateVersion = 6;

      # We are using the Determinate daemon
      nix.enable = false;
      # Custom settings written to /etc/nix/nix.custom.conf
      determinate-nix.customSettings = {
        eval-cores = 0;
        extra-experimental-features = "external-builders parallel-eval";
        external-builders = "[{\"systems\":[\"aarch64-linux\",\"x86_64-linux\"],\"program\":\"/usr/local/bin/determinate-nixd\",\"args\":[\"builder\"]}]";
      };

      programs.zsh.enableCompletion = false;
      programs.zsh.enableBashCompletion = false;

      system.defaults = {
        dock = {
          autohide = true;
          showhidden = true;
          mru-spaces = false;
          launchanim = false;
        };
        finder = {
          AppleShowAllExtensions = true;
          QuitMenuItem = true;
        };
        NSGlobalDomain = {
          AppleKeyboardUIMode = 3;
          ApplePressAndHoldEnabled = false;
          AppleFontSmoothing = 1;
          _HIHideMenuBar = true;
          InitialKeyRepeat = 10;
          KeyRepeat = 1;
          "com.apple.mouse.tapBehavior" = 1;
          "com.apple.swipescrolldirection" = false;
        };
        trackpad = {
          Clicking = true;
          TrackpadThreeFingerDrag = false;
        };
      };

      security.pam.services.sudo_local = {
        enable = true;
        touchIdAuth = true;
        reattach = true;
      };
      homebrew.enable = true;
      homebrew.casks = [
        "skim" # PDF viewer with LaTeX support
        "texshop" # LaTeX editor
        "xcode-build-server"
        "xcbeautify"
        "wojciech-kulik/tap/xcp"
      ];

      environment.systemPackages = with pkgs; [
        python313Packages.pymobiledevice3
        swiftformat
      ];

      nixpkgs = {
        config = {
          allowUnfree = true;
          allowUnfreePredicate = _: true;
          allowBroken = true;
        };
        overlays = builtins.attrValues (import ../../overlays { inherit inputs; });
      };
    };

  # Home Manager Nix configuration
  flake.modules.homeManager.base =
    {
      lib,
      pkgs,
      config,
      ...
    }:
    let
      homePrefix = if pkgs.stdenv.hostPlatform.isDarwin then "Users" else "home";
    in
    {
      imports = [
        inputs.nix-index-database.homeModules.nix-index
      ];
      # User-level Nix configuration via Home Manager
      # Note: This configures the user's environment, not the system daemon

      xdg.enable = true;

      # Default programs
      programs = {
        home-manager.enable = true;
        pandoc.enable = true;
        gpg.enable = true;
        dircolors.enable = true;
        direnv.enable = true;
        atuin.enable = true;
        zoxide.enable = true;
        nix-index-database.comma.enable = true;
      };

      # Configure user nixpkgs
      nixpkgs = {
        config = {
          allowUnfree = true;
          allowUnfreePredicate = _: true;
          allowBroken = true;
        };
        overlays = builtins.attrValues (import ../../overlays { inherit inputs; });
      };

      # User session variables for Nix
      home.sessionVariables = {
        # Point to the user's flake for convenience
        FLAKE = "${config.home.homeDirectory}/dotfiles/";
      };
      home.enableNixpkgsReleaseCheck = false;
      home.stateVersion = "25.05";
      home.homeDirectory = "/${homePrefix}/${config.home.username}";

      home.activation = {
        stowHome = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          pushd ${config.home.homeDirectory}/dotfiles/ >/dev/null
          ${pkgs.stow}/bin/stow home
          popd >/dev/null
        '';
      };

      # User-level packages that enhance Nix experience
      home.packages = with pkgs; [
        # Nix development tools
        nil # Nix LSP
        nixfmt-rfc-style # Nix formatter
        nix-tree # Explore Nix store dependencies
        nix-diff # Compare Nix derivations

        # Development environment tools
        devenv # Developer environments with Nix
      ];
    };
}
