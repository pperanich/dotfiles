_: {
  flake.modules.nixos.vaultwarden =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.my.vaultwarden;
    in
    {
      options.my.vaultwarden = {
        enable = lib.mkEnableOption "Vaultwarden password manager";
        port = lib.mkOption {
          type = lib.types.port;
          default = 8222;
          description = "Port for Vaultwarden to listen on";
        };
        address = lib.mkOption {
          type = lib.types.str;
          default = "127.0.0.1";
          description = "Address for Vaultwarden to bind to";
        };
        domain = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "vault.example.com";
          description = "Domain name for Vaultwarden";
        };
        ipHeader = lib.mkOption {
          type = lib.types.str;
          default = "X-Forwarded-For";
          description = "Header containing the real client IP (set by reverse proxy)";
        };
        environmentFiles = lib.mkOption {
          type = lib.types.listOf lib.types.path;
          default = [ ];
          description = "Environment files passed to the Vaultwarden systemd service (e.g. SMTP config, admin token)";
        };
        adminTokenFile = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          description = "Path to a file containing the plaintext admin token. Will be Argon2id-hashed at service start.";
        };
        smtpFrom = lib.mkOption {
          type = lib.types.str;
          example = "vaultwarden@example.com";
          description = "Email address used as the sender for Vaultwarden emails";
        };
        smtpFromName = lib.mkOption {
          type = lib.types.str;
          default = "Vaultwarden";
          description = "Display name for the sender";
        };
      };

      config = lib.mkIf cfg.enable {
        services.vaultwarden = {
          enable = true;
          config = {
            ROCKET_ADDRESS = cfg.address;
            ROCKET_PORT = cfg.port;
            WEB_VAULT_ENABLED = true;
            SIGNUPS_ALLOWED = false;
            INVITATIONS_ALLOWED = false;
            SHOW_PASSWORD_HINT = false;
            IP_HEADER = cfg.ipHeader;
            LOGIN_RATELIMIT_SECONDS = 60;
            LOGIN_RATELIMIT_MAX_BURST = 5;
            SMTP_HOST = "127.0.0.1";
            SMTP_PORT = 25;
            SMTP_SECURITY = "off";
            SMTP_FROM = cfg.smtpFrom;
            SMTP_FROM_NAME = cfg.smtpFromName;
          }
          // lib.optionalAttrs (cfg.domain != null) {
            DOMAIN = "https://${cfg.domain}";
          };
        };

        systemd.services.vaultwarden.serviceConfig.EnvironmentFile =
          cfg.environmentFiles
          ++ lib.optional (cfg.adminTokenFile != null) "/run/vaultwarden-admin-token.env";

        systemd.services.vaultwarden-admin-hash = lib.mkIf (cfg.adminTokenFile != null) {
          description = "Hash Vaultwarden admin token with Argon2id";
          requiredBy = [ "vaultwarden.service" ];
          before = [ "vaultwarden.service" ];
          serviceConfig.Type = "oneshot";
          path = [
            pkgs.libargon2
            pkgs.openssl
          ];
          script = ''
            TOKEN=$(<"${cfg.adminTokenFile}")
            SALT=$(openssl rand -base64 32)
            HASH=$(echo -n "$TOKEN" | argon2 "$SALT" -e -id -k 65540 -t 3 -p 4)
            printf 'ADMIN_TOKEN=%s\n' "$HASH" > /run/vaultwarden-admin-token.env
            chown vaultwarden:vaultwarden /run/vaultwarden-admin-token.env
            chmod 400 /run/vaultwarden-admin-token.env
          '';
        };

        networking.firewall.allowedTCPPorts =
          lib.mkIf
            (
              !builtins.elem cfg.address [
                "127.0.0.1"
                "::1"
              ]
            )
            [
              cfg.port
            ];
      };
    };

  flake.modules.homeManager.vaultwarden =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        bitwarden-cli
      ];
    };
}
