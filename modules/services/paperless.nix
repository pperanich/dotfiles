# Document management with OCR and full-text search.
#
# Watches a consumption directory for new files (e.g. scanner output),
# OCRs them, and files them into a searchable archive.
# Access: via Caddy reverse proxy on the router (paperless.prestonperanich.com)
_: {
  flake.modules.nixos.paperless =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.my.paperless;
    in
    {
      options.my.paperless = {
        port = lib.mkOption {
          type = lib.types.port;
          default = 28981;
          description = "Port for the paperless web server";
        };

        address = lib.mkOption {
          type = lib.types.str;
          default = "127.0.0.1";
          description = "Address for the paperless web server to listen on";
        };

        dataDir = lib.mkOption {
          type = lib.types.path;
          default = "/var/lib/paperless";
          description = "Directory for paperless data (database, archive, thumbnails)";
        };

        consumptionDir = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          description = "Directory watched for new documents to ingest";
        };

        domain = lib.mkOption {
          type = lib.types.str;
          example = "paperless.example.com";
          description = "Public domain paperless is served under (sets PAPERLESS_URL for CSRF)";
        };

        passwordFile = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          description = "File containing the initial admin password";
        };

        openFirewall = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Open the firewall for the paperless web server";
        };
      };

      config = {
        assertions = [
          {
            # Upstream silently skips superuser creation when this is null:
            # paperless comes up with no account to log in with.
            assertion = cfg.passwordFile != null;
            message = ''
              my.paperless.passwordFile is unset, so no superuser would be created
              and the web UI would be unreachable. Point it at a sops secret, e.g.
              `passwordFile = config.sops.secrets.paperless-admin-pass.path;`.
            '';
          }
        ];

        services.paperless = {
          enable = true;
          inherit (cfg)
            port
            address
            dataDir
            passwordFile
            ;
          consumptionDir = lib.mkIf (cfg.consumptionDir != null) cfg.consumptionDir;
          # Scanner writes as a different user; let the consumer pick files up anyway
          consumptionDirIsPublic = true;
          settings = {
            PAPERLESS_URL = "https://${cfg.domain}";
            PAPERLESS_OCR_LANGUAGE = "eng";
            PAPERLESS_CONSUMER_RECURSIVE = true;
            PAPERLESS_FILENAME_FORMAT = "{{ created_year }}/{{ correspondent }}/{{ title }}";
          };
        };

        networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];
      };
    };
}
