# Self-hosted file sync and collaboration platform
#
# Provides CalDAV (calendar), CardDAV (contacts), file sync, and more.
# Uses PostgreSQL + Redis for performance. Nginx handles PHP-FPM locally.
#
# Access: via Caddy reverse proxy on the router (e.g., nextcloud.prestonperanich.com)
# Admin: the `admin` account made at installation; reset it with
# `nextcloud-occ user:resetpassword admin` (nixpkgs no longer manages it).
_: {
  flake.modules.nixos.nextcloud =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.my.nextcloud;
    in
    {
      options.my.nextcloud = {
        hostName = lib.mkOption {
          type = lib.types.str;
          example = "nextcloud.prestonperanich.com";
          description = "FQDN for the Nextcloud instance.";
        };

        datadir = lib.mkOption {
          type = lib.types.path;
          default = "/var/lib/nextcloud";
          description = "Directory for Nextcloud data storage.";
        };

        maxUploadSize = lib.mkOption {
          type = lib.types.str;
          default = "16G";
          description = "Maximum upload size.";
        };

        defaultPhoneRegion = lib.mkOption {
          type = lib.types.str;
          default = "US";
          description = "Default phone region (ISO 3166-1 alpha-2).";
        };

        listenAddress = lib.mkOption {
          type = lib.types.str;
          default = "127.0.0.1";
          description = "Address for the local Nginx backend to bind to.";
        };

        listenPort = lib.mkOption {
          type = lib.types.port;
          default = 8088;
          description = "Port for the local Nginx backend to listen on.";
        };

        openFirewall = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Whether to open listenPort in the host firewall.";
        };

        extraTrustedDomains = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          example = [ "192.168.0.161" ];
          description = "Additional trusted domains beyond hostName.";
        };

        trustedProxies = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [
            "127.0.0.1"
            "::1"
          ];
          example = [
            "127.0.0.1"
            "::1"
          ];
          description = "Reverse proxy IPs to trust for X-Forwarded-For headers.";
        };

        extraApps = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          example = [
            "calendar"
            "contacts"
            "tasks"
            "notes"
          ];
          description = "Nextcloud apps to install from nixpkgs (by attribute name).";
        };
      };

      config = {
        services = {
          nextcloud = {
            enable = true;
            # One major per deploy, and each must run once (nextcloud-setup upgrades the database):
            # Upgrade one major at a time; Nextcloud refuses to skip one.
            package = pkgs.nextcloud35;
            inherit (cfg) hostName;
            inherit (cfg) datadir;
            https = true;
            inherit (cfg) maxUploadSize;

            # Automatic PostgreSQL + Redis
            database.createLocally = true;
            configureRedis = true;

            config = {
              dbtype = "pgsql";
            };

            settings = {
              overwriteprotocol = "https";
              default_phone_region = cfg.defaultPhoneRegion;
              trusted_domains = [ cfg.hostName ] ++ cfg.extraTrustedDomains;
              trusted_proxies = cfg.trustedProxies;
              log_type = "systemd";

              # Enable HEIC preview (iPhone photos)
              enabledPreviewProviders = [
                "OC\\Preview\\BMP"
                "OC\\Preview\\GIF"
                "OC\\Preview\\JPEG"
                "OC\\Preview\\Krita"
                "OC\\Preview\\MarkDown"
                "OC\\Preview\\MP3"
                "OC\\Preview\\OpenDocument"
                "OC\\Preview\\PNG"
                "OC\\Preview\\TXT"
                "OC\\Preview\\XBitmap"
                "OC\\Preview\\HEIC"
              ];
            };

            # Pre-installed apps from nixpkgs
            extraApps = lib.listToAttrs (
              map (name: {
                inherit name;
                value = config.services.nextcloud.package.packages.apps.${name};
              }) cfg.extraApps
            );
            extraAppsEnable = true;
            autoUpdateApps.enable = true;

            # PHP tuning for a small home server
            phpOptions = {
              "opcache.interned_strings_buffer" = "16";
              "opcache.max_accelerated_files" = "10000";
              "opcache.memory_consumption" = "128";
            };
          };

          # Nginx listens on loopback locally; Caddy terminates HTTPS in front
          nginx.virtualHosts.${cfg.hostName} = {
            listen = [
              {
                addr = cfg.listenAddress;
                port = cfg.listenPort;
              }
            ];
          };

          # Automatic database backups (mkDefault so hosts can customize schedule/location)
          postgresqlBackup = {
            enable = lib.mkDefault true;
            startAt = lib.mkDefault "*-*-* 02:00:00";
          };
        };

        networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.listenPort ];

        # Ensure data directory exists with correct ownership
        systemd.tmpfiles.settings."10-nextcloud" = {
          ${cfg.datadir}."d" = {
            user = "nextcloud";
            group = "nextcloud";
            mode = "0750";
          };
        };
      };
    };
}
