# Self-hosted file sync and collaboration platform
#
# Provides CalDAV (calendar), CardDAV (contacts), file sync, and more.
# Uses PostgreSQL + Redis for performance. Nginx handles PHP-FPM locally.
#
# Access: via Caddy reverse proxy on the router (e.g., nextcloud.prestonperanich.com)
# Admin: log in with the admin credentials configured via adminPasswordFile option
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

        extraTrustedDomains = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          example = [ "192.168.0.161" ];
          description = "Additional trusted domains beyond hostName.";
        };

        trustedProxies = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          example = [ "10.0.0.1" ];
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

        adminPasswordFile = lib.mkOption {
          type = lib.types.path;
          description = "Path to file containing the Nextcloud admin password";
        };
      };

      config = {
        services.nextcloud = {
          enable = true;
          package = pkgs.nextcloud32;
          inherit (cfg) hostName;
          inherit (cfg) datadir;
          https = true;
          inherit (cfg) maxUploadSize;

          # Automatic PostgreSQL + Redis
          database.createLocally = true;
          configureRedis = true;

          config = {
            dbtype = "pgsql";
            adminuser = "admin";
            adminpassFile = cfg.adminPasswordFile;
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

        # Nginx listens on port 80 locally — Caddy on the router handles HTTPS
        services.nginx.virtualHosts.${cfg.hostName} = {
          listen = [
            {
              addr = "0.0.0.0";
              port = 80;
            }
          ];
        };
        networking.firewall.allowedTCPPorts = [ 80 ];

        # Ensure data directory exists with correct ownership
        systemd.tmpfiles.settings."10-nextcloud" = {
          ${cfg.datadir}."d" = {
            user = "nextcloud";
            group = "nextcloud";
            mode = "0750";
          };
        };

        # Automatic database backups
        services.postgresqlBackup = {
          enable = true;
          startAt = "*-*-* 02:00:00";
        };
      };
    };
}
