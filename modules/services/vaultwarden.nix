_: {
  flake.modules.nixos.vaultwarden =
    {
      config,
      lib,
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
          }
          // lib.optionalAttrs (cfg.domain != null) {
            DOMAIN = "https://${cfg.domain}";
          };
        };

        systemd.services.vaultwarden.serviceConfig.EnvironmentFile = cfg.environmentFiles;

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
