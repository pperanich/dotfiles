_: {
  flake.modules.nixos.cloudflareTunnel =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.my.cloudflareTunnel;
      hostnames = builtins.attrNames cfg.ingress;
      hostnameFlags = lib.concatMapStringsSep " " (h: "--hostname ${lib.escapeShellArg h}") hostnames;
    in
    {
      options.my.cloudflareTunnel = {
        enable = lib.mkEnableOption "Cloudflare Tunnel for public service exposure";

        tunnelId = lib.mkOption {
          type = lib.types.str;
          description = "Cloudflare tunnel UUID (from `cloudflared tunnel create`)";
          example = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx";
        };

        tunnelName = lib.mkOption {
          type = lib.types.str;
          description = "Cloudflare tunnel name (must match the name used during `cf tunnel sync`)";
          example = "homelab";
        };

        zone = lib.mkOption {
          type = lib.types.str;
          description = "Cloudflare zone for tunnel CNAME records";
          example = "example.com";
        };

        credentialsFile = lib.mkOption {
          type = lib.types.path;
          description = "Path to the cloudflared tunnel credentials JSON file";
        };

        environmentFile = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = config.my.cloudflare.envFile;
          defaultText = lib.literalExpression "config.my.cloudflare.envFile";
          description = ''
            Env file defining CLOUDFLARE_API_TOKEN, used by the CNAME sync job.
            Defaults to the shared file built by my.cloudflare.
          '';
        };

        ingress = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = { };
          example = {
            "vault.example.com" = "http://localhost:8222";
          };
          description = "Hostname to backend origin mapping";
        };

        default = lib.mkOption {
          type = lib.types.str;
          default = "http_status:404";
          description = "Catch-all rule for unmatched requests (required by cloudflared)";
        };
      };

      config = lib.mkIf cfg.enable {
        assertions = [
          {
            assertion =
              builtins.match "[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}" cfg.tunnelId != null;
            message = "my.cloudflareTunnel.tunnelId must be a valid UUID, got: ${cfg.tunnelId}";
          }
          {
            assertion = cfg.tunnelId != "00000000-0000-0000-0000-000000000000";
            message = "my.cloudflareTunnel.tunnelId is still the nil-UUID placeholder. Run: cf tunnel sync --name <name> --apply";
          }
          {
            # Only the CNAME sync job reads it; the tunnel itself uses credentialsFile
            assertion = hostnames != [ ] -> cfg.environmentFile != null;
            message = ''
              my.cloudflareTunnel syncs CNAMEs for its ingress hostnames and needs a
              Cloudflare API token for that. Set `my.cloudflare.enable = true;` on this
              machine, or point my.cloudflareTunnel.environmentFile at your own file.
            '';
          }
        ];

        my.cloudflare.restartUnits = lib.optional (hostnames != [ ]) "cf-tunnel-dns-sync.service";

        services.cloudflared = {
          enable = true;
          tunnels.${cfg.tunnelId} = {
            inherit (cfg) credentialsFile;
            inherit (cfg) ingress default;
          };
        };

        environment.systemPackages = [ config.services.cloudflared.package ];

        # Tunnel resolves Cloudflare edge via local DNS on boot. If cloudflared
        # starts before Blocky binds :53, the SRV lookup fails and systemd's
        # default burst limit (5 restarts / 10s) marks it permanently failed.
        # Wait for Blocky and disable the burst cap so it keeps retrying.
        systemd = {
          services = {
            "cloudflared-tunnel-${cfg.tunnelId}" = {
              after = [ "blocky.service" ];
              wants = [ "blocky.service" ];
              unitConfig.StartLimitIntervalSec = 0;
              serviceConfig.RestartSec = "10s";
            };

            # Auto-sync tunnel CNAME records for ingress hostnames
            cf-tunnel-dns-sync = lib.mkIf (hostnames != [ ]) {
              description = "Sync Cloudflare Tunnel DNS records";
              after = [ "network-online.target" ];
              wants = [ "network-online.target" ];
              serviceConfig = {
                Type = "oneshot";
                EnvironmentFile = cfg.environmentFile;
                ExecStart = "${pkgs.cf}/bin/cf tunnel sync-dns --tunnel-id ${lib.escapeShellArg cfg.tunnelId} --zone ${lib.escapeShellArg cfg.zone} ${hostnameFlags} --apply";
                DynamicUser = true;
              };
            };
          };

          timers.cf-tunnel-dns-sync = lib.mkIf (hostnames != [ ]) {
            description = "Periodic Cloudflare Tunnel DNS sync";
            wantedBy = [ "timers.target" ];
            timerConfig = {
              OnBootSec = "5min";
              OnUnitActiveSec = "12h";
              RandomizedDelaySec = "5min";
              Persistent = true;
            };
          };
        };
      };
    };
}
