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
      cfg = config.my.opencloud;
    in
    {
      options.my.opencloud = {
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

        adminPasswordSecret = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "opencloud-admin-pass";
          description = ''
            sops key holding the initial admin password. The module renders
            IDM_ADMIN_PASSWORD from it, so the env var name stays in here.
          '';
        };

        environmentFile = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          description = ''
            Escape hatch for supplying IDM_ADMIN_PASSWORD yourself. Prefer
            adminPasswordSecret, which builds this file from sops.
          '';
        };
      };

      config =
        let
          envFile =
            if cfg.environmentFile != null then
              cfg.environmentFile
            else if cfg.adminPasswordSecret != null then
              config.sops.templates."opencloud.env".path
            else
              null;
        in
        {
          assertions = [
            {
              assertion = cfg.adminPasswordSecret != null || cfg.environmentFile != null;
              message = ''
                my.opencloud has no admin password. Set
                `my.opencloud.adminPasswordSecret = "<sops key>";` — the module renders
                IDM_ADMIN_PASSWORD from it — or supply my.opencloud.environmentFile.
              '';
            }
          ];

          sops = lib.mkIf (cfg.adminPasswordSecret != null) {
            secrets.${cfg.adminPasswordSecret} = {
              owner = "opencloud";
              mode = "0400";
            };

            templates."opencloud.env" = {
              content = "IDM_ADMIN_PASSWORD=${config.sops.placeholder.${cfg.adminPasswordSecret}}";
              owner = "opencloud";
              restartUnits = [ "opencloud.service" ];
            };
          };

          services.opencloud = {
            enable = true;
            environmentFile = lib.mkIf (envFile != null) envFile;
            inherit (cfg)
              url
              address
              port
              stateDir
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
