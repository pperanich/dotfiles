{
  description = "Dendritic Nix configuration (flake-parts + import-tree)";

  # Every .nix file under ./modules is imported automatically as a flake-parts
  # module. There is no central import list to maintain: add a file, it's live.
  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules);

  inputs = {
    # Core
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    flake-parts.url = "github:hercules-ci/flake-parts";
    import-tree.url = "github:vic/import-tree";
    systems.url = "github:nix-systems/default";

    # System management
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    darwin = {
      # Release branch must match the nixpkgs release (nix-darwin asserts this)
      url = "github:nix-darwin/nix-darwin/nix-darwin-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Secrets
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Formatting
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Optional: multi-machine deployment. See optional/clan/README.md.
    # clan-core = {
    #   url = "github:clan-lol/clan-core";
    #   inputs = {
    #     nixpkgs.follows = "nixpkgs";
    #     flake-parts.follows = "flake-parts";
    #     nix-darwin.follows = "darwin";
    #     sops-nix.follows = "sops-nix";
    #     treefmt-nix.follows = "treefmt-nix";
    #     systems.follows = "systems";
    #   };
    # };
  };
}
