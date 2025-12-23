# Host configuration for pperanich-ml1 (macOS laptop - Apple Silicon)
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

  # services.aerospace.enable = true;
  homebrew = {
    casks = [
      "nikitabobko/tap/aerospace"
      "leader-key"
    ];
  };

  clan.core.networking.targetHost = lib.mkForce "root@pperanich-ml1";
  clan.core.networking.buildHost = "root@pperanich-ml1";

  # Host-specific configuration
  networking.hostName = "pperanich-ml1";
  nixpkgs.hostPlatform = "aarch64-darwin";
}
