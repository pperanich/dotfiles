# Periodic renewal for LG webOS Developer Mode sessions.
# Exits non-zero on failure or low remaining hours so systemd failure alerts fire.
_: {
  flake.modules.nixos.webosDevmodeRenew =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.my.webosDevmodeRenew;
    in
    {
      options.my.webosDevmodeRenew = {
        enable = lib.mkEnableOption "periodic LG webOS Developer Mode session renewal";

        sessionTokenSecret = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "webos-devmode-token";
          description = "sops key holding the TV's /var/luna/preferences/devmode_enabled token.";
        };

        interval = lib.mkOption {
          type = lib.types.str;
          default = "weekly";
          description = "systemd OnCalendar schedule for renewing the session.";
        };

        minHours = lib.mkOption {
          type = lib.types.ints.unsigned;
          default = 100;
          description = "Fail the unit when remaining session hours drop below this threshold.";
        };
      };

      config = lib.mkIf cfg.enable {
        assertions = [
          {
            assertion = cfg.sessionTokenSecret != null;
            message = "my.webosDevmodeRenew.sessionTokenSecret is unset; cannot renew without a session token.";
          }
        ];

        # Oneshot timer reads the credential fresh on each run; no daemon restart needed.
        sops.secrets = lib.mkIf (cfg.sessionTokenSecret != null) {
          ${cfg.sessionTokenSecret}.mode = "0400";
        };

        systemd.services.webos-devmode-renew = {
          description = "Renew LG webOS Developer Mode session";
          after = [ "network-online.target" ];
          wants = [ "network-online.target" ];
          serviceConfig = {
            Type = "oneshot";
            DynamicUser = true;
            LoadCredential =
              lib.mkIf (cfg.sessionTokenSecret != null)
                "session-token:${config.sops.secrets.${cfg.sessionTokenSecret}.path}";
            ExecStart = "${pkgs.webos-devmode-renew}/bin/webos-devmode-renew --min-hours ${toString cfg.minHours}";
            NoNewPrivileges = true;
            PrivateTmp = true;
            ProtectSystem = "strict";
            ProtectHome = true;
            ProtectKernelTunables = true;
            ProtectKernelModules = true;
            ProtectControlGroups = true;
            RestrictAddressFamilies = [
              "AF_INET"
              "AF_INET6"
            ];
          };
        };

        systemd.timers.webos-devmode-renew = {
          description = "Periodic LG webOS Developer Mode session renewal";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnCalendar = cfg.interval;
            RandomizedDelaySec = "1h";
            Persistent = true;
          };
        };
      };
    };
}
