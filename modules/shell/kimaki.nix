# Kimaki - Discord bot for remote development via OpenCode
# https://github.com/remorses/kimaki
_: {
  flake.modules = {
    # Darwin (macOS) launchd service
    darwin.kimaki =
      {
        config,
        lib,
        pkgs,
        ...
      }:
      let
        cfg = config.services.kimaki;

        # Build dependencies for native modules (better-sqlite3)
        # Note: Darwin needs clang for -stdlib=libc++ support
        buildDeps = [
          pkgs.bun
          pkgs.git
          pkgs.sqlite
          pkgs.python3
          pkgs.gnumake
          pkgs.clang
          pkgs.coreutils
          pkgs.bash
          pkgs.gnused
        ];

        # Expand ~ to actual home directory for paths
        expandedDataDir =
          if lib.hasPrefix "~/" cfg.dataDir then
            "/Users/${config.users.primaryUser.username or "pperanich"}${lib.removePrefix "~" cfg.dataDir}"
          else
            cfg.dataDir;

        # Build command line arguments
        kimakiArgs = [
          "--data-dir"
          cfg.dataDir
        ]
        ++ lib.optionals cfg.useWorktrees [ "--use-worktrees" ]
        ++ lib.optionals cfg.enableVoiceChannels [ "--enable-voice-channels" ]
        ++ lib.optionals (cfg.verbosity != null) [
          "--verbosity"
          cfg.verbosity
        ];

        kimakiArgsStr = lib.concatStringsSep " " (map lib.escapeShellArg kimakiArgs);

        # Wrapper script that checks for initialization before starting
        kimakiWrapper = pkgs.writeShellScript "kimaki-wrapper" ''
          set -euo pipefail

          DATA_DIR="${expandedDataDir}"
          DB_FILE="$DATA_DIR/discord-sessions.db"

          if [ ! -f "$DB_FILE" ]; then
            echo "ERROR: Kimaki not initialized. Database not found at: $DB_FILE"
            echo ""
            echo "Run 'bunx kimaki@latest --data-dir ${cfg.dataDir}' manually first to complete setup."
            exit 1
          fi

          if ! ${pkgs.sqlite}/bin/sqlite3 "$DB_FILE" "SELECT 1 FROM bot_tokens LIMIT 1;" >/dev/null 2>&1; then
            echo "ERROR: Kimaki database exists but has no bot credentials."
            echo ""
            echo "Run 'bunx kimaki@latest --data-dir ${cfg.dataDir}' manually to complete setup."
            exit 1
          fi

          echo "Kimaki initialized. Starting bot..."
          exec ${pkgs.bun}/bin/bunx kimaki@latest ${kimakiArgsStr}
        '';
      in
      {
        options.services.kimaki = {
          enable = lib.mkEnableOption "Kimaki Discord bot service";

          dataDir = lib.mkOption {
            type = lib.types.str;
            default = "~/.kimaki";
            description = "Data directory for Kimaki (stores database, credentials)";
          };

          logDir = lib.mkOption {
            type = lib.types.str;
            default = "/tmp";
            description = "Directory for log files";
          };

          useWorktrees = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Create git worktrees for all new sessions started from channel messages";
          };

          enableVoiceChannels = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Create voice channels for projects (disabled by default)";
          };

          verbosity = lib.mkOption {
            type = lib.types.nullOr (
              lib.types.enum [
                "tools-and-text"
                "text-and-essential-tools"
                "text-only"
              ]
            );
            default = null;
            description = "Default verbosity level for all channels";
          };
        };

        config = lib.mkIf cfg.enable {
          environment.systemPackages = buildDeps;

          launchd.user.agents.kimaki = {
            serviceConfig = {
              Label = "com.kimaki.bot";
              ProgramArguments = [ "${kimakiWrapper}" ];
              RunAtLoad = true;
              KeepAlive = {
                SuccessfulExit = false;
                Crashed = true;
              };
              ThrottleInterval = 30;
              StandardOutPath = "${cfg.logDir}/kimaki.out.log";
              StandardErrorPath = "${cfg.logDir}/kimaki.err.log";
              EnvironmentVariables = {
                # All build tools provided via Nix packages
                PATH = lib.makeBinPath buildDeps;
                HOME = "/Users/${config.users.primaryUser.username or "pperanich"}";
              };
            };
          };
        };
      };

    # NixOS systemd user service
    nixos.kimaki =
      {
        config,
        lib,
        pkgs,
        ...
      }:
      let
        cfg = config.services.kimaki;

        # Build dependencies for native modules (better-sqlite3)
        buildDeps = [
          pkgs.bun
          pkgs.git
          pkgs.sqlite
          pkgs.python3
          pkgs.gnumake
          pkgs.gcc
          pkgs.coreutils
          pkgs.bash
          pkgs.gnused
        ];

        expandedDataDir =
          if lib.hasPrefix "~/" cfg.dataDir then
            "/home/${cfg.user}${lib.removePrefix "~" cfg.dataDir}"
          else
            cfg.dataDir;

        kimakiArgs = [
          "--data-dir"
          cfg.dataDir
        ]
        ++ lib.optionals cfg.useWorktrees [ "--use-worktrees" ]
        ++ lib.optionals cfg.enableVoiceChannels [ "--enable-voice-channels" ]
        ++ lib.optionals (cfg.verbosity != null) [
          "--verbosity"
          cfg.verbosity
        ];

        kimakiArgsStr = lib.concatStringsSep " " (map lib.escapeShellArg kimakiArgs);

        kimakiWrapper = pkgs.writeShellScript "kimaki-wrapper" ''
          set -euo pipefail

          DATA_DIR="${expandedDataDir}"
          DB_FILE="$DATA_DIR/discord-sessions.db"

          if [ ! -f "$DB_FILE" ]; then
            echo "ERROR: Kimaki not initialized. Database not found at: $DB_FILE"
            echo ""
            echo "Run 'bunx kimaki@latest --data-dir ${cfg.dataDir}' manually first to complete setup."
            exit 1
          fi

          if ! ${pkgs.sqlite}/bin/sqlite3 "$DB_FILE" "SELECT 1 FROM bot_tokens LIMIT 1;" >/dev/null 2>&1; then
            echo "ERROR: Kimaki database exists but has no bot credentials."
            echo ""
            echo "Run 'bunx kimaki@latest --data-dir ${cfg.dataDir}' manually to complete setup."
            exit 1
          fi

          echo "Kimaki initialized. Starting bot..."
          exec ${pkgs.bun}/bin/bunx kimaki@latest ${kimakiArgsStr}
        '';
      in
      {
        options.services.kimaki = {
          enable = lib.mkEnableOption "Kimaki Discord bot service";

          dataDir = lib.mkOption {
            type = lib.types.str;
            default = "~/.kimaki";
            description = "Data directory for Kimaki (stores database, credentials)";
          };

          user = lib.mkOption {
            type = lib.types.str;
            default = "pperanich";
            description = "User to run Kimaki as";
          };

          useWorktrees = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Create git worktrees for all new sessions started from channel messages";
          };

          enableVoiceChannels = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Create voice channels for projects (disabled by default)";
          };

          verbosity = lib.mkOption {
            type = lib.types.nullOr (
              lib.types.enum [
                "tools-and-text"
                "text-and-essential-tools"
                "text-only"
              ]
            );
            default = null;
            description = "Default verbosity level for all channels";
          };
        };

        config = lib.mkIf cfg.enable {
          systemd.user.services.kimaki = {
            description = "Kimaki Discord bot for remote development";
            wantedBy = [ "default.target" ];
            after = [ "network-online.target" ];
            wants = [ "network-online.target" ];

            unitConfig = {
              ConditionPathExists = "${expandedDataDir}/discord-sessions.db";
            };

            serviceConfig = {
              Type = "simple";
              ExecStart = "${kimakiWrapper}";
              Restart = "on-failure";
              RestartSec = "30s";
              Environment = [ "PATH=${lib.makeBinPath buildDeps}" ];
            };
          };

          environment.systemPackages = buildDeps;
        };
      };

    # Home Manager module (alternative to system-level service)
    homeManager.kimaki =
      {
        config,
        lib,
        pkgs,
        ...
      }:
      let
        cfg = config.services.kimaki;

        # Build dependencies for native modules (better-sqlite3)
        # Compiler: clang on Darwin (for -stdlib=libc++), gcc on Linux
        buildDeps = [
          pkgs.bun
          pkgs.git
          pkgs.sqlite
          pkgs.python3
          pkgs.gnumake
          pkgs.coreutils
          pkgs.bash
          pkgs.gnused
        ]
        ++ lib.optionals pkgs.stdenv.hostPlatform.isDarwin [ pkgs.clang ]
        ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [ pkgs.gcc ];

        expandedDataDir =
          if lib.hasPrefix "~/" cfg.dataDir then "$HOME${lib.removePrefix "~" cfg.dataDir}" else cfg.dataDir;

        kimakiArgs = [
          "--data-dir"
          cfg.dataDir
        ]
        ++ lib.optionals cfg.useWorktrees [ "--use-worktrees" ]
        ++ lib.optionals cfg.enableVoiceChannels [ "--enable-voice-channels" ]
        ++ lib.optionals (cfg.verbosity != null) [
          "--verbosity"
          cfg.verbosity
        ];

        kimakiArgsStr = lib.concatStringsSep " " (map lib.escapeShellArg kimakiArgs);

        kimakiWrapper = pkgs.writeShellScript "kimaki-wrapper" ''
          set -euo pipefail

          DATA_DIR="${expandedDataDir}"
          DB_FILE="$DATA_DIR/discord-sessions.db"

          if [ ! -f "$DB_FILE" ]; then
            echo "ERROR: Kimaki not initialized. Database not found at: $DB_FILE"
            echo ""
            echo "Run 'bunx kimaki@latest --data-dir ${cfg.dataDir}' manually first to complete setup."
            exit 1
          fi

          if ! ${pkgs.sqlite}/bin/sqlite3 "$DB_FILE" "SELECT 1 FROM bot_tokens LIMIT 1;" >/dev/null 2>&1; then
            echo "ERROR: Kimaki database exists but has no bot credentials."
            echo ""
            echo "Run 'bunx kimaki@latest --data-dir ${cfg.dataDir}' manually to complete setup."
            exit 1
          fi

          echo "Kimaki initialized. Starting bot..."
          exec ${pkgs.bun}/bin/bunx kimaki@latest ${kimakiArgsStr}
        '';
      in
      {
        options.services.kimaki = {
          enable = lib.mkEnableOption "Kimaki Discord bot service";

          dataDir = lib.mkOption {
            type = lib.types.str;
            default = "~/.kimaki";
            description = "Data directory for Kimaki (stores database, credentials)";
          };

          useWorktrees = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Create git worktrees for all new sessions started from channel messages";
          };

          enableVoiceChannels = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Create voice channels for projects (disabled by default)";
          };

          verbosity = lib.mkOption {
            type = lib.types.nullOr (
              lib.types.enum [
                "tools-and-text"
                "text-and-essential-tools"
                "text-only"
              ]
            );
            default = null;
            description = "Default verbosity level for all channels";
          };
        };

        config = lib.mkIf cfg.enable {
          home.packages = buildDeps;

          systemd.user.services.kimaki = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
            Unit = {
              Description = "Kimaki Discord bot for remote development";
              After = [ "network-online.target" ];
              Wants = [ "network-online.target" ];
            };

            Service = {
              Type = "simple";
              ExecStart = "${kimakiWrapper}";
              Restart = "on-failure";
              RestartSec = "30s";
              Environment = [ "PATH=${lib.makeBinPath buildDeps}" ];
            };

            Install = {
              WantedBy = [ "default.target" ];
            };
          };

          launchd.agents.kimaki = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
            enable = true;
            config = {
              Label = "com.kimaki.bot";
              ProgramArguments = [ "${kimakiWrapper}" ];
              RunAtLoad = true;
              KeepAlive = {
                SuccessfulExit = false;
                Crashed = true;
              };
              ThrottleInterval = 30;
              StandardOutPath = "/tmp/kimaki.out.log";
              StandardErrorPath = "/tmp/kimaki.err.log";
              EnvironmentVariables = {
                # All build tools provided via Nix packages
                PATH = lib.makeBinPath buildDeps;
              };
            };
          };
        };
      };
  };
}
