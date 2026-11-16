_: {
  flake.modules.nixos.backup =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.my.backup;
      gdrive = cfg.googleDrive;
      zfs = gdrive.zfsSnapshot;
      unit = "restic-backups-gdrive";
      snapshotUnit = "restic-gdrive-zfs-snapshot";
      snapshotName = "restic-gdrive";
      snapshotRoot = "/run/${snapshotUnit}";
      rcloneServeArgs = "serve restic --stdio --tpslimit ${toString gdrive.tpsLimit} --tpslimit-burst ${toString gdrive.tpsLimit} --drive-chunk-size 128M";

      # Shortest mountpoint first, so the last match for a path is its deepest dataset.
      snapshotMounts = lib.sort (a: b: lib.stringLength a.mountpoint < lib.stringLength b.mountpoint) (
        lib.mapAttrsToList (dataset: mountpoint: { inherit dataset mountpoint; }) zfs.datasets
      );
      underMountpoint = path: mp: path == mp || lib.hasPrefix (if mp == "/" then "/" else "${mp}/") path;
      # Each snapshot mounts in its own flat directory ("+" cannot appear in a ZFS name). Nesting them
      # fails whenever a parent holds files under a child's mountpoint.
      snapshotDir = m: "${snapshotRoot}/${lib.replaceStrings [ "/" ] [ "+" ] m.dataset}";
      # Children before parents; also clears mounts left by an earlier layout or a failed start.
      unmountSnapshots = ''
        for target in $(findmnt -rn -o TARGET | grep -F '${snapshotRoot}/' | sort -r); do
          umount -l "$target" || true
        done
      '';
      relativeTo = mp: path: if mp == "/" then path else lib.removePrefix mp path;
      snapshottedPaths = lib.filter (
        path: lib.any (m: underMountpoint path m.mountpoint) snapshotMounts
      ) gdrive.paths;
      # systemd applies binds parent-first, so child datasets land on top of their parent's snapshot.
      snapshotBinds = lib.unique (
        map (
          path:
          let
            m = lib.last (lib.filter (m: underMountpoint path m.mountpoint) snapshotMounts);
          in
          "-${snapshotDir m}${relativeTo m.mountpoint path}:${path}"
        ) snapshottedPaths
        ++ map (m: "-${snapshotDir m}:${m.mountpoint}") (
          lib.filter (
            m: lib.any (path: m.mountpoint != path && underMountpoint m.mountpoint path) gdrive.paths
          ) snapshotMounts
        )
      );

      # A ZFS filesystem inside a backed-up path but not snapshotted would show up as an empty directory.
      unsnapshottedMounts = lib.filter (
        fs:
        fs.fsType == "zfs"
        && lib.any (path: underMountpoint fs.mountPoint path) gdrive.paths
        && (zfs.datasets.${fs.device} or null) != fs.mountPoint
      ) (lib.attrValues config.fileSystems);

      pingCommand =
        suffix:
        lib.optionalString (gdrive.healthchecksPingUrlSecret != null) ''
          ${pkgs.curl}/bin/curl -fsS -m 10 --retry 3 -o /dev/null \
            "$(cat ${config.sops.secrets.${gdrive.healthchecksPingUrlSecret}.path})${suffix}" || true
        '';

      freshnessCommand = lib.concatMapStrings (check: ''
        newest=$(${pkgs.findutils}/bin/find ${lib.escapeShellArg check.path} -type f -name ${lib.escapeShellArg check.name} \
          -size +${toString (check.minBytes - 1)}c -printf '%T@\n' | sort -n | tail -n 1)
        if [ -z "$newest" ] || [ "''${newest%.*}" -lt "$(( $(date +%s) - ${
          toString (check.maxAgeHours * 3600)
        } ))" ]; then
          echo "refusing to back up: no ${check.name} under ${check.path} newer than ${toString check.maxAgeHours}h" >&2
          exit 1
        fi
      '') gdrive.freshnessChecks;

      prepareCommand = lib.concatStrings [
        ''
          #!${pkgs.runtimeShell}
          set -euo pipefail
        ''
        (pingCommand "/start")
        freshnessCommand
        cfg.sqliteSnapshotCommand
      ];

      metricsCommand = lib.optionalString (gdrive.metricsDir != null) ''
        dir=${lib.escapeShellArg gdrive.metricsDir}
        if [ "$SERVICE_RESULT" = success ] && [ -d "$dir" ]; then
          if count=$(${pkgs.restic}/bin/restic -o 'rclone.args=${rcloneServeArgs}' snapshots --no-lock --json | ${pkgs.jq}/bin/jq -e length) \
            && [ -n "$count" ]; then
            printf 'restic_last_success_timestamp_seconds{repo="gdrive"} %s\nrestic_snapshots_total{repo="gdrive"} %s\n' \
              "$(date +%s)" "$count" > "$dir/restic-gdrive.prom.tmp"
            mv "$dir/restic-gdrive.prom.tmp" "$dir/restic-gdrive.prom"
          else
            echo "backup succeeded but the snapshot count could not be read; success metric not updated" >&2
          fi
        fi
      '';

      # No `set -e`: the Healthchecks ping below must run even when the metric step fails.
      cleanupCommand = lib.concatStrings [
        ''
          #!${pkgs.runtimeShell}
          set -uo pipefail
        ''
        metricsCommand
        (lib.optionalString (gdrive.healthchecksPingUrlSecret != null) ''
          if [ "$SERVICE_RESULT" = success ]; then
            ${pingCommand ""}
          else
            ${pingCommand "/fail"}
          fi
        '')
      ];
    in
    {
      options.my.backup.googleDrive = {
        enable = lib.mkEnableOption "Restic offsite backup to Google Drive via rclone";

        remoteName = lib.mkOption {
          type = lib.types.str;
          default = "gdrive";
          description = "rclone remote name configured inside rcloneConfigSecret.";
        };

        remotePath = lib.mkOption {
          type = lib.types.str;
          default = "restic-backups/${config.networking.hostName}";
          defaultText = lib.literalExpression ''"restic-backups/''${config.networking.hostName}"'';
          description = "Folder path inside the Google Drive remote for this machine's Restic repository.";
        };

        initialize = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Create the repository if `restic cat config` fails. Leave off once the repository exists:
            a run that cannot see it (wrong OAuth client, a renamed folder) would otherwise start a
            new empty repository and keep succeeding. Initialise by hand instead (docs/backups.md).
          '';
        };

        passwordSecret = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "restic-gdrive-password";
          description = "sops secret key containing the Restic repository password.";
        };

        rcloneConfigSecret = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "rclone-gdrive-conf";
          description = "sops secret key containing a per-machine `drive.file`-scoped OAuth rclone.conf.";
        };

        healthchecksPingUrlSecret = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "healthchecks-gdrive-ping-url";
          description = "Optional sops secret key holding a Healthchecks.io ping URL; each run pings /start, then success or /fail.";
        };

        paths = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Filesystem paths to back up to Google Drive.";
        };

        exclude = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [
            ".git/objects/pack/*.idx.tmp"
            "node_modules"
            "target"
            ".direnv"
            ".cache"
            "Library/Caches"
            ".colima"
            ".orbstack"
            ".Trash"
            "/nix"
          ];
          description = "Patterns excluded from Google Drive Restic backups.";
        };

        zfsSnapshot.datasets = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = { };
          example = {
            "rpool/tank" = "/tank";
            "rpool/var" = "/var";
          };
          description = ''
            ZFS datasets (name to mountpoint) to snapshot atomically before each run. Backup paths
            under these mountpoints are read from the snapshot, bound read-only over their live path,
            so every file is captured at the same instant. The snapshot is destroyed after the run.
          '';
        };

        freshnessChecks = lib.mkOption {
          type = lib.types.listOf (
            lib.types.submodule {
              options = {
                path = lib.mkOption {
                  type = lib.types.str;
                  description = "Directory searched for the file.";
                };
                name = lib.mkOption {
                  type = lib.types.str;
                  default = "*";
                  description = "find -name glob the file must match; name the finished output so a half-written temp file never counts.";
                };
                minBytes = lib.mkOption {
                  type = lib.types.ints.positive;
                  default = 1;
                  description = "Smallest size that counts, so an empty file left by a failed job does not pass.";
                };
                maxAgeHours = lib.mkOption {
                  type = lib.types.ints.positive;
                  description = "Fail the run when the newest matching file is older than this.";
                };
              };
            }
          );
          default = [ ];
          example = [
            {
              path = "/tank/backups/postgres";
              name = "all.sql.*";
              maxAgeHours = 26;
            }
          ];
          description = "Inputs produced by other jobs (database dumps) that must be fresh, or the run fails instead of uploading stale data.";
        };

        checkReadDataSubset = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = "2%";
          description = "After each backup, run `restic check --read-data-subset=<this>`; null skips the check.";
        };

        metricsDir = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = "/var/lib/prometheus-node-exporter-text";
          description = ''
            Node-exporter textfile directory for restic_backup_configured, restic_last_success_timestamp_seconds
            and restic_snapshots_total. Null on hosts without a node exporter; use healthchecksPingUrlSecret there.
          '';
        };

        packSizeMiB = lib.mkOption {
          type = lib.types.ints.positive;
          default = 128;
          description = "Restic target pack size in MiB (128 MiB avoids Google Drive's ~2 files/sec creation limit).";
        };

        tpsLimit = lib.mkOption {
          type = lib.types.ints.positive;
          default = 8;
          description = "rclone transactions-per-second limit against the Google Drive API.";
        };

        pruneOpts = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [
            "--keep-daily 7"
            "--keep-weekly 4"
            "--keep-monthly 12"
          ];
          description = "Retention arguments passed to `restic forget --prune`.";
        };

        startHour = lib.mkOption {
          type = lib.types.ints.between 0 23;
          default = 4;
          description = "Local hour of day (0-23) when the daily Google Drive backup triggers.";
        };
      };

      config = lib.mkIf gdrive.enable {
        assertions = [
          {
            assertion = gdrive.passwordSecret != null;
            message = "my.backup.googleDrive.passwordSecret is unset; refusing to configure Google Drive Restic backup without password.";
          }
          {
            assertion = gdrive.rcloneConfigSecret != null;
            message = "my.backup.googleDrive.rcloneConfigSecret is unset; refusing to configure Google Drive Restic backup without rclone config.";
          }
          {
            assertion = gdrive.paths != [ ];
            message = "my.backup.googleDrive.paths is empty; specify at least one path to back up to Google Drive.";
          }
          {
            assertion = zfs.datasets == { } || config.boot.zfs.enabled;
            message = "my.backup.googleDrive.zfsSnapshot.datasets is set on a host without ZFS.";
          }
          {
            assertion = zfs.datasets == { } || unsnapshottedMounts == [ ];
            message = "my.backup.googleDrive.zfsSnapshot.datasets must list every ZFS filesystem inside a backed-up path, or it is backed up empty. Missing: ${
              lib.concatMapStringsSep ", " (fs: "${fs.device} at ${fs.mountPoint}") unsnapshottedMounts
            }";
          }
        ];

        # Marks the host as expected to back up, so a run that never succeeds still alerts.
        systemd.tmpfiles.rules =
          lib.optional (gdrive.metricsDir != null)
            ''f+ ${gdrive.metricsDir}/restic-gdrive-configured.prom 0644 root root - restic_backup_configured{repo="gdrive"} 1\n'';

        sops.secrets =
          lib.optionalAttrs (gdrive.passwordSecret != null) {
            ${gdrive.passwordSecret} = {
              mode = "0400";
            };
          }
          // lib.optionalAttrs (gdrive.rcloneConfigSecret != null) {
            ${gdrive.rcloneConfigSecret} = {
              mode = "0400";
            };
          }
          // lib.optionalAttrs (gdrive.healthchecksPingUrlSecret != null) {
            ${gdrive.healthchecksPingUrlSecret} = {
              mode = "0400";
            };
          };

        systemd.services = {
          ${unit} = {
            path = [ pkgs.rclone ];
            requires = lib.optional (zfs.datasets != { }) "${snapshotUnit}.service";
            after = lib.optional (zfs.datasets != { }) "${snapshotUnit}.service";
            serviceConfig = {
              # The post-run snapshot count and Healthchecks ping talk to remote services.
              TimeoutStopSec = "10min";
              BindReadOnlyPaths = snapshotBinds;
              # Deeper paths mount last, so these stay live and writable inside a snapshot bind.
              BindPaths = lib.optionals (snapshotBinds != [ ]) (
                lib.optional (gdrive.metricsDir != null) "-${gdrive.metricsDir}" ++ [ "-${cfg.sqliteBackupDir}" ]
              );
            };
          };

          # Snapshots stay mounted for as long as the backup unit runs, then StopWhenUnneeded tears them down.
          ${snapshotUnit} = lib.mkIf (zfs.datasets != { }) {
            description = "ZFS snapshots for the Google Drive Restic backup";
            path = [
              config.boot.zfs.package
              pkgs.util-linux
            ];
            unitConfig.StopWhenUnneeded = true;
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
            };
            # --one-file-system keeps rm out of any snapshot that failed to unmount.
            script = ''
              ${unmountSnapshots}
              rm -rf --one-file-system ${snapshotRoot}
              ${lib.concatMapStrings (m: ''
                zfs destroy ${m.dataset}@${snapshotName} 2>/dev/null || true
              '') snapshotMounts}
              zfs snapshot ${lib.concatMapStringsSep " " (m: "${m.dataset}@${snapshotName}") snapshotMounts}
              ${lib.concatMapStrings (m: ''
                mkdir -p ${snapshotDir m}
                mount -t zfs -o ro ${m.dataset}@${snapshotName} ${snapshotDir m}
              '') snapshotMounts}
            '';
            preStop = ''
              ${unmountSnapshots}
              ${lib.concatMapStrings (m: ''
                zfs destroy ${m.dataset}@${snapshotName} || true
              '') snapshotMounts}
              rm -rf --one-file-system ${snapshotRoot}
            '';
          };
        };

        services.restic.backups.gdrive = {
          repository = "rclone:${gdrive.remoteName}:${gdrive.remotePath}";
          rcloneConfigFile = lib.mkIf (
            gdrive.rcloneConfigSecret != null
          ) config.sops.secrets.${gdrive.rcloneConfigSecret}.path;
          passwordFile = lib.mkIf (
            gdrive.passwordSecret != null
          ) config.sops.secrets.${gdrive.passwordSecret}.path;
          inherit (gdrive) initialize paths pruneOpts;
          runCheck = gdrive.checkReadDataSubset != null;
          checkOpts = lib.optional (
            gdrive.checkReadDataSubset != null
          ) "--read-data-subset=${gdrive.checkReadDataSubset}";
          extraBackupArgs = [
            "--pack-size=${toString gdrive.packSizeMiB}"
            "--exclude-caches"
          ]
          ++ map (e: lib.escapeShellArg "--exclude=${e}") gdrive.exclude;
          extraOptions = [
            "'rclone.args=${rcloneServeArgs}'"
          ];
          backupPrepareCommand = lib.mkIf (prepareCommand != "") prepareCommand;
          backupCleanupCommand = cleanupCommand;
          timerConfig = {
            OnCalendar = "*-*-* ${lib.fixedWidthNumber 2 gdrive.startHour}:00:00";
            RandomizedDelaySec = "45m";
            Persistent = true;
          };
        };
      };
    };
}
