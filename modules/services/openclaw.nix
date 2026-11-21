{ inputs, ... }:
{
  flake.modules.nixos.openclaw =
    {
      config,
      lib,
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

      config = lib.mkIf cfg.enable {
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
              # Caddy adds X-Forwarded-For, so proxied browsers never get silent local pairing.
              auth.mode = "token";
              controlUi.enabled = true;
            };
            agents.defaults = {
              inherit workspace;
              model.primary = cfg.model;
            };
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

        # Seeded once; the agent may edit its own AGENTS.md afterwards.
        systemd.tmpfiles.rules = [
          "d ${workspace} 0750 ${service.user} ${service.group} - -"
          "C ${workspace}/AGENTS.md - - - - ${workerInstructions}"
          "z ${workspace}/AGENTS.md 0640 ${service.user} ${service.group} - -"
        ];

        # Upstream's unit has no sandboxing; the gateway runs agent tool calls as this user.
        systemd.services.${service.unitName}.serviceConfig = {
          NoNewPrivileges = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          PrivateTmp = true;
          ReadWritePaths = [ service.stateDir ];
        };
      };
    };
}
