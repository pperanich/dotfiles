_: {
  # NixOS system-level Borgbackup configuration
  flake.modules.nixos.borgbackup =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.features.borgbackup;
    in
    {
      options.features.borgbackup = {
        repository = lib.mkOption {
          type = lib.types.str;
          example = "borg@backup-server:/backups/{hostname}";
          description = "Borg repository path";
        };
        passphraseFile = lib.mkOption {
          type = lib.types.path;
          description = "Path to file containing the Borg repository passphrase";
        };
        paths = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [
            "/home"
            "/var"
            "/root"
          ];
          description = "Paths to backup";
        };
        excludePatterns = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [
            "*.pyc"
            "*.o"
            "*/node_modules/*"
            "*/.cache/*"
            "*/.cargo/*"
            "/var/cache"
            "/var/tmp"
            "/var/log"
          ];
          description = "Patterns to exclude from backup";
        };
        frequency = lib.mkOption {
          type = lib.types.str;
          default = "daily";
          description = "Backup frequency (systemd timer format)";
        };
        keepDaily = lib.mkOption {
          type = lib.types.int;
          default = 7;
          description = "Number of daily backups to keep";
        };
        keepWeekly = lib.mkOption {
          type = lib.types.int;
          default = 4;
          description = "Number of weekly backups to keep";
        };
      };

      config = {
        # Borg backup service
        services.borgbackup.jobs.main = {
          repo = cfg.repository;
          inherit (cfg) paths;
          exclude = cfg.excludePatterns;

          encryption = {
            mode = "repokey-blake2";
            passCommand = "cat ${cfg.passphraseFile}";
          };

          environment.BORG_RSH = "ssh -o 'StrictHostKeyChecking=no'";

          compression = "auto,lzma";
          startAt = cfg.frequency;

          prune.keep = {
            daily = cfg.keepDaily;
            weekly = cfg.keepWeekly;
            monthly = 6;
          };

          preHook = ''
            # Ensure network connectivity
            ${pkgs.iputils}/bin/ping -c1 8.8.8.8 || {
              echo "No network connectivity, skipping backup"
              exit 1
            }
          '';

          postHook = ''
            cat > /var/log/borgbackup-status <<EOF
            last_backup=$(date +%s)
            exit_code=$exitStatus
            backup_size=$(${pkgs.borgbackup}/bin/borg info ::'{hostname}-{now}' --json 2>/dev/null | ${pkgs.jq}/bin/jq -r '.archives[0].stats.compressed_size // "unknown"')
            EOF
          '';
        };

        # Required packages
        environment.systemPackages = with pkgs; [
          borgbackup
        ];

        # Create log directory
        systemd.tmpfiles.rules = [
          "d /var/log 0755 root root - -"
        ];
      };
    };

  # Home Manager backup tools
  flake.modules.homeManager.borgbackup =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        borgbackup
        borgmatic # Configuration management for borg
      ];
    };
}
