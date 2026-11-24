# Caddy with Cloudflare DNS-01 ACME: shared plugin pin, API token env
# wiring, and acme_dns global config. Machines add their own vhosts and
# extra globalConfig lines.
_: {
  flake.modules.nixos.caddyDns01 =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.my.caddyDns01;
      mkEnvVar =
        key: "CADDY_SECRET_" + lib.toUpper (lib.replaceStrings [ "-" "/" "." ] [ "_" "_" "_" ] key);
    in
    {
      options.my.caddyDns01 = {
        enable = lib.mkEnableOption "Caddy with Cloudflare DNS-01 certificates";
        crowdsecBouncer = lib.mkEnableOption "CrowdSec HTTP bouncer plugin compiled into Caddy";

        secrets = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          example = [ "sunshine-basic-auth" ];
          description = "sops keys rendered into Caddy's EnvironmentFile; reference via placeholders.<key>.";
        };

        placeholders = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          readOnly = true;
          default = lib.genAttrs cfg.secrets (k: "{$" + mkEnvVar k + "}");
          description = "Read-only Caddy env-var placeholders for each key in my.caddyDns01.secrets.";
        };
      };

      config = lib.mkIf cfg.enable (
        lib.mkMerge [
          {
            assertions = [
              {
                assertion = config.my.cloudflare.envFile != null;
                message = ''
                  my.caddyDns01 needs Cloudflare API credentials for the DNS-01 solver.
                  Set `my.cloudflare.enable = true;` on this machine — it builds the env
                  file from the sops key named by my.cloudflare.apiTokenSecret.
                '';
              }
            ];

            my.cloudflare.restartUnits = [ "caddy.service" ];

            services.caddy = {
              enable = true;

              package = pkgs.caddy.withPlugins {
                # v0.2.4 is the first release that accepts Cloudflare's `cfut_` token format.
                plugins = [
                  "github.com/caddy-dns/cloudflare@v0.2.4"
                ]
                ++ lib.optional cfg.crowdsecBouncer "github.com/hslatman/caddy-crowdsec-bouncer@v0.15.0";
                # caddy 2.11.9; on a bump, set lib.fakeHash and build to get the new hashes
                hash =
                  if cfg.crowdsecBouncer then
                    "sha256-xxeXdWnwFkR9L2OZE16G9jSndUW3LumPBnGLSx/CNBI="
                  else
                    "sha256-QSiwKqKvSxhksWBF4/MlBOpyXba5xOQ2sRwA0R7399E=";
              };

              environmentFile = config.my.cloudflare.envFile;

              globalConfig = lib.mkBefore ''
                acme_dns cloudflare {env.CLOUDFLARE_API_TOKEN}
              '';
            };
          }
          (lib.mkIf (cfg.secrets != [ ]) {
            sops = {
              secrets = lib.genAttrs cfg.secrets (_: { });
              templates."caddy-secrets.env" = {
                content = lib.concatMapStringsSep "\n" (
                  k: "${mkEnvVar k}=${config.sops.placeholder.${k}}"
                ) cfg.secrets;
                restartUnits = [ "caddy.service" ];
              };
            };

            systemd.services.caddy.serviceConfig.EnvironmentFile = [
              config.sops.templates."caddy-secrets.env".path
            ];
          })
        ]
      );
    };
}
