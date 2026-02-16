_: {
  flake.modules.nixos.cloudflareTunnel =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.my.cloudflareTunnel;
    in
    {
      options.my.cloudflareTunnel = {
        enable = lib.mkEnableOption "Cloudflare Tunnel for public service exposure";

        tunnelId = lib.mkOption {
          type = lib.types.str;
          description = "Cloudflare tunnel UUID (from `cloudflared tunnel create`)";
          example = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx";
        };

        credentialsFile = lib.mkOption {
          type = lib.types.path;
          description = "Path to the cloudflared tunnel credentials JSON file";
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
      };
    };
}
