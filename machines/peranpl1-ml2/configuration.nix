# Host configuration for peranpl1-ml2 (macOS laptop - Apple Silicon)
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
    peranpl1

    # Development environment
    rust

    # Work environment
    aplnis

    # Window management
    # yabai
    # skhd
    sketchybar
  ];

  clan.core.networking.targetHost = lib.mkForce "root@peranpl1-ml2";
  clan.core.networking.buildHost = "root@peranpl1-ml2";

  # Host-specific configuration
  networking.hostName = "peranpl1-ml2";
  nixpkgs.hostPlatform = "aarch64-darwin";
}
