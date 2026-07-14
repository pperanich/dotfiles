# Host configuration for pp-ml1 (macOS laptop - Apple Silicon)
{
  lib,
  modules,
  pkgs,
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

    # Container runtime
    colima

    # Remote development via Discord
    # kimaki
  ];

  # Kimaki Discord bot for remote development
  # services.kimaki = {
  #   enable = true;
  #   enableVoiceChannels = true;
  # };

  clan.core.networking.targetHost = lib.mkForce "pperanich@pp-ml1.local";

  # cf share: expose a local port via an ephemeral Cloudflare Tunnel + Access.
  # cloudflared must be on PATH; cf drives the tunnel/DNS/Access lifecycle.
  environment.systemPackages = with pkgs; [
    cf
    cloudflared
  ];

  # Host-specific configuration
  networking.hostName = "pp-ml1";
  nixpkgs.hostPlatform = "aarch64-darwin";
}
