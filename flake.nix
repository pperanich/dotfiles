{
  description = "My custom nix configs";

  inputs = {
    # Core
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    hardware.url = "github:nixos/nixos-hardware";

    # System Management
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    NixOS-WSL = {
      url = "github:nix-community/NixOS-WSL";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Security & Utils
    sops-nix.url = "github:Mic92/sops-nix";
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    systems.url = "github:nix-systems/default";

    # Development Tools
    neovim-nightly-overlay.url = "github:nix-community/neovim-nightly-overlay";
    emacs-overlay.url = "github:nix-community/emacs-overlay";
    nixgl.url = "github:guibou/nixGL";
    rust-overlay.url = "github:oxalica/rust-overlay";

    # Additional Software
    nixcasks = {
      url = "github:jacekszymanski/nixcasks";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    
    # Development Tools
    nil.url = "github:oxalica/nil"; # Nix LSP
    treefmt-nix.url = "github:numtide/treefmt-nix"; # Formatting tools
  };

  outputs = { self, nixpkgs, systems, darwin, home-manager, NixOS-WSL, ... }@inputs:
    let
      inherit (self) outputs;
      # lib = nixpkgs.lib;
      lib = nixpkgs.lib.extend (self: super: { custom = import ./lib { inherit (nixpkgs) lib; }; });

      forEachSystem = f: lib.genAttrs (import systems) (system: f pkgsFor.${system});
      pkgsFor = lib.genAttrs (import systems) (
        system:
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
    in {
      inherit lib;

      # Reusable modules
      commonModules = import ./modules/common;
      nixosModules = import ./modules/nixos;
      darwinModules = import ./modules/darwin;
      homeManagerModules = import ./modules/home-manager;

      # Overlays
      overlays = import ./overlays {inherit inputs outputs;};

      # Packages & Development Shells
      packages = forEachSystem (pkgs: import ./pkgs {inherit pkgs;});
      devShells = forEachSystem (pkgs: import ./shell.nix {inherit pkgs;});
      formatter = forEachSystem (pkgs: pkgs.alejandra);

      # System Configurations
      # nixosConfigurations = {
      #   # Linux Desktop
      #   pperanich-ld1 = lib.nixosSystem {
      #     modules = [
      #       ./hosts/pperanich-ld1
      #     ];
      #     specialArgs = {
      #       inherit inputs outputs;
      #     };
      #   };

      #   # WSL Configuration
      #   pperanich-wsl1 = lib.nixosSystem {
      #     modules = [
      #       ./hosts/pperanich-wsl1
      #     ];
      #     specialArgs = {
      #       inherit inputs outputs;
      #     };
      #   };

      #   # Raspberry Pi
      #   pperanich-raspi1 = lib.nixosSystem {
      #     modules = [
      #       ./hosts/pperanich-raspi1
      #     ];
      #     specialArgs = {
      #       inherit inputs outputs;
      #     };
      #   };

      #   # Installation Media
      #   narwhal-ld1 = lib.nixosSystem {
      #     modules = [
      #       ./hosts/narwhal-ld1
      #     ];
      #     specialArgs = {
      #       inherit inputs outputs;
      #     };
      #   };
      # };

      # Darwin Configurations
      darwinConfigurations = {
        # M1 MacBook
        peranpl1-ml2 = darwin.lib.darwinSystem {
          modules = [
            ./hosts/peranpl1-ml2
          ];
          specialArgs = {
            inherit inputs outputs lib;
          };
        };

        # Intel MacBook
        # peranpl1-ml1 = darwin.lib.darwinSystem {
        #   modules = [
        #     ./hosts/peranpl1-ml1
        #   ];
        #   specialArgs = {
        #     inherit inputs outputs;
        #   };
        # };

        # # Work MacBook
        # B1LOAN-21-ML126 = darwin.lib.darwinSystem {
        #   modules = [
        #     ./hosts/B1LOAN-21-ML126
        #   ];
        #   specialArgs = {
        #     inherit inputs outputs;
        #   };
        # };
      };

    #   # Home Manager Configurations
    #   homeConfigurations = {
    #     # Linux Workstations
    #     "peranpl1@holobrain-ld1" = home-manager.lib.homeManagerConfiguration {
    #       pkgs = pkgsFor.x86_64-linux;
    #       modules = [
    #         ./home-manager/users/peranpl1
    #         ./home-manager/features/emacs.nix
    #         ./home-manager/features/desktop.nix
    #         ./home-manager/features/aplnis.nix
    #       ];
    #     };

    #     "holo@holobrain-ld1" = home-manager.lib.homeManagerConfiguration {
    #       pkgs = pkgsFor.x86_64-linux;
    #       modules = [
    #         ./home-manager/users/holo
    #         ./home-manager/features/desktop.nix
    #         ./home-manager/features/aplnis.nix
    #       ];
    #     };

    #     # Embedded Systems
    #     "pi@om-apl-st2-raspi1" = home-manager.lib.homeManagerConfiguration {
    #       pkgs = pkgsFor.aarch64-linux;
    #       modules = [
    #         ./home-manager/users/pi
    #       ];
    #     };

    #     "nvidia@om-apl-st2-agx1" = home-manager.lib.homeManagerConfiguration {
    #       pkgs = pkgsFor.aarch64-linux;
    #       modules = [
    #         ./home-manager/users/nvidia
    #       ];
    #     };
    #   };
    };
}
