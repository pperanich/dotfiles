{ inputs, ... }:
{
  flake.modules.nixos.hermesCoordinator =
    {
      config,
      lib,
      options,
      pkgs,
      ...
    }:
    let
      cfg = config.my.hermesCoordinator;
      service = config.services.hermes-agent;
      inherit (lib) mkOption types;
    in
    {
      imports = [ inputs.hermes-agent.nixosModules.default ];

      options.my.hermesCoordinator = {
        enable = lib.mkEnableOption "the Hermes coding coordinator";
        model = mkOption {
          type = types.str;
          description = "Model ID for the ChatGPT subscription.";
        };
        publicUrl = mkOption {
          type = types.strMatching "https://[^/ ]+";
          description = "Private HTTPS origin served by Caddy.";
        };
        username = mkOption {
          type = types.strMatching "[A-Za-z0-9._-]+";
          description = "Webapp login name.";
        };
        passwordHashSecret = mkOption {
          type = types.str;
          description = "SOPS key for the Hermes scrypt password verifier.";
        };
        signingKeySecret = mkOption {
          type = types.str;
          description = "SOPS key for signing Webapp sessions.";
        };
        workerEndpoint = mkOption {
          type = types.str;
          description = "Rex login-server address including the worker account.";
        };
      };

      config = lib.mkIf cfg.enable (
        {
          services.hermes-agent = {
            enable = true;
            extraPackages = [ inputs.rex.packages.${pkgs.stdenv.hostPlatform.system}.rex ];
            workingDirectory = "${service.stateDir}/workspace";
            documents."AGENTS.md" = ''
              Use the terminal tool to run `rex --autostart=false -S ${cfg.workerEndpoint}` with a Rex subcommand.
              Run coding tasks in a dedicated worker pane in the requested checkout. Record the checkout,
              Rex session and block IDs with the task so you can reconnect before starting another worker.
              Report the tested revision and result to the originating chat.
              The worker has no push credentials: clone over HTTPS into ~/src and report diffs instead of pushing.
            '';
            settings = {
              model = {
                provider = "openai-codex";
                default = cfg.model;
              };
              webapp = {
                enabled = true;
                host = "127.0.0.1";
                # OpenCloud holds most of 9100-9282 on the NAS, 9120 included.
                port = 9480;
                public_url = cfg.publicUrl;
              };
            };
          };
          users.users.${service.user}.packages = [ service.package ];

          sops.secrets.${cfg.passwordHashSecret} = { };
          sops.secrets.${cfg.signingKeySecret} = { };
          sops.templates."hermes-web.env" = {
            owner = "root";
            mode = "0400";
            restartUnits = [ "hermes-agent.service" ];
            content = ''
              HERMES_DASHBOARD_BASIC_AUTH_USERNAME=${cfg.username}
              HERMES_DASHBOARD_BASIC_AUTH_PASSWORD_HASH=${config.sops.placeholder.${cfg.passwordHashSecret}}
              HERMES_DASHBOARD_BASIC_AUTH_SECRET=${config.sops.placeholder.${cfg.signingKeySecret}}
            '';
          };
          systemd.services.hermes-agent = {
            # The upstream environmentFiles option copies its inputs into the backed-up Hermes home.
            serviceConfig.EnvironmentFile = config.sops.templates."hermes-web.env".path;
            restartTriggers = [ (pkgs.writeText "hermes-settings.json" (builtins.toJSON service.settings)) ];
            # The terminal tool runs as this user; hide NAS data (media, phone backups, other services' state).
            serviceConfig = {
              InaccessiblePaths = [ "-/tank" ];
              TemporaryFileSystem = "/var/lib:ro";
              BindPaths = [ service.stateDir ];
              # Idle is about 300 MiB; a runaway session is killed here rather than by the NAS OOM killer.
              MemoryHigh = "768M";
              MemoryMax = "1G";
            };
          };
        }
        // lib.optionalAttrs (options ? my.backup.sqliteDatabases) {
          my.backup.sqliteDatabases = lib.mkIf config.my.backup.autoDetectSqlite {
            hermes = "${service.stateDir}/.hermes/state.db";
          };
        }
      );
    };
}
