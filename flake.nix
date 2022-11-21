{
  description = "My custom nix configs";

  inputs = {
    # Nixpkgs
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    # Home manager
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    hardware.url = "github:nixos/nixos-hardware";
  };

  outputs = { nixpkgs, home-manager, ... }@inputs:
    let
      forAllSystems = nixpkgs.lib.genAttrs [
        "aarch64-linux"
        "i686-linux"
        "x86_64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];
    in
    rec {
      # Your custom packages
      # Acessible through 'nix build', 'nix shell', etc
      packages = forAllSystems (system:
        let pkgs = nixpkgs.legacyPackages.${system};
        in
        import ./pkgs { inherit pkgs; }
      );
      # Devshell for bootstrapping
      # Acessible through 'nix develop' or 'nix-shell' (legacy)
      devShells = forAllSystems (system:
        let pkgs = nixpkgs.legacyPackages.${system};
        in
        import ./shell.nix { inherit pkgs; }
      );

      # Your custom packages and modifications, exported as overlays
      overlays = import ./overlays;
      # Reusable nixos modules you might want to export
      # These are usually stuff you would upstream into nixpkgs
      nixosModules = import ./modules/nixos;
      # Reusable home-manager modules you might want to export
      # These are usually stuff you would upstream into home-manager
      homeManagerModules = import ./modules/home-manager;

      nixosConfigurations = {
        pperanich-ld1 = nixpkgs.lib.nixosSystem {
          specialArgs = { inherit inputs; };
          modules = (builtins.attrValues nixosModules) ++ [
            ./nixos/configuration.nix
            (import ./nixpkgs-config.nix { inherit overlays; })
          ];
        };
      };

      homeConfigurations = {
        "pperanich@pperanich-ld1" = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
          extraSpecialArgs = { inherit inputs; };
          modules = (builtins.attrValues homeManagerModules) ++ [
            ./home/pperanich-ld1.nix
            (import ./nixpkgs-config.nix { inherit overlays; })
          ];
        };
        "peranpl1@peranpl1-ml1" = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.x86_64-darwin;
          extraSpecialArgs = { inherit inputs; };
          modules = (builtins.attrValues homeManagerModules) ++ [
            ./home-manager/peranpl1-ml1.nix
            (import ./nixpkgs-config.nix { inherit overlays; })
          ];
        };
        "omni@omnimed-ld1" = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
          extraSpecialArgs = { inherit inputs; };
          modules = (builtins.attrValues homeManagerModules) ++ [
            ./home/omnimed-ld1.nix
            (import ./nixpkgs-config.nix { inherit overlays; })
          ];
        };
        "omni@omnimed-ld2" = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
          extraSpecialArgs = { inherit inputs; };
          modules = (builtins.attrValues homeManagerModules) ++ [
            ./home/omnimed-ld2.nix
            (import ./nixpkgs-config.nix { inherit overlays; })
          ];
        };
        "omni@omnimed-ld3" = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
          extraSpecialArgs = { inherit inputs; };
          modules = (builtins.attrValues homeManagerModules) ++ [
            ./home/omnimed-ld3.nix
            (import ./nixpkgs-config.nix { inherit overlays; })
          ];
        };
        "peranpl1@redd-holobrain" = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
          extraSpecialArgs = { inherit inputs; };
          modules = (builtins.attrValues homeManagerModules) ++ [
            ./home/redd-holobrain.nix
            (import ./nixpkgs-config.nix { inherit overlays; })
          ];
        };
        "holo@holobrain-ld1" = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
          extraSpecialArgs = { inherit inputs; };
          modules = (builtins.attrValues homeManagerModules) ++ [
            ./home/holobrain-ld1.nix
            (import ./nixpkgs-config.nix { inherit overlays; })
          ];
        };
      };
    };
}
