_: {
  flake.modules.nixos.backup =
    { config, lib, ... }:
    let
      cfg = config.my.backup;
    in
    {
      options.my.backup.borgServer = {
        enable = lib.mkEnableOption "append-only Borg repository server for one client";

        repoName = lib.mkOption {
          type = lib.types.str;
          example = "router";
          description = "Name of the Borg repository; the unit is borgbackup-repo-<repoName>.service.";
        };

        path = lib.mkOption {
          type = lib.types.path;
          example = "/tank/backups/borg/router";
          description = "Filesystem path storing the append-only Borg repository.";
        };

        authorizedKeys = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Client SSH public keys restricted to `borg serve --append-only`.";
        };
      };

      # No compaction timer: compaction is manual because it makes client deletes permanent.
      config = lib.mkIf cfg.borgServer.enable {
        assertions = [
          {
            assertion = cfg.borgServer.authorizedKeys != [ ];
            message = "my.backup.borgServer.authorizedKeys is empty; at least one client SSH public key is required.";
          }
        ];

        services.borgbackup.repos.${cfg.borgServer.repoName} = {
          inherit (cfg.borgServer) path;
          authorizedKeysAppendOnly = cfg.borgServer.authorizedKeys;
        };

        systemd.services."borgbackup-repo-${cfg.borgServer.repoName}".unitConfig.RequiresMountsFor = [
          cfg.borgServer.path
        ];
      };
    };
}
