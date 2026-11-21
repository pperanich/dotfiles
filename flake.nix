{
  description = "My nix configs";

  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules);

  inputs = {
    # Core
    # One rolling channel for every host (docs/decisions/0005): nixpkgs-unstable advances only
    # once Hydra has built it for Linux and darwin, so updates come from the binary cache.
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    # MongoDB for UniFi only: unfree, so never in the binary cache, and a bump compiles it for
    # hours on the router. Pinned to the build already there; see docs/todo.md.
    nixpkgs-mongodb.url = "github:nixos/nixpkgs/8ce73368d1efd4d657e9064d29b144a52046b4e8";
    hardware = {
      url = "github:nixos/nixos-hardware";
    };
    # Built-in schemas for `nix flake check`, extended in modules/flake-parts/schemas.nix.
    flake-schemas.url = "github:DeterminateSystems/flake-schemas";
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
      # master tracks nixpkgs-unstable (nix-darwin asserts the releases match)
      url = "github:nix-darwin/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-wsl = {
      url = "github:nix-community/nixos-wsl";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-compat.follows = "flake-compat";
      };
    };

    # Disk Management
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Security & Deployment
    deploy-rs = {
      url = "github:serokell/deploy-rs";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-compat.follows = "flake-compat";
      };
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    systems = {
      url = "github:nix-systems/triplet";
    };

    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    treefmt-nix = {
      url = "github:numtide/treefmt-nix"; # Formatting tools
      inputs.nixpkgs.follows = "nixpkgs";
    };

    personal-site = {
      url = "github:pperanich/personal-site";
      # Built on the site's own nixpkgs (decision 0005), so it rebuilds only when the site's lock moves.
      # bun2nix lists x86_64-darwin, which a site lock past nixpkgs' drop of it would fail to evaluate.
      inputs.bun2nix.inputs.systems.follows = "systems";
    };

    # Upstream CLI/terminfo; Lua configuration remains Stow-managed under home/.
    rex = {
      url = "https://pkgs.superlogical.com/rex/nix/snapshot.tar.gz";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-apple-fonts.url = "github:pperanich/nix-apple-fonts";
    llm-agents.url = "github:numtide/llm-agents.nix";
    feed-me.url = "git+ssh://git@gitea.prestonperanich.com/pperanich/feed-me.git?ref=main";

  };
}
