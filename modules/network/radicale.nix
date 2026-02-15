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
      cfg = config.features.radicale;
    in
    {
      options.features.radicale = {
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
      };

      config = {
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
      };
    };
}
