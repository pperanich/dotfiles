# Tailscale feature module
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.my.features.tailscale;
in {
  options.my.features.tailscale = {
    enable = lib.mkEnableOption "Tailscale VPN";
  };

  config = lib.mkIf cfg.enable {
    services.tailscale = {
      enable = true;
      package = pkgs.tailscale;
      # Optional (default: 41641):
      port = 41641;
    };

    networking.firewall = {
      # Enable Tailscale's ports
      # allowedUDPPorts = [ config.services.tailscale.port ];
      # Enable Tailscale's built-in firewall
      trustedInterfaces = ["tailscale0"];
    };
  };
}
