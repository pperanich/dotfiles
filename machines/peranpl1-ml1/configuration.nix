# Host configuration for peranpl1-ml1 (macOS laptop)
{
  modules,
  lib,
  ...
}:
{
  imports = with modules.darwin; [
    # Core system configuration
    base

    # User setup
    peranpl1

    # Development environment
    rust

    # Container runtime
    colima

    # Work environment
    work
  ];

  clan.core.networking.targetHost = lib.mkForce "peranpl1@peranpl1-ml1.local";

  # Host-specific configuration
  networking.hostName = "peranpl1-ml1";
  nixpkgs.hostPlatform = "x86_64-darwin";
}
