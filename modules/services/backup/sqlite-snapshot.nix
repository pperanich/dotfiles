# Backup tiers: borg-client and borg-server (router to NAS, append-only), restic-gcs and
# restic-gdrive (offsite). Client tiers run the SQLite snapshot command below before reading data.
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
      sqliteSnapshot = pkgs.callPackage ../../../pkgs/sqlite-snapshot { };

      autoDetectedSqliteDatabases = lib.optionalAttrs cfg.autoDetectSqlite (
        lib.optionalAttrs
          (
            (config.services.vaultwarden.enable or false)
            && (config.services.vaultwarden.dbBackend or "sqlite") == "sqlite"
          )
          {
            vaultwarden = "${
              config.services.vaultwarden.config.DATA_FOLDER or "/var/lib/vaultwarden"
            }/db.sqlite3";
          }
        //
          lib.optionalAttrs
            (
              (config.services.gitea.enable or false) && (config.services.gitea.database.type or "") == "sqlite3"
            )
            {
              gitea = config.services.gitea.database.path;
            }
        // lib.optionalAttrs (config.services.headscale.enable or false) {
          headscale =
            config.services.headscale.settings.database.sqlite.path or "/var/lib/headscale/db.sqlite";
        }
        //
          lib.optionalAttrs
            (
              (config.services.grafana.enable or false)
              && (config.services.grafana.settings.database.type or "sqlite3") == "sqlite3"
            )
            {
              grafana =
                config.services.grafana.settings.database.path
                  or "${config.services.grafana.dataDir}/data/grafana.db";
            }
        // lib.optionalAttrs (config.services.home-assistant.enable or false) {
          home-assistant = "${config.services.home-assistant.configDir}/home-assistant_v2.db";
        }
        // lib.optionalAttrs (config.services.navidrome.enable or false) {
          navidrome = "${config.services.navidrome.settings.DataFolder or "/var/lib/navidrome"}/navidrome.db";
        }
        // lib.optionalAttrs (config.services.audiobookshelf.enable or false) {
          audiobookshelf = "/var/lib/${config.services.audiobookshelf.dataDir}/config/absdatabase.sqlite";
        }
        // lib.optionalAttrs (config.services.docuseal.enable or false) {
          docuseal = "/var/lib/docuseal/db.sqlite3";
        }
      );

      # Auto-detected entries are merged into sqliteDatabases with mkDefault below, so this is the effective set.
      effectiveSqliteDatabases = cfg.sqliteDatabases;

      sqliteSnapshotCommand = lib.optionalString (effectiveSqliteDatabases != { }) (
        lib.escapeShellArgs (
          [
            (lib.getExe sqliteSnapshot)
            "--out-dir"
            cfg.sqliteBackupDir
            "--timeout"
            cfg.sqliteSnapshotTimeout
          ]
          ++ lib.mapAttrsToList (name: path: "${name}=${path}") effectiveSqliteDatabases
        )
      );
    in
    {
      options.my.backup = {
        sqliteDatabases = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = { };
          example = {
            vaultwarden = "/var/lib/vaultwarden/db.sqlite3";
            gitea = "/var/lib/gitea/data/gitea.db";
            headscale = "/var/lib/headscale/db.sqlite";
            grafana = "/var/lib/grafana/data/grafana.db";
          };
          description = ''
            Mapping of logical database names to live SQLite database file paths to snapshot online before backups.
            With autoDetectSqlite, detected databases are added here; an explicit entry of the same name wins.
          '';
        };

        autoDetectSqlite = lib.mkEnableOption "auto-snapshotting enabled homelab SQLite databases before backup";

        sqliteBackupDir = lib.mkOption {
          type = lib.types.path;
          default = "/var/backups/sqlite";
          description = "Root-only directory holding consistent SQLite snapshots.";
        };

        sqliteSnapshotTimeout = lib.mkOption {
          type = lib.types.str;
          default = "15m";
          description = "Upper bound on each database's snapshot, as a coreutils `timeout` duration.";
        };

        sqliteSnapshotCommand = lib.mkOption {
          type = lib.types.str;
          readOnly = true;
          internal = true;
          default = sqliteSnapshotCommand;
          description = "Shell command line that snapshots every configured SQLite database; empty when there are none.";
        };
      };

      config = lib.mkMerge [
        { my.backup.sqliteDatabases = lib.mapAttrs (_: lib.mkDefault) autoDetectedSqliteDatabases; }

        (lib.mkIf (effectiveSqliteDatabases != { }) {
          assertions = lib.mapAttrsToList (name: _: {
            assertion = builtins.match "[a-zA-Z0-9._-]+" name != null;
            message = "my.backup.sqliteDatabases key '${name}' contains invalid characters; use [a-zA-Z0-9._-]+.";
          }) effectiveSqliteDatabases;

          systemd.tmpfiles.rules = [
            "d ${cfg.sqliteBackupDir} 0700 root root -"
          ];
        })
      ];
    };
}
