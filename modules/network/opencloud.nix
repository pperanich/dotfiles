# Self-hosted file sync and sharing platform (Go-based, single binary)
#
# Modern alternative to Nextcloud — no database, no Redis, no PHP.
# Uses OpenID Connect for auth and stores metadata on the filesystem.
#
# Access: via Caddy reverse proxy on the router (e.g., opencloud.prestonperanich.com)
# Admin: initial password injected via environmentFile option
_: {
  flake.modules.nixos.opencloud =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.features.opencloud;
    in
    {
      options.features.opencloud = {
        url = lib.mkOption {
          type = lib.types.str;
          example = "https://opencloud.prestonperanich.com";
          description = "Public URL for the OpenCloud instance (including scheme).";
        };

        address = lib.mkOption {
          type = lib.types.str;
          default = "127.0.0.1";
          description = "Address for OpenCloud to bind to.";
        };

        port = lib.mkOption {
          type = lib.types.port;
          default = 9200;
          description = "Port for OpenCloud proxy service.";
        };

        stateDir = lib.mkOption {
          type = lib.types.path;
          default = "/var/lib/opencloud";
          description = "Directory for OpenCloud data storage.";
        };

        openFirewall = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Whether to open the firewall for OpenCloud.";
        };

        environmentFile = lib.mkOption {
          type = lib.types.path;
          description = "Path to environment file containing IDM_ADMIN_PASSWORD";
        };
      };

      config = {
        services.opencloud = {
          enable = true;
          inherit (cfg)
            url
            address
            port
            stateDir
            environmentFile
            ;
          environment = {
            # Disable TLS — Caddy on the router handles HTTPS termination
            OC_INSECURE = "true";
            PROXY_TLS = "false";
          };
        };

        # Ensure state directory exists with correct ownership
        systemd.tmpfiles.settings."10-opencloud" = {
          ${cfg.stateDir}."d" = {
            user = "opencloud";
            group = "opencloud";
            mode = "0750";
          };
        };

        networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];
      };
    };
}
