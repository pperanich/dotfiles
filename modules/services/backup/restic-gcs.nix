_: {
  flake.modules.nixos.backup =
    {
      config,
      lib,
      pkgs,
      utils,
      ...
    }:
    let
      cfg = config.my.backup;
      inherit (utils.systemdUtils.unitOptions) unitOption;
    in
    {
      options.my.backup.gcsWorm = {
        enable = lib.mkEnableOption "Restic offsite backup to a GCS bucket with Object Versioning + Soft Delete";

        repository = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "gs:pp-homelab-worm-backups:/";
          description = "GCS Restic repository URI (bucket protected by Object Versioning + 30d Soft Delete + IAM delete deny).";
        };

        passwordSecret = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "restic-gcs-worm-password";
          description = "sops secret key containing the Restic repository password.";
        };

        gcsCredentialsSecret = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "gcs-worm-sa-key";
          description = "sops secret key containing the GCP service account JSON credentials.";
        };

        paths = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Paths backed up to GCS WORM storage.";
        };

        exclude = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Exclude patterns for GCS WORM Restic backup.";
        };

        timerConfig = lib.mkOption {
          type = lib.types.attrsOf unitOption;
          default = {
            OnCalendar = "03:00";
            RandomizedDelaySec = "30m";
            Persistent = true;
          };
          description = "systemd timer configuration for GCS WORM Restic backup.";
        };

        enablePrune = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Whether to run `restic forget --prune` after backup. Bucket protection uses
            GCS Object Versioning + 30-day Soft Delete (rather than a bucket-wide Retention
            Policy, which blocks restic's 5-minute lock-file refresh DELETEs), so live object
            deletes move superseded packs to noncurrent/soft-deleted generations for 30 days.
          '';
        };

        pruneOpts = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [
            "--keep-daily 7"
            "--keep-weekly 4"
            "--keep-monthly 12"
          ];
          description = "Retention arguments passed to `restic forget --prune` when enablePrune is true.";
        };
      };

      config = lib.mkIf cfg.gcsWorm.enable {
        assertions = [
          {
            assertion = cfg.gcsWorm.repository != null;
            message = "my.backup.gcsWorm.repository is unset; specify the target GCS bucket URI (e.g. \"gs:pp-homelab-worm-backups:/\").";
          }
          {
            assertion = cfg.gcsWorm.passwordSecret != null;
            message = "my.backup.gcsWorm.passwordSecret is unset; refusing to configure Restic GCS backup without repository password.";
          }
          {
            assertion = cfg.gcsWorm.gcsCredentialsSecret != null;
            message = "my.backup.gcsWorm.gcsCredentialsSecret is unset; refusing to configure Restic GCS backup without service account credentials.";
          }
          {
            assertion = cfg.gcsWorm.paths != [ ];
            message = "my.backup.gcsWorm.paths is empty; specify at least one path to back up to GCS.";
          }
        ];

        sops.secrets =
          lib.optionalAttrs (cfg.gcsWorm.passwordSecret != null) {
            ${cfg.gcsWorm.passwordSecret} = {
              mode = "0400";
            };
          }
          // lib.optionalAttrs (cfg.gcsWorm.gcsCredentialsSecret != null) {
            ${cfg.gcsWorm.gcsCredentialsSecret} = {
              mode = "0400";
            };
          };

        services.restic.backups.gcs-worm = {
          inherit (cfg.gcsWorm)
            repository
            paths
            exclude
            timerConfig
            ;
          initialize = true;
          passwordFile = lib.mkIf (
            cfg.gcsWorm.passwordSecret != null
          ) config.sops.secrets.${cfg.gcsWorm.passwordSecret}.path;
          environmentFile = lib.mkIf (cfg.gcsWorm.gcsCredentialsSecret != null) (
            toString (
              pkgs.writeText "restic-gcs-worm.env" "GOOGLE_APPLICATION_CREDENTIALS=${
                config.sops.secrets.${cfg.gcsWorm.gcsCredentialsSecret}.path
              }\n"
            )
          );
          backupPrepareCommand = lib.mkIf (cfg.sqliteSnapshotCommand != "") cfg.sqliteSnapshotCommand;
          pruneOpts = lib.optionals cfg.gcsWorm.enablePrune cfg.gcsWorm.pruneOpts;
        };
      };
    };
}
