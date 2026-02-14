# Declarative Cloudflare DNS record management
#
# Generates a JSON config at build time and syncs it to Cloudflare
# via a systemd timer. Secrets injected at runtime via sops-nix.
#
# Usage in machine config:
#   services.cf-dns = {
#     enable = true;
#     zone = "example.com";
#     records = [
#       { type = "A"; name = "app.example.com"; content = "10.0.0.1"; }
#     ];
#   };
#
# Manual trigger: systemctl start cf-dns-sync
# View logs:      journalctl -u cf-dns-sync
_: {
  flake.modules.nixos.cfDns =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.services.cf-dns;

      cf-dns = pkgs.callPackage ../../pkgs/cf-dns { };

      configJson = pkgs.writeText "cf-dns-config.json" (
        builtins.toJSON {
          inherit (cfg) zone;
          inherit (cfg) records;
        }
      );
    in
    {
      options.services.cf-dns = {
        enable = lib.mkEnableOption "Declarative Cloudflare DNS sync";

        zone = lib.mkOption {
          type = lib.types.str;
          example = "example.com";
          description = "Cloudflare zone (domain) to manage records in.";
        };

        records = lib.mkOption {
          type = lib.types.listOf (
            lib.types.submodule {
              options = {
                type = lib.mkOption {
                  type = lib.types.enum [
                    "A"
                    "AAAA"
                    "CNAME"
                    "MX"
                    "TXT"
                    "SRV"
                  ];
                  description = "DNS record type.";
                };
                name = lib.mkOption {
                  type = lib.types.str;
                  description = "Fully qualified domain name.";
                };
                content = lib.mkOption {
                  type = lib.types.str;
                  description = "Record value (IP address, hostname, etc).";
                };
                proxied = lib.mkOption {
                  type = lib.types.bool;
                  default = false;
                  description = "Whether to proxy through Cloudflare.";
                };
                ttl = lib.mkOption {
                  type = lib.types.int;
                  default = 300;
                  description = "TTL in seconds.";
                };
              };
            }
          );
          default = [ ];
          description = ''
            DNS records to sync. Only records tagged `managed-by:cf-dns`
            are touched — other records (e.g. dyndns) are left alone.
          '';
        };

        interval = lib.mkOption {
          type = lib.types.str;
          default = "12h";
          description = "How often to sync DNS records (systemd timer interval).";
        };

        sopsSecretName = lib.mkOption {
          type = lib.types.str;
          default = "cloudflare-api-token";
          description = "Name of the sops secret containing the Cloudflare API token.";
        };
      };

      config = lib.mkIf cfg.enable {
        # Ensure the Cloudflare API token secret is declared
        sops.secrets.${cfg.sopsSecretName} = { };

        # Render env file with the API token at runtime
        sops.templates."cf-dns.env" = {
          content = ''
            CLOUDFLARE_API_TOKEN=${config.sops.placeholder.${cfg.sopsSecretName}}
          '';
        };

        systemd.services.cf-dns-sync = {
          description = "Sync Cloudflare DNS records";
          after = [ "network-online.target" ];
          wants = [ "network-online.target" ];
          serviceConfig = {
            Type = "oneshot";
            EnvironmentFile = config.sops.templates."cf-dns.env".path;
            ExecStart = "${cf-dns}/bin/cf-dns sync --config ${configJson} --apply";
            DynamicUser = true;
          };
        };

        systemd.timers.cf-dns-sync = {
          description = "Periodic Cloudflare DNS sync";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnBootSec = "5min";
            OnUnitActiveSec = cfg.interval;
            RandomizedDelaySec = "5min";
            Persistent = true;
          };
        };
      };
    };
}
