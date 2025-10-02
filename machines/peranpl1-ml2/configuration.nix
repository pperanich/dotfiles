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

    # User setup
    peranpl1

    # Development environment
    rust

    # Work environment
    aplnis

    # Window management
    yabai
    skhd
    sketchybar
  ];

  home-manager.users.peranpl1 = {
    imports = with modules.homeManager; [
      # Core system configuration
      base

      # Desktop environment
      fonts
      desktopApplications
      zsh

      # Development environment
      nvim
      vscode
      rust

      # Network and file utilities
      networkUtilities
      fileExploration

      # Work environment
      aplnis
    ];
  };

  clan.core.networking.targetHost = lib.mkForce "root@peranpl1-ml2";
  clan.core.networking.buildHost = "root@peranpl1-ml2";

  # Host-specific configuration
  networking.hostName = "peranpl1-ml2";
  nixpkgs.hostPlatform = "aarch64-darwin";
}
