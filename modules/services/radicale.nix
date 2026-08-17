# CalDAV / CardDAV server (calendar and contacts sync)
#
# Lightweight Python server. Designed to sit behind a reverse proxy that
# provides authentication and passes the username via X-Remote-User header.
#
# Used alongside OpenCloud to provide calendar/contacts functionality.
# Can also be used standalone with any reverse proxy that sets X-Remote-User.
#
# Access: proxied through the same domain as OpenCloud (e.g., /caldav/, /carddav/)
_: {
  flake.modules.nixos.radicale =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.my.radicale;
    in
    {
      options.my.radicale = {
        address = lib.mkOption {
          type = lib.types.str;
          default = "127.0.0.1";
          description = "Address for Radicale to bind to.";
        };

        port = lib.mkOption {
          type = lib.types.port;
          default = 5232;
          description = "Port for Radicale to listen on.";
        };

        dataDir = lib.mkOption {
          type = lib.types.path;
          default = "/var/lib/radicale/collections";
          description = "Directory for Radicale calendar/contact storage.";
        };

        # Radicale trusts X-Remote-User blindly, so the proxy in front of it has
        # to authenticate. The hash lives in sops; this module renders it into
        # Caddy's environment and hands back the variable name to reference.
        basicAuthHashSecret = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "radicale-password-hash";
          description = ''
            sops key holding a bcrypt hash for Caddy's basic_auth. When set, the
            module renders it into Caddy's EnvironmentFile; reference it in the
            vhost via basicAuthHashPlaceholder.
          '';
        };

        basicAuthHashEnvVar = lib.mkOption {
          type = lib.types.str;
          readOnly = true;
          default = "RADICALE_PASSWORD_HASH";
          description = "Read-only. Name of the env var carrying the basic_auth hash.";
        };

        basicAuthHashPlaceholder = lib.mkOption {
          type = lib.types.str;
          readOnly = true;
          default = "{$" + cfg.basicAuthHashEnvVar + "}";
          description = ''
            Read-only. Caddy env-var reference for the hash, ready to drop into a
            vhost: `pperanich ''${config.my.radicale.basicAuthHashPlaceholder}`.
            Built by concatenation because `{$''${var}}` inside an indented string
            is a literal-$ escape, not an interpolation.
          '';
        };
      };

      config = lib.mkMerge [
        (lib.mkIf (cfg.basicAuthHashSecret != null) {
          sops = {
            secrets.${cfg.basicAuthHashSecret} = { };

            templates."caddy-radicale.env" = {
              content = "${cfg.basicAuthHashEnvVar}=${config.sops.placeholder.${cfg.basicAuthHashSecret}}";
              owner = "caddy";
              restartUnits = [ "caddy.service" ];
            };
          };

          systemd.services.caddy.serviceConfig.EnvironmentFile = [
            config.sops.templates."caddy-radicale.env".path
          ];
        })
        {
          # PrivateUsers remaps UIDs inside the namespace, making external paths
          # (like /tank on ZFS) appear owned by nobody. Disable it so Radicale
          # can write to its data directory. Other sandboxing remains in place.
          systemd.services.radicale.serviceConfig.PrivateUsers = lib.mkForce false;

          # Ensure the data directory exists before the service starts.
          # The upstream module only creates /var/lib/radicale/collections via StateDirectory.
          systemd.tmpfiles.settings."10-radicale" = {
            ${cfg.dataDir}.d = {
              user = "radicale";
              group = "radicale";
              mode = "0750";
            };
          };

          services.radicale = {
            enable = true;
            settings = {
              server = {
                hosts = [ "${cfg.address}:${toString cfg.port}" ];
                # Disable TLS — reverse proxy handles HTTPS termination
                ssl = false;
              };
              auth = {
                # Trust the username provided by the reverse proxy (X-Remote-User header)
                type = "http_x_remote_user";
              };
              web = {
                # Disable built-in web UI — access via OpenCloud or native clients
                type = "none";
              };
              storage = {
                filesystem_folder = cfg.dataDir;
              };
            };
          };
        }
      ];
    };
}
