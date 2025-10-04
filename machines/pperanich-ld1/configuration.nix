# Host configuration for pperanich-ld1 (Linux desktop)
{
  modules,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
  ]
  ++ (with modules.nixos; [
    # Core system configuration
    base

    # User setup
    pperanich

    # System utilities
    fileExploration
    networkUtilities

    # Development environment
    rust

    # Database services
    couchdb

    # Virtualization
    docker
    podman
  ]);

  nixpkgs.hostPlatform = "x86_64-linux";
  networking.hostName = "pperanich-ld1";
}
