{ inputs, ... }:
{
  flake.modules.nixos.openclaw =
    {
      config,
      lib,
      options,
      pkgs,
      ...
    }:
    let
      cfg = config.my.openclaw;
      service = config.services.openclaw-gateway;
      inherit (lib) mkOption types;
      workspace = "${service.stateDir}/workspace";
      workerInstructions = pkgs.writeText "openclaw-AGENTS.md" ''
        Use the exec tool to run `rex --autostart=false -S ${cfg.workerEndpoint}` with a Rex subcommand.
        Run coding tasks in a dedicated worker pane in the requested checkout. Record the checkout,
        Rex session and block IDs with the task so you can reconnect before starting another worker.
        Report the tested revision and result to the originating chat.
        The worker has no push credentials: clone over HTTPS into ~/src and report diffs instead of pushing.
      '';
      # Root reads the token; exporting it keeps it out of argv, where every user could see it.
      openclawCtl = pkgs.writeShellScriptBin "openclaw-ctl" ''
        set -euo pipefail
        set -a
        . ${config.sops.templates."openclaw.env".path}
        set +a
        export OPENCLAW_CONFIG_PATH=${service.configPath} OPENCLAW_STATE_DIR=${service.stateDir} HOME=${service.stateDir}
        exec ${pkgs.util-linux}/bin/runuser --preserve-environment -u ${service.user} -- ${service.package}/bin/openclaw "$@"
      '';
    in
    {
      imports = [ inputs.nix-openclaw.nixosModules.openclaw-gateway ];

      options.my.openclaw = {
        enable = lib.mkEnableOption "the OpenClaw gateway";
        publicUrl = mkOption {
          type = types.strMatching "https://[^/ ]+";
          description = "Private HTTPS origin served by Caddy; the Control UI only accepts this browser origin.";
        };
        port = mkOption {
          type = types.port;
          default = 18789;
          description = "Loopback port of the gateway (WebSocket, HTTP and Control UI).";
        };
        model = mkOption {
          type = types.str;
          description = "Primary model, as provider/model (the config file is read-only, so set it here).";
        };
        gatewayTokenSecret = mkOption {
          type = types.str;
          description = "SOPS key holding the gateway token the Control UI and CLI authenticate with.";
        };
        workerEndpoint = mkOption {
          type = types.str;
          description = "Rex login-server address including the worker account.";
        };
      };

      config = lib.mkIf cfg.enable (
        {
          services.openclaw-gateway = {
            enable = true;
            package = inputs.nix-openclaw.packages.${pkgs.stdenv.hostPlatform.system}.openclaw;
            inherit (cfg) port;
            servicePath = [ inputs.rex.packages.${pkgs.stdenv.hostPlatform.system}.rex ];
            environmentFiles = [ config.sops.templates."openclaw.env".path ];
            config = {
              gateway = {
                mode = "local";
                bind = "loopback";
                inherit (cfg) port;
                publicOrigin = cfg.publicUrl;
                # Local Caddy is the only proxy; it overwrites X-Forwarded-For with the real client.
                trustedProxies = [ "127.0.0.1" ];
                # Caddy adds X-Forwarded-For, so proxied browsers never get silent local pairing.
                auth.mode = "token";
                controlUi.enabled = true;
              };
              agents.defaults = {
                inherit workspace;
                model.primary = cfg.model;
              };
              # The default runs any command on the NAS unasked; Rex dispatch is approved once with "allow always".
              tools.exec.mode = "ask";
            };
          };
          users.users.${service.user}.packages = [
            service.package
            inputs.rex.packages.${pkgs.stdenv.hostPlatform.system}.rex
          ];
          environment.systemPackages = [ openclawCtl ];

          sops.secrets.${cfg.gatewayTokenSecret} = { };
          sops.templates."openclaw.env" = {
            owner = "root";
            mode = "0400";
            restartUnits = [ "${service.unitName}.service" ];
            content = "OPENCLAW_GATEWAY_TOKEN=${config.sops.placeholder.${cfg.gatewayTokenSecret}}";
          };

          systemd.tmpfiles.rules = [ "d ${workspace} 0750 ${service.user} ${service.group} - -" ];
          # Nix owns AGENTS.md, as in upstream's home-manager module; linked as the service user
          # because tmpfiles refuses to write through the openclaw-owned state directory.
          services.openclaw-gateway.execStartPre = [
            "${pkgs.coreutils}/bin/ln -sfn ${workerInstructions} ${workspace}/AGENTS.md"
          ];

          # Upstream's unit has no sandboxing; the gateway runs agent tool calls as this user.
          systemd.services.${service.unitName}.serviceConfig = {
            NoNewPrivileges = true;
            ProtectSystem = "strict";
            ProtectHome = true;
            PrivateTmp = true;
            ReadWritePaths = [ service.stateDir ];
            # Hide NAS data (media, phone backups, other services' state) that is world-readable.
            InaccessiblePaths = [ "-/tank" ];
            TemporaryFileSystem = "/var/lib:ro";
            BindPaths = [ service.stateDir ];
            # Idle is about 1.4 GiB and startup peaks near 1.9 GiB; agent commands share this cgroup.
            MemoryHigh = "2560M";
            MemoryMax = "3G";
          };
        }
        // lib.optionalAttrs (options ? my.backup.sqliteDatabases) {
          my.backup.sqliteDatabases = lib.mkIf config.my.backup.autoDetectSqlite {
            openclaw = "${service.stateDir}/state/openclaw.sqlite";
          };
        }
      );
    };
}
