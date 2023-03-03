{
  description = "My custom nix configs";

  inputs = {
    # Nixpkgs
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    # Home manager
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # Darwin
    darwin.url = "github:LnL7/nix-darwin";
    darwin.inputs.nixpkgs.follows = "nixpkgs";

    hardware.url = "github:nixos/nixos-hardware";

    #neovim-nightly-overlay.url = "github:nix-community/neovim-nightly-overlay";
    neovim-nightly-overlay = {
      url = "github:nix-community/neovim-nightly-overlay";
      # Pin to a nixpkgs revision that doesn't have NixOS/nixpkgs#208103 yet
      inputs.nixpkgs.url = "github:nixos/nixpkgs?rev=fad51abd42ca17a60fc1d4cb9382e2d79ae31836";
    };
    emacs-overlay.url = "github:nix-community/emacs-overlay";
    nixgl.url = "github:guibou/nixGL";
  };

  outputs = { self, nixpkgs, home-manager, darwin, ... }@inputs:
    let
      inherit (self) outputs;
      forAllSystems = nixpkgs.lib.genAttrs [
        "aarch64-linux"
        "i686-linux"
        "x86_64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];
    in
    rec {
      nixosModules = import ./modules/nixos;
      homeManagerModules = import ./modules/home-manager;

      overlays = import ./overlays { inherit inputs; };

      legacyPackages = forAllSystems (system:
        import nixpkgs {
          inherit system;
          config.allowUnfree = true;
          config.allowBroken = true;
          config.allowUnfreePredicate = (_: true);
          config.overlays = builtins.attrValues outputs.overlays;
        }
      );

      packages = forAllSystems (system:
          let pkgs = legacyPackages.${system};
          in import ./pkgs {inherit pkgs; }
          );

      devShells = forAllSystems (system:
        let pkgs = legacyPackages.${system};
        in import ./shell.nix { inherit pkgs; }
      );

      nixosConfigurations = {
        pperanich-ld1 = nixpkgs.lib.nixosSystem {
          specialArgs = { inherit inputs outputs; };
          modules = [
            ./nixos/configuration.nix
          ];
        };
      };

      darwinConfigurations = {
        "peranpl1-ml1" = darwin.lib.darwinSystem {
          system = "x86_64-darwin";
          specialArgs = { inherit inputs outputs; };
          modules = [ ./darwin/configuration.nix ];
        };
      };

      homeConfigurations = {
        "pperanich@pperanich-ld1" = home-manager.lib.homeManagerConfiguration {
          pkgs = legacyPackages.x86_64-linux;
          extraSpecialArgs = { inherit inputs outputs; };
          modules = [
            ./home-manager
            {
              home.username = "pperanich";
              imports = [
                ./home-manager/features/emacs.nix
                ./home-manager/features/desktop.nix
                ./home-manager/features/tex.nix
                ./home-manager/features/zotero.nix
                ./home-manager/features/darwin.nix
                ./home-manager/features/fonts.nix
              ];
            }
          ];
        };
        "peranpl1@peranpl1-ml1" = home-manager.lib.homeManagerConfiguration {
          pkgs = legacyPackages.x86_64-darwin;
          extraSpecialArgs = { inherit inputs outputs; };
          modules = [
            ./home-manager
            {
              home.username = "peranpl1";
              imports = [
                ./home-manager/features/emacs.nix
                ./home-manager/features/desktop.nix
                ./home-manager/features/tex.nix
                ./home-manager/features/zotero.nix
                ./home-manager/features/darwin.nix
                ./home-manager/features/fonts.nix
                ./home-manager/features/aplnis.nix
              ];
            }
          ];
        };
        "peranpl1@redd-holobrain" = home-manager.lib.homeManagerConfiguration {
          pkgs = legacyPackages.x86_64-linux;
          extraSpecialArgs = { inherit inputs outputs; };
          modules = [
            ./home-manager
            {
              home.username = "peranpl1";
              imports = [
                ./home-manager/features/aplnis.nix
                ./home-manager/features/emacs.nix
                ./home-manager/features/desktop.nix
              ];
            }
          ];
        };
        "holobrain@redd-holobrain-jr" = home-manager.lib.homeManagerConfiguration {
          pkgs = legacyPackages.x86_64-linux;
          extraSpecialArgs = { inherit inputs outputs; };
          modules = [
            ./home-manager
            {
              home.username = "holobrain";
              imports = [
                ./home-manager/features/emacs.nix
                ./home-manager/features/desktop.nix
              ];
            }
          ];
        };
        "holo@holobrain-ld1" = home-manager.lib.homeManagerConfiguration {
          pkgs = legacyPackages.x86_64-linux;
          extraSpecialArgs = { inherit inputs outputs; };
          modules = [
            ./home-manager
            {
              home.username = "holo";
              imports = [
                ./home-manager/features/emacs.nix
                ./home-manager/features/desktop.nix
              ];
            }
          ];
        };
        "omni@om-apl-st1-ws1" = home-manager.lib.homeManagerConfiguration {
          pkgs = legacyPackages.x86_64-linux;
          extraSpecialArgs = { inherit inputs outputs; };
          modules = [
            ./home-manager
            {
              home.username = "omni";
              imports = [
                ./home-manager/features/emacs.nix
                ./home-manager/features/desktop.nix
              ];
            }
          ];
        };
        "omni@om-apl-st1-ws2" = home-manager.lib.homeManagerConfiguration {
          pkgs = legacyPackages.x86_64-linux;
          extraSpecialArgs = { inherit inputs outputs; };
          modules = [
            ./home-manager
            {
              home.username = "omni";
              imports = [
                ./home-manager/features/emacs.nix
                ./home-manager/features/desktop.nix
              ];
            }
          ];
        };
        "omni@om-apl-st1-ws3" = home-manager.lib.homeManagerConfiguration {
          pkgs = legacyPackages.x86_64-linux;
          extraSpecialArgs = { inherit inputs outputs; };
          modules = [
            ./home-manager
            {
              home.username = "omni";
              imports = [
                ./home-manager/features/emacs.nix
                ./home-manager/features/desktop.nix
              ];
            }
          ];
        };
        "pi@om-apl-st2-raspi1" = home-manager.lib.homeManagerConfiguration {
          pkgs = legacyPackages."aarch64-linux";
          extraSpecialArgs = { inherit inputs outputs; };
          modules = [
            ./home-manager
            {
              home.username = "pi";
            }
          ];
        };
        "nvidia@om-apl-st2-agx1" = home-manager.lib.homeManagerConfiguration {
          pkgs = legacyPackages."aarch64-linux";
          extraSpecialArgs = { inherit inputs outputs; };
          modules = [
            ./home-manager
            {
              home.username = "pi";
            }
          ];
        };
      };
    };
}
