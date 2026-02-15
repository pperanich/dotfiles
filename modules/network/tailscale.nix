_: {
  flake.modules = {
    # NixOS system-level Tailscale configuration
    nixos.tailscale =
      {
        config,
        lib,
        ...
      }:
      let
        cfg = config.features.tailscale;
      in
      {
        options.features.tailscale = {
          authKeyFile = lib.mkOption {
            type = lib.types.nullOr lib.types.path;
            default = null;
            description = "Path to Tailscale auth key file";
          };
          exitNode = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Enable this node as an exit node";
          };
          subnet = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            example = "192.168.1.0/24";
            description = "Subnet to advertise";
          };
          acceptRoutes = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Accept subnet routes from other nodes";
          };
        };

        config = {
          # Tailscale service
          services.tailscale = {
            enable = true;
            inherit (cfg) authKeyFile;
            extraUpFlags =
              lib.optional cfg.exitNode "--advertise-exit-node"
              ++ lib.optional (cfg.subnet != null) "--advertise-routes=${cfg.subnet}"
              ++ lib.optional cfg.acceptRoutes "--accept-routes";
          };

          # Enable IP forwarding if acting as exit node or subnet router
          boot.kernel.sysctl = lib.mkIf (cfg.exitNode || cfg.subnet != null) {
            "net.ipv4.ip_forward" = 1;
            "net.ipv6.conf.all.forwarding" = 1;
          };

          # Firewall configuration
          networking.firewall = {
            # Enable if using as subnet router or exit node
            checkReversePath = lib.mkIf (cfg.exitNode || cfg.subnet != null) "loose";

            # Tailscale uses UDP 41641
            allowedUDPPorts = [ 41641 ];

            # Trust Tailscale interface
            trustedInterfaces = [ "tailscale0" ];
          };

          # systemd-resolved conflicts with Tailscale MagicDNS
          services.resolved.enable = lib.mkDefault false;
        };
      };

    # Darwin Tailscale configuration
    darwin.tailscale =
      {
        pkgs,
        ...
      }:
      {
        # Tailscale on macOS is typically installed via App Store or PKG
        # This module provides CLI tools and configuration
        environment.systemPackages = with pkgs; [
          tailscale
        ];

        # Enable Tailscale daemon (requires manual setup)
        # Note: macOS Tailscale typically runs as a GUI app
      };

    # Home Manager Tailscale tools
    homeManager.tailscale =
      { pkgs, ... }:
      {
        home.packages = with pkgs; [
          tailscale
        ];
      };
  };
}
