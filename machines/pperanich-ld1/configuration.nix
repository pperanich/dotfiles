# Host configuration for pperanich-ld1 (Linux desktop)
{inputs, ...}: {
  imports = [
    ./hardware-configuration.nix

    # Core system configuration
    inputs.self.modules.nixos.base
    inputs.self.modules.homeManager.base

    # User setup
    inputs.self.modules.nixos.pperanich
    inputs.self.modules.homeManager.pperanich

    # System utilities
    inputs.self.modules.nixos.fileExploration
    inputs.self.modules.homeManager.fileExploration
    inputs.self.modules.nixos.networkUtilities
    inputs.self.modules.homeManager.networkUtilities

    # Development environment
    inputs.self.modules.homeManager.nvim
    inputs.self.modules.homeManager.zsh
    inputs.self.modules.nixos.rust
    inputs.self.modules.homeManager.rust

    # Database services
    inputs.self.modules.nixos.couchdb
    inputs.self.modules.homeManager.couchdb

    # Virtualization
    inputs.self.modules.nixos.docker
    inputs.self.modules.homeManager.docker
    inputs.self.modules.nixos.podman
    inputs.self.modules.homeManager.podman
  ];

  nixpkgs.hostPlatform = "x86_64-linux";
  networking.hostName = "pperanich-ld1";
}
