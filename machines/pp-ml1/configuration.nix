# Host configuration for pp-ml1 (macOS laptop - Apple Silicon)
{
  lib,
  modules,
  ...
}:
{
  imports = with modules.darwin; [
    # Core system configuration
    base
    sops

    # User setup
    pperanich

    # Development environment
    rust

    # Window management
    sketchybar
  ];

  clan.core.networking.targetHost = lib.mkForce "root@pp-ml1";
  clan.core.networking.buildHost = "root@pp-ml1";

  # Host-specific configuration
  networking.hostName = "pp-ml1";
  nixpkgs.hostPlatform = "aarch64-darwin";
}
