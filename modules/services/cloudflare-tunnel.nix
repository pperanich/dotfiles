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
          type = lib.types.path;
          description = "Path to environment file containing CLOUDFLARE_API_TOKEN";
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
        ];

        services.cloudflared = {
          enable = true;
          tunnels.${cfg.tunnelId} = {
            inherit (cfg) credentialsFile;
            inherit (cfg) ingress default;
          };
        };

        environment.systemPackages = [ config.services.cloudflared.package ];

        # Auto-sync tunnel CNAME records for ingress hostnames
        systemd.services.cf-tunnel-dns-sync = lib.mkIf (hostnames != [ ]) {
          description = "Sync Cloudflare Tunnel DNS records";
          after = [ "network-online.target" ];
          wants = [ "network-online.target" ];
          serviceConfig = {
            Type = "oneshot";
            EnvironmentFile = cfg.environmentFile;
            ExecStart = "${pkgs.cf}/bin/cf tunnel sync --name ${lib.escapeShellArg cfg.tunnelName} --zone ${lib.escapeShellArg cfg.zone} ${hostnameFlags} --apply";
            DynamicUser = true;
          };
        };

        systemd.timers.cf-tunnel-dns-sync = lib.mkIf (hostnames != [ ]) {
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
}
