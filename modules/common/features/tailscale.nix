# Tailscale feature module
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.modules.features.tailscale;
in {
  options.modules.features.tailscale = {
    enable = lib.mkEnableOption "Tailscale VPN";
  };

  config = lib.mkIf cfg.enable {
    services.tailscale = {
      enable = true;
      package = pkgs.tailscale;
    };

    networking.firewall = {
      # Enable Tailscale's ports
      allowedUDPPorts = [config.services.tailscale.port];
      # Enable Tailscale's built-in firewall
      trustedInterfaces = ["tailscale0"];
    };
  };
}
