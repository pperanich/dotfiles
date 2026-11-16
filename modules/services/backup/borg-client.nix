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
    in
    {
      options.my.backup.borgClient = {
        enable = lib.mkEnableOption "append-only Borg client that pushes this host's data to a Borg server";

        repo = lib.mkOption {
          type = lib.types.str;
          example = "ssh://borg@nas.home.arpa/tank/backups/borg/router";
          description = "Remote Borg repository URL.";
        };

        jobName = lib.mkOption {
          type = lib.types.str;
          default = "remote";
          description = "Name of the Borg job; the unit is borgbackup-job-<jobName>.service.";
        };

        passphraseSecret = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "borg-router-passphrase";
          description = "sops secret key containing the Borg repository passphrase.";
        };

        sshKeySecret = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "borg-router-ssh-key";
          description = "sops secret key containing the dedicated SSH private key for append-only Borg access.";
        };

        serverHostKey = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "nas.home.arpa ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA...";
          description = ''
            Optional known_hosts line pinning the Borg server's SSH host public key for BORG_RSH.
            When null, ssh verifies against system-wide `/etc/ssh/ssh_known_hosts` with
            `StrictHostKeyChecking=yes`.
          '';
        };

        paths = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Paths to include in the nightly Borg archive.";
        };

        exclude = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Exclude patterns, typically live SQLite files covered by the snapshots in sqliteBackupDir.";
        };

        startAt = lib.mkOption {
          type = lib.types.str;
          default = "*-*-* 02:00:00";
          description = "systemd calendar schedule for the Borg job.";
        };

        metricsDir = lib.mkOption {
          type = lib.types.path;
          default = "/var/lib/prometheus-node-exporter-text";
          description = "Node-exporter textfile collector directory for borg_last_success_timestamp_seconds.";
        };
      };

      config = lib.mkIf cfg.borgClient.enable {
        assertions = [
          {
            assertion = cfg.borgClient.passphraseSecret != null;
            message = "my.backup.borgClient.passphraseSecret is unset; refusing to configure Borg without encryption passphrase.";
          }
          {
            assertion = cfg.borgClient.sshKeySecret != null;
            message = "my.backup.borgClient.sshKeySecret is unset; refusing to configure Borg without dedicated SSH key.";
          }
          {
            assertion = cfg.borgClient.paths != [ ];
            message = "my.backup.borgClient.paths is empty; specify at least one path to back up.";
          }
        ];

        sops.secrets =
          lib.optionalAttrs (cfg.borgClient.passphraseSecret != null) {
            ${cfg.borgClient.passphraseSecret} = {
              mode = "0400";
            };
          }
          // lib.optionalAttrs (cfg.borgClient.sshKeySecret != null) {
            ${cfg.borgClient.sshKeySecret} = {
              mode = "0400";
            };
          };

        # Only emit the textfile dir rule if neither observability nor nodeMetrics already declares it
        systemd.tmpfiles.rules =
          lib.optionals
            (!(config.my.observability.enable or false) && !(config.my.nodeMetrics.enable or false))
            [
              "d ${cfg.borgClient.metricsDir} 0755 root root -"
            ];

        services.borgbackup.jobs.${cfg.borgClient.jobName} = {
          inherit (cfg.borgClient)
            repo
            paths
            exclude
            startAt
            ;
          persistentTimer = true;
          encryption = {
            mode = "repokey-blake2";
            passCommand =
              lib.mkIf (cfg.borgClient.passphraseSecret != null)
                "cat ${config.sops.secrets.${cfg.borgClient.passphraseSecret}.path}";
          };
          environment = lib.optionalAttrs (cfg.borgClient.sshKeySecret != null) (
            let
              knownHostsArg =
                lib.optionalString (cfg.borgClient.serverHostKey != null)
                  " -o UserKnownHostsFile=${pkgs.writeText "borg-server-known-hosts" "${cfg.borgClient.serverHostKey}\n"}";
            in
            {
              BORG_RSH = "ssh -i ${
                config.sops.secrets.${cfg.borgClient.sshKeySecret}.path
              } -o BatchMode=yes -o StrictHostKeyChecking=yes${knownHostsArg}";
            }
          );
          compression = "auto,zstd";
          prune.keep = {
            daily = 7;
            weekly = 4;
            monthly = 6;
          };
          readWritePaths = [ cfg.borgClient.metricsDir ];
          preHook = cfg.sqliteSnapshotCommand;
          postHook = ''
            if [ "$exitStatus" = "0" ]; then
              dir=${lib.escapeShellArg cfg.borgClient.metricsDir}
              printf 'borg_last_success_timestamp_seconds %s\n' "$(date +%s)" > "$dir/borgbackup.prom.tmp"
              mv "$dir/borgbackup.prom.tmp" "$dir/borgbackup.prom"
            fi
          '';
        };

        # The job runs under ProtectSystem=strict; snapshots need the output dir and each DB's -wal/-shm.
        # The `-` prefix lets the unit start when a directory does not exist.
        systemd.services."borgbackup-job-${cfg.borgClient.jobName}".serviceConfig.ReadWritePaths = [
          "-${cfg.sqliteBackupDir}"
        ]
        ++ map (p: "-${builtins.dirOf p}") (lib.unique (lib.attrValues cfg.sqliteDatabases));
      };
    };
}
