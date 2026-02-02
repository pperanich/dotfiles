{
  description = "My nix configs";

  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules);

  inputs = {
    # Core
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    hardware = {
      url = "github:nixos/nixos-hardware";
    };
    determinate = {
      url = "github:DeterminateSystems/determinate";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-compat = {
      url = "github:edolstra/flake-compat";
    };
    nixos-facter-modules = {
      url = "github:nix-community/nixos-facter-modules";
    };

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
    };

    clan-core = {
      url = "github:clan-lol/clan-core";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-parts.follows = "flake-parts";
        nix-darwin.follows = "darwin";
        disko.follows = "disko";
        sops-nix.follows = "sops-nix";
        treefmt-nix.follows = "treefmt-nix";
        systems.follows = "systems";
      };
    };

    import-tree = {
      url = "github:vic/import-tree";
    };
    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-compat.follows = "flake-compat";
      };
    };

    # System Management
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-wsl = {
      url = "github:nix-community/nixos-wsl";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-compat.follows = "flake-compat";
      };
    };
    jetpack-nixos = {
      url = "github:anduril/jetpack-nixos";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Disk Management
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Security & Utils
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    systems = {
      url = "github:nix-systems/default";
    };
    nix-ld = {
      url = "github:Mic92/nix-ld";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Development Tools
    neovim-nightly-overlay = {
      url = "github:nix-community/neovim-nightly-overlay";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-parts.follows = "flake-parts";
      };
    };
    emacs-overlay = {
      url = "github:nix-community/emacs-overlay";
      inputs = {
        nixpkgs.follows = "nixpkgs";
      };
    };
    nixgl = {
      url = "github:guibou/nixGL";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    ghostty = {
      url = "github:ghostty-org/ghostty";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        home-manager.follows = "home-manager";
        flake-compat.follows = "flake-compat";
      };
    };

    # Additional Software
    nixcasks = {
      url = "github:jacekszymanski/nixcasks";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Development Tools
    nil = {
      url = "github:oxalica/nil"; # Nix LSP
      inputs.nixpkgs.follows = "nixpkgs";
    };
    treefmt-nix = {
      url = "github:numtide/treefmt-nix"; # Formatting tools
      inputs.nixpkgs.follows = "nixpkgs";
    };

    apple-fonts = {
      url = "github:Lyndeno/apple-fonts.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # OpenClaw - AI assistant gateway
    nix-openclaw = {
      url = "path:/Users/pperanich/Documents/repos/oss/nix-openclaw";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        home-manager.follows = "home-manager";
      };
    };

    # OpenCode - AI coding agent
    opencode = {
      url = "path:/Users/pperanich/Documents/repos/oss/opencode";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
}
