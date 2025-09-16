# Unified Nix configuration module for all platforms
_: {
  # NixOS Nix configuration
  flake.modules.nixos.nixConfiguration = {
    lib,
    pkgs,
    config,
    ...
  }: {
    nix = {
      settings = {
        # Trust configuration
        trusted-users = ["root" "@wheel"];
        experimental-features = ["nix-command" "flakes"];
        warn-dirty = false;
        system-features = ["kvm" "big-parallel" "nixos-test"];

        # Disable global flake registry
        flake-registry = "";

        # Substituters - include common ones that might be used across machines
        substituters = [
          "https://cache.nixos.org/"
          "https://nix-community.cachix.org"
          "https://t2linux.cachix.org" # T2Linux support for MacBooks
        ];
        trusted-public-keys = [
          "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
          "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
          "t2linux.cachix.org-1:P733c5Gt1qTcxsm+Bae0renWnT8OLs0u9+yfaK2Bejw=" # T2Linux support
        ];
      };

      # Garbage collection
      gc = {
        automatic = true;
        dates = "weekly";
        options = "--delete-older-than 7d";
      };

      # Store optimization
      optimise = {
        automatic = true;
        dates = ["03:45"];
      };

      # Registry will be configured by the flake itself
      # No need to configure inputs here since they're not available
    };

    # System auto-upgrade (NixOS specific) - disabled by default
    system.autoUpgrade.enable = false;

    nixpkgs.config = {
      allowUnfree = true;
      allowUnfreePredicate = _: true;
    };
  };

  # Darwin Nix configuration
  flake.modules.darwin.nixConfiguration = {
    lib,
    pkgs,
    config,
    ...
  }: {
    # Darwin Nix configuration
    nix = {
      settings = {
        # Trust configuration
        trusted-users = ["root" "@admin"];
        experimental-features = ["nix-command" "flakes"];
        warn-dirty = false;

        # Disable global flake registry
        flake-registry = "";

        # Substituters
        substituters = [
          "https://cache.nixos.org/"
          "https://nix-community.cachix.org"
          "https://t2linux.cachix.org" # T2Linux support for MacBooks
        ];
        trusted-public-keys = [
          "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
          "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
          "t2linux.cachix.org-1:P733c5Gt1qTcxsm+Bae0renWnT8OLs0u9+yfaK2Bejw=" # T2Linux support
        ];
      };

      # Garbage collection (more conservative on Darwin)
      gc = {
        automatic = true;
        interval = {
          Weekday = 0;
          Hour = 3;
          Minute = 15;
        };
        options = "--delete-older-than 14d";
      };

      # Store optimization
      optimise.automatic = true;

      # Registry will be configured by the flake itself
    };

    nixpkgs.config = {
      allowUnfree = true;
      allowUnfreePredicate = _: true;
    };
  };

  # Home Manager Nix configuration
  flake.modules.homeModules.nixConfiguration = {
    lib,
    pkgs,
    config,
    ...
  }: {
    # User-level Nix configuration via Home Manager
    # Note: This configures the user's environment, not the system daemon

    # Enable direnv for per-project Nix environments
    programs.direnv = {
      enable = true;
      nix-direnv.enable = true;
    };

    # Configure user nixpkgs
    nixpkgs.config = {
      allowUnfree = true;
      allowUnfreePredicate = _: true;
    };

    # User session variables for Nix
    home.sessionVariables = {
      # Point to the user's flake for convenience
      FLAKE = "${config.home.homeDirectory}/dotfiles/";
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
