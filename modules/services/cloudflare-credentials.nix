# Single owner of the Cloudflare API credentials shared by cf-dns, cf-tunnel,
# cf-access and Caddy's DNS-01 solver.
#
# The env var names live here and nowhere else: machines name the sops keys,
# consumers read my.cloudflare.envFile. Nothing outside this file spells
# CLOUDFLARE_API_TOKEN.
#
# Usage in machine config:
#   my.cloudflare = {
#     enable = true;
#     accountIdSecret = "cloudflare-account-id";  # only cf-access needs it
#   };
_: {
  flake.modules.nixos.cloudflareCredentials =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.my.cloudflare;
    in
    {
      options.my.cloudflare = {
        enable = lib.mkEnableOption "shared Cloudflare API credentials";

        apiTokenSecret = lib.mkOption {
          type = lib.types.str;
          default = "cloudflare-api-token";
          description = "sops key holding the Zone:DNS:Edit + Zone:Zone:Read API token.";
        };

        accountIdSecret = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = ''
            sops key holding the account ID. Only cf access needs it; leave null
            when just DNS, tunnel or Caddy consume these credentials.
          '';
        };

        restartUnits = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = ''
            Units restarted when the credentials change. Consumers append
            themselves, so a rotated token takes effect on the next activation
            instead of at the next reboot.
          '';
        };

        envFile = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          readOnly = true;
          default = if cfg.enable then config.sops.templates."cloudflare.env".path else null;
          defaultText = lib.literalMD "the generated env file, or `null` when disabled";
          description = "Read-only. Env file defining CLOUDFLARE_API_TOKEN (and CLOUDFLARE_ACCOUNT_ID when accountIdSecret is set).";
        };
      };

      config = lib.mkIf cfg.enable {
        sops.secrets = {
          ${cfg.apiTokenSecret} = { };
        }
        // lib.optionalAttrs (cfg.accountIdSecret != null) {
          ${cfg.accountIdSecret} = { };
        };

        # Root-owned 0400: EnvironmentFile is read by PID 1 before the unit
        # drops privileges, so no consumer needs to own it.
        sops.templates."cloudflare.env" = {
          content = ''
            CLOUDFLARE_API_TOKEN=${config.sops.placeholder.${cfg.apiTokenSecret}}
          ''
          + lib.optionalString (cfg.accountIdSecret != null) ''
            CLOUDFLARE_ACCOUNT_ID=${config.sops.placeholder.${cfg.accountIdSecret}}
          '';
          inherit (cfg) restartUnits;
        };
      };
    };
}
