# Declarative Cloudflare Access application management
#
# Reconciles self-hosted Access applications (each gated by an email allowlist)
# from a JSON config via a systemd timer, mirroring cloudflareDns. Only apps
# whose name starts with `cf-access:` are touched — apps configured by hand are
# left alone. (A name prefix rather than a tag: Access tags must be pre-created
# before assignment, which the reconciler can't assume.)
#
# The config is passed as a path (see configFile), typically a sops-rendered
# file so the allowlist emails never enter git or the world-readable nix store.
# It is handed to the unit via systemd LoadCredential so the DynamicUser can
# read it while the source stays root-only.
#
# The API token in environmentFile must additionally hold
# Account -> Access: Apps and Policies -> Edit (beyond the DNS scope).
#
# Manual trigger: systemctl start cf-access-sync
# View logs:      journalctl -u cf-access-sync
_: {
  flake.modules.nixos.cloudflareAccess =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.my.cloudflareAccess;
    in
    {
      options.my.cloudflareAccess = {
        enable = lib.mkEnableOption "Declarative Cloudflare Access sync";

        configFile = lib.mkOption {
          type = lib.types.path;
          description = ''
            Path to the sync config JSON `{ "apps": [ ... ] }`. Usually a
            sops-rendered file so allowlist emails stay out of git and the nix
            store. Loaded via LoadCredential so the DynamicUser unit can read it.
          '';
        };

        interval = lib.mkOption {
          type = lib.types.str;
          default = "12h";
          description = "How often to reconcile Access apps (systemd timer interval).";
        };

        environmentFile = lib.mkOption {
          type = lib.types.path;
          description = "Env file with CLOUDFLARE_API_TOKEN and CLOUDFLARE_ACCOUNT_ID.";
        };
      };

      config = lib.mkIf cfg.enable {
        systemd.services.cf-access-sync = {
          description = "Sync Cloudflare Access applications";
          wantedBy = [ "multi-user.target" ];
          after = [ "network-online.target" ];
          wants = [ "network-online.target" ];
          serviceConfig = {
            Type = "oneshot";
            EnvironmentFile = cfg.environmentFile;
            # systemd (root) copies the secret into $CREDENTIALS_DIRECTORY (%d),
            # readable by the DynamicUser without exposing the source file.
            LoadCredential = [ "config:${cfg.configFile}" ];
            ExecStart = "${pkgs.cf}/bin/cf access sync --config %d/config --prune --apply";
            DynamicUser = true;
          };
        };

        systemd.timers.cf-access-sync = {
          description = "Periodic Cloudflare Access sync";
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
