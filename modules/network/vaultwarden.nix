_: {
  # NixOS system-level Vaultwarden configuration
  flake.modules.nixos.vaultwarden =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.features.vaultwarden;
    in
    {
      options.features.vaultwarden = {
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
      };

      config = {
        # Vaultwarden service configuration
        services.vaultwarden = {
          enable = true;
          config = {
            ROCKET_ADDRESS = cfg.address;
            ROCKET_PORT = cfg.port;
            DOMAIN = lib.mkIf (cfg.domain != null) "https://${cfg.domain}";
            WEB_VAULT_ENABLED = true;
            SIGNUPS_ALLOWED = false;
          };
          environmentFile = "/run/secrets/vaultwarden-env";
        };

        # Secret management
        sops.secrets.vaultwarden-env = {
          mode = "0400";
          owner = "vaultwarden";
          group = "vaultwarden";
        };

        # Open firewall port if not binding to localhost
        networking.firewall.allowedTCPPorts = lib.mkIf (cfg.address != "127.0.0.1") [
          cfg.port
        ];
      };
    };

  # Home Manager client tools
  flake.modules.homeManager.vaultwarden =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        # Bitwarden CLI for command-line access
        bitwarden-cli

        # Browser integration (if needed)
        # Note: Browser extensions are typically installed separately
      ];
    };
}
