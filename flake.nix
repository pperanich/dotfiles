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

    # WSL
    NixOS-WSL.url = "github:nix-community/NixOS-WSL";
    NixOS-WSL.inputs.nixpkgs.follows = "nixpkgs";

    # SOPS
    sops-nix.url = "github:Mic92/sops-nix";

    # Nix Casks
    nixcasks.url = "github:jacekszymanski/nixcasks";
    nixcasks.inputs.nixpkgs.follows = "nixpkgs";

    hardware.url = "github:nixos/nixos-hardware";

    neovim-nightly-overlay.url = "github:nix-community/neovim-nightly-overlay";
    neovim-nightly-overlay.inputs.nixpkgs.follows = "nixpkgs";

    emacs-overlay.url = "github:nix-community/emacs-overlay";
    nixgl.url = "github:guibou/nixGL";
    rust-overlay.url = "github:oxalica/rust-overlay";

    nix-index-database.url = "github:nix-community/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";
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
      inherit (inputs.nixpkgs.lib) attrValues;
    in
    rec {
      nixosModules = import ./modules/nixos;
      darwinModules = import ./modules/darwin;
      homeManagerModules = import ./modules/home-manager;

      overlays = import ./overlays { inherit inputs; };

      legacyPackages = forAllSystems (system:
        import nixpkgs {
          inherit system;
          config = {
            allowUnfree = true;
            allowBroken = true;
            allowUnfreePredicate = _: true;
            overlays = builtins.attrValues outputs.overlays;
            packageOverrides = _: {
              nixcasks = import inputs.nixcasks {
                inherit nixpkgs;
                pkgs = import nixpkgs {};
                osVersion = "sonoma";
              };
            };
          };
        }
      );

      packages = forAllSystems (system:
        let pkgs = legacyPackages.${system};
        in import ./pkgs { inherit pkgs; }
      );

      devShells = forAllSystems (system:
        let pkgs = legacyPackages.${system};
        in import ./shell.nix { inherit pkgs; }
      );

      nixosConfigurations = {
        "pperanich-ld1" = nixpkgs.lib.nixosSystem {
          specialArgs = { inherit inputs outputs; };
          modules = [
            ./nixos/configuration.nix
          ];
        };
        "pperanich-wsl1" = nixpkgs.lib.nixosSystem {
          specialArgs = { inherit inputs outputs; };
          modules = [
            ./hosts/pperanich-wsl1
          ];
        };
        "pperanich-raspi1" = nixpkgs.lib.nixosSystem {
          specialArgs = { inherit inputs outputs; };
          modules = [
            "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
            ./hosts/pperanich-raspi1
          ];
        };
        "narwhal-ld1" = nixpkgs.lib.nixosSystem {
          specialArgs = { inherit inputs outputs; };
          modules = [
            "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
            ./hosts/narwhal-ld1
          ];
        };
      };

      darwinConfigurations = {
        "peranpl1-ml2" = darwin.lib.darwinSystem {
          specialArgs = { inherit inputs outputs; };
          modules = attrValues self.darwinModules ++ [
            {nixpkgs.hostPlatform = "aarch64-darwin";}
            ./darwin/configuration.nix
            ./darwin/features/yabai.nix
            ./darwin/features/sketchybar.nix
            ./darwin/features/skhd.nix
            home-manager.darwinModules.home-manager
            {
              home-manager = {
                extraSpecialArgs = { inherit inputs outputs; };
                useUserPackages = true;
                users.peranpl1 = {
                  imports = [
                    ./home-manager
                    # ./home-manager/features/emacs.nix
                    ./home-manager/features/desktop.nix
                    ./home-manager/features/tex.nix
                    ./home-manager/features/darwin.nix
                    ./home-manager/features/aplnis.nix
                    ./home-manager/features/vscode.nix
                    ./home-manager/features/fonts.nix
                    ./home-manager/features/rust.nix
                  ];
                };
              };
            }
          ];
        };
        "peranpl1-ml1" = darwin.lib.darwinSystem {
          specialArgs = { inherit inputs outputs; };
          modules = attrValues self.darwinModules ++ [
            {nixpkgs.hostPlatform = "x86_64-darwin";}
            ./darwin/configuration.nix
            ./darwin/features/yabai.nix
            ./darwin/features/sketchybar.nix
            ./darwin/features/skhd.nix
            home-manager.darwinModules.home-manager
            {
              home-manager = {
                extraSpecialArgs = { inherit inputs outputs; };
                useUserPackages = true;
                users.peranpl1 = {
                  imports = [
                    ./home-manager
                    ./home-manager/features/emacs.nix
                    ./home-manager/features/desktop.nix
                    ./home-manager/features/tex.nix
                    ./home-manager/features/darwin.nix
                    ./home-manager/features/aplnis.nix
                    ./home-manager/features/vscode.nix
                    ./home-manager/features/fonts.nix
                    ./home-manager/features/rust.nix
                  ];
                };
              };
            }
          ];
        };
        "B1LOAN-21-ML126" = darwin.lib.darwinSystem {
          specialArgs = { inherit inputs outputs; };
          modules = attrValues self.darwinModules ++ [
            {nixpkgs.hostPlatform = "aarch64-darwin";}
            ./darwin/configuration.nix
            ./darwin/features/yabai.nix
            ./darwin/features/sketchybar.nix
            ./darwin/features/skhd.nix
            home-manager.darwinModules.home-manager
            {
              home-manager = {
                extraSpecialArgs = { inherit inputs outputs; };
                useUserPackages = true;
                users.peranpl1 = {
                  imports = [
                    ./home-manager
                    # ./home-manager/features/emacs.nix
                    ./home-manager/features/desktop.nix
                    ./home-manager/features/tex.nix
                    ./home-manager/features/darwin.nix
                    ./home-manager/features/aplnis.nix
                    ./home-manager/features/vscode.nix
                    ./home-manager/features/fonts.nix
                    ./home-manager/features/rust.nix
                  ];
                };
              };
            }
          ];
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
                ./home-manager/features/darwin.nix
                ./home-manager/features/fonts.nix
              ];
            }
          ];
        };
        "peranpl1" = home-manager.lib.homeManagerConfiguration {
          pkgs = legacyPackages.x86_64-linux;
          extraSpecialArgs = { inherit inputs outputs; };
          modules = [
            ./home-manager
            {
              home.username = "peranpl1";
              imports = [
                ./home-manager/features/aplnis.nix
                ./home-manager/features/rust.nix
                ./home-manager/features/desktop.nix
                ./home-manager/features/standalone.nix
                ./home-manager/features/fonts.nix
              ];
            }
          ];
        };
        "peranpl1@holobrain-ld1" = home-manager.lib.homeManagerConfiguration {
          pkgs = legacyPackages.x86_64-linux;
          extraSpecialArgs = { inherit inputs outputs; };
          modules = [
            ./home-manager
            {
              home.username = "peranpl1";
              imports = [
                ./home-manager/features/emacs.nix
                ./home-manager/features/desktop.nix
                ./home-manager/features/standalone.nix
                ./home-manager/features/fonts.nix
                ./home-manager/features/aplnis.nix
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
                ./home-manager/features/standalone.nix
                ./home-manager/features/fonts.nix
                ./home-manager/features/aplnis.nix
              ];
            }
          ];
        };
        "peranpl1@holobrain-ld2" = home-manager.lib.homeManagerConfiguration {
          pkgs = legacyPackages.x86_64-linux;
          extraSpecialArgs = { inherit inputs outputs; };
          modules = [
            ./home-manager
            {
              home.username = "peranpl1";
              imports = [
                ./home-manager/features/emacs.nix
                ./home-manager/features/desktop.nix
                ./home-manager/features/standalone.nix
                ./home-manager/features/fonts.nix
                ./home-manager/features/aplnis.nix
              ];
            }
          ];
        };
        "holo@holobrain-ld2" = home-manager.lib.homeManagerConfiguration {
          pkgs = legacyPackages.x86_64-linux;
          extraSpecialArgs = { inherit inputs outputs; };
          modules = [
            ./home-manager
            {
              home.username = "holo";
              imports = [
                # ./home-manager/features/emacs.nix
                ./home-manager/features/desktop.nix
                ./home-manager/features/standalone.nix
                ./home-manager/features/fonts.nix
                ./home-manager/features/aplnis.nix
                # { services.sunshine.enable = true; }
              ];
            }
          ];
        };
        "peranpl1@holobrain-ld3" = home-manager.lib.homeManagerConfiguration {
          pkgs = legacyPackages.x86_64-linux;
          extraSpecialArgs = { inherit inputs outputs; };
          modules = [
            ./home-manager
            {
              home.username = "peranpl1";
              imports = [
                # ./home-manager/features/emacs.nix
                ./home-manager/features/desktop.nix
                ./home-manager/features/standalone.nix
                ./home-manager/features/fonts.nix
                ./home-manager/features/aplnis.nix
              ];
            }
          ];
        };
        "holo@holobrain-ld3" = home-manager.lib.homeManagerConfiguration {
          pkgs = legacyPackages.x86_64-linux;
          extraSpecialArgs = { inherit inputs outputs; };
          modules = [
            ./home-manager
            {
              home.username = "holo";
              imports = [
                # ./home-manager/features/emacs.nix
                ./home-manager/features/desktop.nix
                ./home-manager/features/standalone.nix
                ./home-manager/features/fonts.nix
                ./home-manager/features/aplnis.nix
              ];
            }
          ];
        };
        "mxwbio@mxwbio" = home-manager.lib.homeManagerConfiguration {
          pkgs = legacyPackages.x86_64-linux;
          extraSpecialArgs = { inherit inputs outputs; };
          modules = [
            ./home-manager
            {
              home.username = "mxwbio";
              imports = [
                # ./home-manager/features/desktop.nix
                ./home-manager/features/standalone.nix
                ./home-manager/features/fonts.nix
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
                ./home-manager/features/standalone.nix
                ./home-manager/features/fonts.nix
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
                ./home-manager/features/standalone.nix
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
                ./home-manager/features/standalone.nix
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
              imports = [
                ./home-manager/features/standalone.nix
              ];
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
              imports = [
                ./home-manager/features/standalone.nix
              ];
            }
          ];
        };
      };
    };
}
