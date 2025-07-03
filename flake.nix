{
  description = "My nix configs";

  inputs = {
    # Core
    nixpkgs.url = "github:nixos/nixpkgs/release-25.05";
    hardware.url = "github:nixos/nixos-hardware";

    # System Management
    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    darwin = {
      url = "github:LnL7/nix-darwin/nix-darwin-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-wsl = {
      url = "github:nix-community/nixos-wsl";
      inputs.nixpkgs.follows = "nixpkgs";
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
      url = "github:pperanich/sops-nix/hm-package-option";
      inputs.nixpkgs.follows = "nixpkgs";
    };
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

    # Generate all configurations automatically
    allConfigurations = lib.my.mkAllConfigurations {
      inherit inputs outputs lib darwin home-manager pkgsFor;
      additionalUsers = ["hst" "holo" "mxwbio"];
    };
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

    # Automatically generated configurations
    inherit (allConfigurations) nixosConfigurations;
    inherit (allConfigurations) darwinConfigurations;
    inherit (allConfigurations) homeConfigurations;
  };
}
