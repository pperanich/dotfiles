# Host configuration for pp-ml1 (macOS laptop - Apple Silicon)
{
  modules,
  pkgs,
  ...
}:
{
  imports = with modules.darwin; [
    # Core system configuration
    base
    sops
    tailscale

    # User setup
    pperanich

    # Development environment
    rust

    # Window management
    sketchybar

    # Container runtime
    colima

    aiTools
  ];

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
