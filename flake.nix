{
  description = "My nix configs";

  inputs = {
    # Core
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    hardware.url = "github:nixos/nixos-hardware";

    # Temporary, for latest cursor
    # nixpkgs-cursor.url = "github:sarahec/nixpkgs/code-cursor-via-api";

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
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # https://github.com/elliotberman/jetpack-nixos/tree/jetpack6
    jetpack-nixos = {
      url = "github:elliotberman/jetpack-nixos/jetpack6";
      inputs.nixpkgs.follows = "nixpkgs";
    };


    # Disk Management
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Security & Utils
    sops-nix.url = "github:Mic92/sops-nix";
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    systems.url = "github:nix-systems/default";
    mac-app-util.url = "github:hraban/mac-app-util";

    # Development Tools
    neovim-nightly-overlay.url = "github:nix-community/neovim-nightly-overlay";
    emacs-overlay.url = "github:nix-community/emacs-overlay";
    nixgl.url = "github:guibou/nixGL";
    rust-overlay.url = "github:oxalica/rust-overlay";
    # ghostty.url = "github:ghostty-org/ghostty";

    # Additional Software
    nixcasks = {
      url = "github:jacekszymanski/nixcasks";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Development Tools
    nil.url = "github:oxalica/nil"; # Nix LSP
    treefmt-nix.url = "github:numtide/treefmt-nix"; # Formatting tools

    apple-fonts.url = "github:Lyndeno/apple-fonts.nix";
  };

  outputs = {
    self,
    nixpkgs,
    systems,
    darwin,
    home-manager,
    nixos-wsl,
    nixcasks,
    disko,
    ...
  } @ inputs: let
    inherit (self) outputs;
    lib = nixpkgs.lib.extend (self: super: {my = import ./lib {inherit (nixpkgs) lib;};});

    forEachSystem = f: lib.genAttrs (import systems) (system: f pkgsFor.${system});
    nixcasks =
      forEachSystem
      (inputs.nixcasks.output {
        osVersion = "sequoia";
      })
      .packages;

    pkgsFor = lib.genAttrs (import systems) (
      system:
        import nixpkgs {
          inherit system;
          config = {
            allowUnfree = true;
            allowBroken = true;
            # allowUnfreePredicate = _: true;
            permittedInsecurePackages = [
              "openssl-1.1.1w"
            ];
            overlays = builtins.attrValues outputs.overlays;
            packageOverrides = _: {
              inherit nixcasks;
            };
          };
        }
    );
  in {
    inherit lib;

    # Reusable modules
    sharedModules = import ./modules/shared;
    nixosModules = import ./modules/nixos;
    darwinModules = import ./modules/darwin;
    homeManagerModules = import ./modules/home-manager;

    # Overlays
    overlays = import ./overlays {inherit inputs outputs;};

    # Packages & Development Shells
    packages = forEachSystem (pkgs: import ./pkgs {inherit pkgs;});
    devShells = forEachSystem (pkgs: {
      default = import ./shell.nix {
        inherit pkgs;
      };
    });
    formatter = forEachSystem (pkgs: pkgs.alejandra);

    # System Configurations
    nixosConfigurations = {
      # Nvidia Orin AGX
      "pperanich-orin1" = lib.nixosSystem {
        modules = [
          ./hosts/pperanich-orin1
        ];
        specialArgs = {
          inherit inputs outputs;
        };
      };
      # Nvidia Xavier AGX
      "pperanich-xavier1" = lib.nixosSystem {
        modules = [
          ./hosts/pperanich-xavier1
        ];
        specialArgs = {
          inherit inputs outputs;
        };
      };

      # MacBook Pro 2019 with T2 chip
      "pperanich-ll1" = lib.nixosSystem {
        modules = [
          ./hosts/pperanich-ll1
        ];
        specialArgs = {
          inherit inputs outputs;
        };
      };

      # ISO for MacBook Pro installation
      macbook-pro-iso = lib.nixosSystem {
        modules = [
          ./hosts/macbook-pro-iso
        ];
        specialArgs = {
          inherit inputs outputs;
        };
      };

      # ISO for Apple T2 MacBook installation
      apple-t2-iso = lib.nixosSystem {
        modules = [
          ./hosts/apple-t2-iso
        ];
        specialArgs = {
          inherit inputs outputs;
        };
      };

      # Linux Desktop
      pperanich-ld1 = lib.nixosSystem {
        modules = [
          ./hosts/pperanich-ld1
        ];
        specialArgs = {
          inherit inputs outputs;
        };
      };

      # WSL Configuration
      pperanich-wsl1 = lib.nixosSystem {
        modules = [
          ./hosts/pperanich-wsl1
        ];
        specialArgs = {
          inherit inputs outputs;
        };
      };

      # Raspberry Pi
      pperanich-raspi1 = lib.nixosSystem {
        modules = [
          ./hosts/pperanich-raspi1
        ];
        specialArgs = {
          inherit inputs outputs;
        };
      };

      # Installation Media
      narwal-ld1 = lib.nixosSystem {
        modules = [
          ./hosts/narwal-ld1
        ];
        specialArgs = {
          inherit inputs outputs;
        };
      };
    };

    # Darwin Configurations
    darwinConfigurations = {
      # M3 Max MacBook
      peranpl1-ml2 = darwin.lib.darwinSystem {
        modules = [
          ./hosts/peranpl1-ml2
        ];
        specialArgs = {
          inherit inputs outputs lib;
        };
      };

      # Intel MacBook
      peranpl1-ml1 = darwin.lib.darwinSystem {
        modules = [
          ./hosts/peranpl1-ml1
        ];
        specialArgs = {
          inherit inputs outputs lib;
        };
      };
    };

    # Home Manager Configurations
    homeConfigurations = {
      peranpl1 = home-manager.lib.homeManagerConfiguration {
        pkgs = pkgsFor.x86_64-linux;
        modules = [
          ./home-manager/peranpl1
        ];
        extraSpecialArgs = {
          inherit inputs outputs;
          lib = lib.extend (_: _: home-manager.lib);
        };
      };
      pperanich = home-manager.lib.homeManagerConfiguration {
        pkgs = pkgsFor.x86_64-linux;
        modules = [
          ./home-manager/pperanich
        ];
        extraSpecialArgs = {
          inherit inputs outputs;
          lib = lib.extend (_: _: home-manager.lib);
        };
      };
      holo = home-manager.lib.homeManagerConfiguration {
        pkgs = pkgsFor.x86_64-linux;
        modules = [
          ./home-manager/holo
        ];
        extraSpecialArgs = {
          inherit inputs outputs;
          lib = lib.extend (_: _: home-manager.lib);
        };
      };
    };
  };
}
