# OpenClaw clan service - Gateway/Node distributed AI assistant
#
# Gateway role: Control plane on always-on Linux server
# Node role: Device executors that run commands on behalf of gateway
#
# Uses shared clan.core.vars for token distribution (works on NixOS and Darwin)
#
# Reference implementations:
# - nix-openclaw: https://github.com/openclaw/nix-openclaw
# - clawdinators: https://github.com/openclaw/clawdinators
# - nix-steipete-tools: https://github.com/openclaw/nix-steipete-tools
{ lib, ... }:
let
  # Shared vars generator - imported by both gateway and node roles
  # This follows the ncps pattern: share = true means the generator runs once
  # and all machines access the same stored value
  varsForInstance =
    {
      instanceName,
      settings,
      pkgs,
    }:
    {
      clan.core.vars.generators."openclaw-${instanceName}" = {
        share = true; # Key: same token shared across all machines
        files.gateway-token = { }; # Secret - accessed via .path
        files.anthropic-token = { }; # Secret - Anthropic API key or session token
        files.discord-token = { }; # Secret - Discord bot token (optional)
        files.endpoint = {
          secret = false; # Public - accessed via .value
        };

        # Prompt user for Anthropic token during `clan vars generate`
        prompts.anthropic-token = {
          description = "Anthropic API key or Claude subscription session token";
          type = "hidden"; # Don't echo input
          persist = true; # Automatically save to files.anthropic-token
        };

        # Prompt user for Discord bot token during `clan vars generate`
        prompts.discord-token = {
          description = "Discord bot token (from Discord Developer Portal) - press Enter to skip";
          type = "hidden"; # Don't echo input
          persist = true; # Automatically save to files.discord-token
        };

        runtimeInputs = [ pkgs.openssl ];
        script = ''
          # Generate secure random token for gateway authentication
          ${pkgs.openssl}/bin/openssl rand -base64 32 > "$out"/gateway-token
          # Store endpoint for reference (though nodes specify their own)
          echo "${settings.endpoint}:${toString settings.port}" > "$out"/endpoint
          # anthropic-token and discord-token are handled by persist = true on the prompts
        '';
      };
    };

  # Common environment variables for all openclaw services
  # Includes legacy MOLTBOT_* and CLAWDBOT_* aliases for compatibility
  mkOpenclawEnv =
    {
      stateDir,
      configPath,
      isDarwin ? false,
    }:
    {
      # Primary variables
      OPENCLAW_NIX_MODE = "1";
      OPENCLAW_STATE_DIR = stateDir;
      OPENCLAW_CONFIG_PATH = configPath;

      # Legacy MOLTBOT aliases (some code paths still check these)
      MOLTBOT_NIX_MODE = "1";
      MOLTBOT_STATE_DIR = stateDir;
      MOLTBOT_CONFIG_PATH = configPath;

      # Legacy CLAWDBOT aliases
      CLAWDBOT_NIX_MODE = "1";
      CLAWDBOT_STATE_DIR = stateDir;
      CLAWDBOT_CONFIG_PATH = configPath;
    }
    // lib.optionalAttrs isDarwin {
      # macOS-specific image backend
      OPENCLAW_IMAGE_BACKEND = "sips";
      MOLTBOT_IMAGE_BACKEND = "sips";
      CLAWDBOT_IMAGE_BACKEND = "sips";
    };

  # Strip null values from nested attribute sets (for config JSON)
  stripNulls =
    value:
    if value == null then
      null
    else if builtins.isAttrs value then
      lib.filterAttrs (_: v: v != null) (builtins.mapAttrs (_: stripNulls) value)
    else if builtins.isList value then
      builtins.filter (v: v != null) (map stripNulls value)
    else
      value;
