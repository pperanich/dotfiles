# Headplane web UI for the local Headscale, logged into with a Headscale API
# key. Loopback only; the reverse proxy fronts TLS and serves it under /admin.
_: {
  flake.modules.nixos.headplane =
    { config, lib, ... }:
    let
      cfg = config.my.headplane;
      headscale = config.services.headscale;
    in
    {
      options.my.headplane = {
        enable = lib.mkEnableOption "Headplane web UI for Headscale";

        domain = lib.mkOption {
          type = lib.types.str;
          example = "headplane.example.com";
          description = "Public FQDN the reverse proxy serves Headplane on.";
        };

        listenAddress = lib.mkOption {
          type = lib.types.str;
          default = "127.0.0.1";
          description = "Address Headplane binds to.";
        };

        port = lib.mkOption {
          type = lib.types.port;
          default = 3002;
          description = "Local port Headplane listens on.";
        };

        cookieSecretSecret = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "headplane-cookie-secret";
          description = "sops key holding the 32-character session cookie secret.";
        };
      };

      config = lib.mkIf cfg.enable {
        assertions = [
          {
            assertion = cfg.cookieSecretSecret != null;
            message = "my.headplane.cookieSecretSecret is unset; Headplane refuses to start without a cookie secret.";
          }
        ];

        sops.secrets = lib.mkIf (cfg.cookieSecretSecret != null) {
          ${cfg.cookieSecretSecret} = {
            # Upstream runs Headplane as the Headscale user.
            owner = headscale.user;
            mode = "0400";
            restartUnits = [ "headplane.service" ];
          };
        };

        services.headplane = {
          enable = true;
          settings = {
            server = {
              host = cfg.listenAddress;
              inherit (cfg) port;
              base_url = "https://${cfg.domain}";
              cookie_secret_path = lib.mkIf (
                cfg.cookieSecretSecret != null
              ) config.sops.secrets.${cfg.cookieSecretSecret}.path;
              cookie_secure = true;
            };
            # Headscale's read-only store config, so the UI shows settings but cannot change them.
            # As a string: the module's filterAttrsRecursive walks a derivation's stdenv otherwise.
            headscale = {
              config_path = "${headscale.configFile}";
              url = "http://${headscale.address}:${toString headscale.port}";
              public_url = headscale.settings.server_url;
            };
            # Nothing to reload with a read-only config, so don't let Headplane signal Headscale.
            integration.proc.enabled = false;
          };
        };
      };
    };
}
