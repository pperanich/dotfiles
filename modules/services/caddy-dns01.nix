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
    in
    {
      options.my.caddyDns01 = {
        enable = lib.mkEnableOption "Caddy with Cloudflare DNS-01 certificates";
      };

      config = lib.mkIf cfg.enable {
        # Zone:DNS:Edit + Zone:Zone:Read token (also used by cf-dns/cf-tunnel)
        sops.secrets.cloudflare-api-token = { };

        sops.templates."caddy.env" = {
          content = ''
            CLOUDFLARE_API_TOKEN=${config.sops.placeholder."cloudflare-api-token"}
          '';
          owner = "caddy";
        };

        services.caddy = {
          enable = true;

          package = pkgs.caddy.withPlugins {
            plugins = [ "github.com/caddy-dns/cloudflare@v0.2.2" ];
            hash = "sha256-7g8zDx5RhbptXFyEPtexxkHX8hw/gF001bZ7wX4Mjhs="; # Build once to get correct hash — nix prints it on failure (caddy 2.11.4 / nixos-26.05)
          };

          environmentFile = config.sops.templates."caddy.env".path;

          globalConfig = lib.mkBefore ''
            acme_dns cloudflare {env.CLOUDFLARE_API_TOKEN}
          '';
        };
      };
    };
}