in
{
  _class = "clan.service";

  manifest = {
    name = "openclaw";
    description = "OpenClaw AI assistant with Gateway/Node distributed architecture";
    readme = builtins.readFile ./README.md;
  };

  # =============================================================================
  # Gateway Role - Control plane (runs on pp-router1)
  # =============================================================================
  roles.gateway = {
    description = "OpenClaw control plane - WebSocket server, messaging channels, AI agent execution";

    interface =
      { lib, ... }:
      {
        options = {
          port = lib.mkOption {
            type = lib.types.port;
            default = 18789;
            description = "WebSocket port for gateway";
          };

          endpoint = lib.mkOption {
            type = lib.types.str;
            example = "vpn.prestonperanich.com";
            description = "Public hostname/IP for nodes to connect to gateway";
          };

          stateDir = lib.mkOption {
            type = lib.types.str;
            default = "/var/lib/openclaw";
            description = "State directory for OpenClaw gateway";
          };

          logPath = lib.mkOption {
            type = lib.types.str;
            default = "/var/log/openclaw/gateway.log";
            description = "Log file path for gateway";
          };

          user = lib.mkOption {
            type = lib.types.str;
            default = "openclaw";
            description = "User to run the gateway service as";
          };

          openFirewall = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Open firewall port for gateway (usually not needed with VPN)";
          };

          extraConfig = lib.mkOption {
            type = lib.types.attrs;
            default = { };
            example = lib.literalExpression ''
              {
                channels.telegram = {
                  enabled = true;
                  allowFrom = [ "@username" ];
                };
                agents.defaults.model.primary = "claude-sonnet-4-20250514";
                auth.profiles.anthropic.apiKey = ""; # Use secretFile instead
              }
            '';
            description = ''
              Additional configuration to merge into openclaw.json.
              This allows configuring channels (Telegram, Discord), models,
              auth profiles, and other advanced options.

              For secrets, use environment variables or secret files rather
              than putting API keys directly in Nix config.
            '';
          };
        };
      };

    # perInstance as function to receive settings
    perInstance =
      {
        settings,
        instanceName,
        ...
      }:
      {
        nixosModule =
          {
            config,
            pkgs,
            inputs,
            ...
          }:
          let
            openclawPkgs = inputs.nix-openclaw.packages.${pkgs.system};
            gatewayPackage = openclawPkgs.openclaw-gateway or openclawPkgs.default;

            # Base configuration
            baseConfig = {
              gateway = {
                mode = "local";
                bind = "lan"; # Listen on LAN for VPN connections
                inherit (settings) port;
                auth = {
                  mode = "token";
                  # Token will be provided via environment variable
                };
              };
              agents.defaults = {
                workspace = "${settings.stateDir}/workspace";
              };
            };

            # Merge base config with user's extraConfig
            mergedConfig = stripNulls (lib.recursiveUpdate baseConfig settings.extraConfig);
            configJson = builtins.toJSON mergedConfig;
            configFile = pkgs.writeText "openclaw-${instanceName}.json" configJson;

            # Environment variables
            openclawEnv = mkOpenclawEnv {
              inherit (settings) stateDir;
              configPath = "${settings.stateDir}/openclaw.json";
            };

            # Wrapper script that loads tokens from credentials and executes gateway
            gatewayStartScript = pkgs.writeShellScript "openclaw-gateway-start" ''
              # Load gateway auth token from systemd credentials
              export OPENCLAW_GATEWAY_TOKEN="$(cat "$CREDENTIALS_DIRECTORY/gateway-token")"
              export MOLTBOT_GATEWAY_TOKEN="$OPENCLAW_GATEWAY_TOKEN"
              export CLAWDBOT_GATEWAY_TOKEN="$OPENCLAW_GATEWAY_TOKEN"

              # Load Anthropic API key / session token from systemd credentials
              export ANTHROPIC_API_KEY="$(cat "$CREDENTIALS_DIRECTORY/anthropic-token")"

              # Load Discord bot token from systemd credentials (if provided)
              if [ -s "$CREDENTIALS_DIRECTORY/discord-token" ]; then
                export DISCORD_BOT_TOKEN="$(cat "$CREDENTIALS_DIRECTORY/discord-token")"
              fi

              exec ${gatewayPackage}/bin/openclaw gateway --port ${toString settings.port}
            '';

            # Setup script for state directory - copies config instead of symlinking
            gatewaySetupScript = pkgs.writeShellScript "openclaw-gateway-setup" ''
              # Ensure directories exist
              mkdir -p ${settings.stateDir}/workspace
              mkdir -p ${settings.stateDir}/logs
              mkdir -p $(dirname ${settings.logPath})

              # Copy config file (not symlink) to allow potential runtime writes
              cp -f ${configFile} ${settings.stateDir}/openclaw.json
              chmod 644 ${settings.stateDir}/openclaw.json
            '';
          in
          {
            # Import shared vars generator
            imports = [
              (varsForInstance {
                inherit instanceName settings pkgs;
              })
            ];

            # Create system user for the gateway
            users.users.${settings.user} = {
              isSystemUser = true;
              group = settings.user;
              home = settings.stateDir;
              createHome = true;
              description = "OpenClaw gateway service user";
            };
            users.groups.${settings.user} = { };

            # Systemd service for gateway
            systemd.services."openclaw-gateway-${instanceName}" = {
              description = "OpenClaw Gateway (${instanceName})";
              wantedBy = [ "multi-user.target" ];
              after = [ "network-online.target" ];
              wants = [ "network-online.target" ];

              environment = openclawEnv // {
                HOME = settings.stateDir;
              };

              serviceConfig = {
                Type = "simple";
                User = settings.user;
                Group = settings.user;
                ExecStartPre = "+${gatewaySetupScript}"; # + runs as root for dir creation
                ExecStart = gatewayStartScript;
                Restart = "on-failure";
                RestartSec = "5s";

                # Restart backoff
                RestartSteps = 5;
                RestartMaxDelaySec = "5min";

                # Load secrets via systemd credentials from shared vars
                LoadCredential = [
                  "gateway-token:${
                    config.clan.core.vars.generators."openclaw-${instanceName}".files.gateway-token.path
                  }"
                  "anthropic-token:${
                    config.clan.core.vars.generators."openclaw-${instanceName}".files.anthropic-token.path
                  }"
                  "discord-token:${
                    config.clan.core.vars.generators."openclaw-${instanceName}".files.discord-token.path
                  }"
                ];

                # Logging
                StandardOutput = "append:${settings.logPath}";
                StandardError = "append:${settings.logPath}";

                # Security hardening
                NoNewPrivileges = true;
                ProtectSystem = "strict";
                ProtectHome = true;
                PrivateTmp = true;
                PrivateDevices = true;
                ProtectKernelTunables = true;
                ProtectKernelModules = true;
                ProtectControlGroups = true;
                RestrictNamespaces = true;
                RestrictRealtime = true;
                LockPersonality = true;
                ReadWritePaths = [
                  settings.stateDir
                  (builtins.dirOf settings.logPath)
                ];
              };
            };

            # Firewall (optional)
            networking.firewall.allowedTCPPorts = lib.mkIf settings.openFirewall [ settings.port ];

            # Common packages
            environment.systemPackages = with pkgs; [
              gatewayPackage
              jq
              websocat
            ];
          };
      };
  };

  # =============================================================================
  # Node Role - Device executors (runs on pp-wsl1, pp-ml1, etc.)
  # =============================================================================
  roles.node = {
    description = "OpenClaw node - executes commands on behalf of gateway";

    interface =
      { lib, ... }:
      {
        options = {
          displayName = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Display name for this node (defaults to hostname)";
          };

          gatewayEndpoint = lib.mkOption {
            type = lib.types.str;
            example = "vpn.prestonperanich.com:18789";
            description = ''
              Gateway endpoint (host:port) for nodes to connect to.
              User is responsible for ensuring DNS resolution works
              (via WireGuard, Tailscale, public DNS, etc.)
            '';
          };

          logPath = lib.mkOption {
            type = lib.types.str;
            default = "/var/log/openclaw/node.log";
            description = "Log file path for node service";
          };

          user = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = ''
              User to run the node service as.
              On NixOS: defaults to root (system service)
              On Darwin: defaults to current user (launchd agent)
            '';
          };
        };
      };

    # perInstance as function to receive settings
    perInstance =
      {
        settings,
        instanceName,
        machine,
        roles,
        ...
      }:
      let
        # Get gateway settings for the shared vars generator
        # We need port and endpoint from any gateway machine
        gatewayMachines = roles.gateway.machines or { };
        firstGateway = builtins.head (builtins.attrNames gatewayMachines);
        gatewaySettings =
          gatewayMachines.${firstGateway}.settings or {
            port = 18789;
            endpoint = "localhost";
          };
      in
      {
        # NixOS module for Linux nodes
        nixosModule =
          {
            config,
            pkgs,
            inputs,
            ...
          }:
          let
            openclawPkgs = inputs.nix-openclaw.packages.${pkgs.system};
            nodePackage = openclawPkgs.openclaw-gateway or openclawPkgs.default;

            displayName = if settings.displayName != null then settings.displayName else machine.name;

            # Environment variables
            openclawEnv = mkOpenclawEnv {
              stateDir = "/var/lib/openclaw-node";
              configPath = "/var/lib/openclaw-node/openclaw.json";
            };

            # Wrapper script that loads token from shared vars and executes node
            nodeStartScript = pkgs.writeShellScript "openclaw-node-start" ''
              # Load token from shared clan vars
              OPENCLAW_GATEWAY_TOKEN="$(cat "${
                config.clan.core.vars.generators."openclaw-${instanceName}".files.gateway-token.path
              }")"
              export OPENCLAW_GATEWAY_TOKEN
              export MOLTBOT_GATEWAY_TOKEN="$OPENCLAW_GATEWAY_TOKEN"
              export CLAWDBOT_GATEWAY_TOKEN="$OPENCLAW_GATEWAY_TOKEN"

              exec ${nodePackage}/bin/openclaw node \
                --host "${settings.gatewayEndpoint}" \
                --display-name "${displayName}"
            '';

            # Setup script for directories
            nodeSetupScript = pkgs.writeShellScript "openclaw-node-setup" ''
              mkdir -p /var/lib/openclaw-node
              mkdir -p $(dirname ${settings.logPath})
            '';
          in
          {
            # Import shared vars generator (same as gateway)
            imports = [
              (varsForInstance {
                inherit instanceName pkgs;
                settings = gatewaySettings;
              })
            ];

            # Systemd service for node (system service)
            systemd.services."openclaw-node-${instanceName}" = {
              description = "OpenClaw Node (${instanceName})";
              wantedBy = [ "multi-user.target" ];
              after = [ "network-online.target" ];
              wants = [ "network-online.target" ];

              environment = openclawEnv;

              serviceConfig = {
                Type = "simple";
                ExecStartPre = "+${nodeSetupScript}";
                ExecStart = nodeStartScript;
                Restart = "on-failure";
                RestartSec = "10s";

                # Restart backoff to prevent storms
                RestartSteps = 5;
                RestartMaxDelaySec = "5min";

                # Logging
                StandardOutput = "append:${settings.logPath}";
                StandardError = "append:${settings.logPath}";
              }
              // lib.optionalAttrs (settings.user != null) {
                User = settings.user;
                Group = settings.user;
              };
            };

            # Make openclaw CLI available
            environment.systemPackages = [
              nodePackage
              pkgs.jq
            ];
          };

        # Darwin module for macOS nodes
        darwinModule =
          {
            config,
            pkgs,
            inputs,
            ...
          }:
          let
            openclawPkgs = inputs.nix-openclaw.packages.${pkgs.system};
            nodePackage = openclawPkgs.openclaw-gateway or openclawPkgs.default;

            displayName = if settings.displayName != null then settings.displayName else machine.name;

            # Use user's home directory for state on Darwin
            stateDir = "$HOME/.openclaw-node";
            logDir = "$HOME/Library/Logs";

            # Wrapper script that loads token from shared vars and executes node
            nodeStartScript = pkgs.writeShellScript "openclaw-node-start" ''
              # Ensure directories exist
              mkdir -p "${stateDir}"

              # Load token from shared clan vars
              OPENCLAW_GATEWAY_TOKEN="$(cat "${
                config.clan.core.vars.generators."openclaw-${instanceName}".files.gateway-token.path
              }")"
              export OPENCLAW_GATEWAY_TOKEN
              export MOLTBOT_GATEWAY_TOKEN="$OPENCLAW_GATEWAY_TOKEN"
              export CLAWDBOT_GATEWAY_TOKEN="$OPENCLAW_GATEWAY_TOKEN"

              # Set environment
              export OPENCLAW_NIX_MODE="1"
              export OPENCLAW_STATE_DIR="${stateDir}"
              export OPENCLAW_IMAGE_BACKEND="sips"
              export MOLTBOT_NIX_MODE="1"
              export MOLTBOT_STATE_DIR="${stateDir}"
              export MOLTBOT_IMAGE_BACKEND="sips"
              export CLAWDBOT_NIX_MODE="1"
              export CLAWDBOT_STATE_DIR="${stateDir}"
              export CLAWDBOT_IMAGE_BACKEND="sips"

              exec ${nodePackage}/bin/openclaw node \
                --host "${settings.gatewayEndpoint}" \
                --display-name "${displayName}"
            '';
          in
          {
            # Import shared vars generator (same as gateway)
            imports = [
              (varsForInstance {
                inherit instanceName pkgs;
                settings = gatewaySettings;
              })
            ];

            # Launchd AGENT (user-level, not daemon) for node service
            # This runs as the logged-in user, with access to user context
            launchd.user.agents."openclaw-node-${instanceName}" = {
              serviceConfig = {
                Label = "com.openclaw.node.${instanceName}";
                ProgramArguments = [ "${nodeStartScript}" ];
                RunAtLoad = true;
                KeepAlive = true;
                StandardOutPath = "${logDir}/openclaw-node-${instanceName}.log";
                StandardErrorPath = "${logDir}/openclaw-node-${instanceName}.err";
                ThrottleInterval = 30; # Prevent restart storms
              };
            };

            # Set environment variable for the OpenClaw app (if using native app)
            environment.variables.OPENCLAW_GATEWAY_ENDPOINT = settings.gatewayEndpoint;

            # Common packages
            environment.systemPackages = [
              nodePackage
              pkgs.jq
            ];
          };
      };
  };
}
