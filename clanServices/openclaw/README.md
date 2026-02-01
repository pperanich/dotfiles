---
description = "OpenClaw AI assistant with Gateway/Node distributed architecture"
categories = ["System", "Network", "AI"]
features = ["inventory"]

[constraints]
roles.gateway.min = 1
roles.gateway.max = 1
---

# OpenClaw Clan Service

This service deploys OpenClaw in a distributed Gateway/Node architecture:

- **Gateway**: Control plane running on a server (always-on Linux)
  - WebSocket server for node communication
  - Messaging channel integration (Telegram, Discord, etc.)
  - AI agent execution and tool routing

- **Node**: Device executors that run commands on behalf of the gateway
  - Execute `system.run` commands (xcodebuild, xcrun, etc.)
  - Expose device capabilities (camera, screen, etc.)
  - Connect to gateway via WebSocket
  - Supports both NixOS and Darwin (macOS)

## Architecture

```
Gateway (pp-router1)          Nodes (pp-wsl1, pp-ml1)
     |                              |
     | WebSocket (port 18789)       |
     |<---------------------------->|
     |                              |
  Telegram/etc.              system.run commands
     |                              |
   User                      xcodebuild, etc.
```

## Token Management

Authentication tokens are automatically managed via `clan.core.vars` with `share = true`:

1. **Generation**: Token is generated once when you run `clan vars generate`
2. **Distribution**: Same token is automatically available to all machines (gateway + nodes)
3. **Storage**: Encrypted in `vars/shared/openclaw-<instance>/gateway-token/`
4. **No manual sync required**: Shared vars are automatically consistent across machines

## Quick Start

```nix
{
  inventory.instances.openclaw = {
    module = {
      name = "@pperanich/openclaw";
      input = "self";  # or your flake input name
    };
    roles = {
      gateway.machines.pp-router1 = {
        settings = {
          port = 18789;
          endpoint = "vpn.prestonperanich.com";
        };
      };
      node.machines = {
        pp-wsl1 = {
          settings = {
            displayName = "WSL Dev Node";
            gatewayEndpoint = "vpn.prestonperanich.com:18789";
          };
        };
        pp-ml1 = {
          settings = {
            displayName = "MacBook Dev Node";
            gatewayEndpoint = "vpn.prestonperanich.com:18789";
          };
        };
      };
    };
  };
}
```

## Advanced Configuration

### Configuring Channels, Models, and Auth

Use the `extraConfig` option to configure advanced features like messaging channels,
AI models, and authentication profiles:

```nix
roles.gateway.machines.pp-router1 = {
  settings = {
    port = 18789;
    endpoint = "vpn.prestonperanich.com";

    extraConfig = {
      # Configure default AI model
      agents.defaults.model = {
        primary = "claude-sonnet-4-20250514";
        fallback = "gpt-4o";
      };

      # Enable Discord channel (token from clan vars)
      channels.discord = {
        enabled = true;
        dm = {
          enabled = true;
          policy = "pairing";  # Requires approval code for new DMs
        };
        guilds = {
          "YOUR_GUILD_ID" = {
            requireMention = true;
            channels = {
              "ai-chat" = { allow = true; };
            };
          };
        };
      };

      # Tool configuration
      tools = {
        exec.timeout = 300;  # 5 minute timeout
      };
    };
  };
};
```

### Secrets Management

Secrets are managed via `clan vars generate` prompts:

| Token             | Required | Description                                            |
| ----------------- | -------- | ------------------------------------------------------ |
| `anthropic-token` | Yes      | Anthropic API key or Claude subscription session token |
| `discord-token`   | No       | Discord bot token (from Discord Developer Portal)      |

```bash
# Run this to set up all tokens (prompts for each)
clan vars generate pp-router1
```

The tokens are automatically:

1. Encrypted and stored in `vars/shared/openclaw-<instance>/`
2. Distributed to all machines via clan's shared vars system
3. Injected into the gateway service via systemd credentials

**To update a token later**, delete the var file and re-run:

```bash
rm -rf vars/shared/openclaw-<instance>/discord-token
clan vars generate pp-router1
```

## Deployment

```bash
# Generate shared token (run once)
clan vars generate pp-router1

# Deploy gateway
clan machines update pp-router1

# Deploy nodes
clan machines update pp-wsl1
clan machines update pp-ml1  # Darwin supported!
```

## Configuration Options

### Gateway Settings

| Option         | Type   | Default                       | Description                                 |
| -------------- | ------ | ----------------------------- | ------------------------------------------- |
| `port`         | int    | 18789                         | WebSocket port for gateway                  |
| `endpoint`     | string | required                      | Hostname/IP for nodes to connect            |
| `stateDir`     | string | /var/lib/openclaw             | State directory                             |
| `logPath`      | string | /var/log/openclaw/gateway.log | Log file path                               |
| `user`         | string | openclaw                      | Service user                                |
| `openFirewall` | bool   | false                         | Open firewall port                          |
| `extraConfig`  | attrs  | {}                            | Additional config merged into openclaw.json |

### Node Settings

| Option            | Type   | Default                    | Description                                                 |
| ----------------- | ------ | -------------------------- | ----------------------------------------------------------- |
| `displayName`     | string | hostname                   | Display name for this node                                  |
| `gatewayEndpoint` | string | required                   | Gateway host:port to connect to                             |
| `logPath`         | string | /var/log/openclaw/node.log | Log file path                                               |
| `user`            | string | null                       | Service user (null = root on NixOS, current user on Darwin) |

## extraConfig Schema

The `extraConfig` option accepts any valid OpenClaw configuration. Key sections include:

### agents

```nix
extraConfig.agents = {
  defaults = {
    model = {
      primary = "claude-sonnet-4-20250514";
      fallback = "gpt-4o";
    };
    workspace = "/var/lib/openclaw/workspace";
    contextPruning.enabled = true;
  };
};
```

### channels

#### Discord Channel (recommended)

Discord is fully supported. The bot token is injected via `DISCORD_BOT_TOKEN` environment variable
(set during `clan vars generate`).

```nix
extraConfig.channels = {
  discord = {
    enabled = true;
    # Token injected automatically from clan vars

    # DM access control (default: pairing - requires approval code)
    dm = {
      enabled = true;
      policy = "pairing";  # or "allowlist", "open", "disabled"
      allowFrom = [ "YOUR_DISCORD_USER_ID" ];
    };

    # Guild (server) configuration
    guilds = {
      "YOUR_GUILD_ID" = {
        requireMention = true;  # Bot only responds when @mentioned
        channels = {
          "general" = { allow = true; };
          "ai-chat" = { allow = true; requireMention = false; };
        };
      };
    };
  };
};
```

**Discord Setup Steps:**

1. Create Discord app at https://discord.com/developers/applications
2. Enable **Message Content Intent** + **Server Members Intent** in Bot settings
3. Generate invite URL with `bot` + `applications.commands` scopes
4. Copy bot token and provide during `clan vars generate`
5. Configure channels via `extraConfig` above

See [OpenClaw Discord docs](https://docs.openclaw.ai/channels/discord) for full options.

#### Telegram Channel

```nix
extraConfig.channels = {
  telegram = {
    enabled = true;
    allowFrom = [ "@username1" "@username2" ];
    # tokenFile = "/path/to/secret";
  };
};
```

### auth

```nix
extraConfig.auth = {
  profiles = {
    anthropic = {
      # apiKeyFile = "/path/to/secret";
      # Or use ANTHROPIC_API_KEY env var
    };
    openai = {
      # apiKeyFile = "/path/to/secret";
    };
  };
};
```

### tools

```nix
extraConfig.tools = {
  exec = {
    timeout = 300;
    security = "sandboxed";
  };
  allow = [ "read" "write" "exec" ];
  deny = [ "dangerous_tool" ];
};
```

## Network Requirements

- **User responsibility**: Ensure nodes can reach the gateway endpoint via DNS
- **Options**: WireGuard, Tailscale, public DNS, /etc/hosts, etc.
- **No hard dependency**: This service doesn't configure networking for you

## Service Details

### NixOS Gateway

- Runs as systemd service: `openclaw-gateway-<instance>`
- User: configurable (default: `openclaw`)
- State: `/var/lib/openclaw/`
- Logs: configurable (default: `/var/log/openclaw/gateway.log`)

### NixOS Node

- Runs as systemd service: `openclaw-node-<instance>`
- User: configurable (default: root)
- State: `/var/lib/openclaw-node/`
- Logs: configurable (default: `/var/log/openclaw/node.log`)

### Darwin Node

- Runs as launchd user agent: `com.openclaw.node.<instance>`
- User: current logged-in user
- State: `~/.openclaw-node/`
- Logs: `~/Library/Logs/openclaw-node-<instance>.log`

## Environment Variables

The service sets these environment variables (with legacy aliases):

| Variable                 | Description                                |
| ------------------------ | ------------------------------------------ |
| `OPENCLAW_NIX_MODE`      | Indicates Nix-managed installation         |
| `OPENCLAW_STATE_DIR`     | State directory path                       |
| `OPENCLAW_CONFIG_PATH`   | Config file path                           |
| `OPENCLAW_GATEWAY_TOKEN` | Authentication token                       |
| `OPENCLAW_IMAGE_BACKEND` | Image processing backend (Darwin: sips)    |
| `ANTHROPIC_API_KEY`      | Anthropic API key (from clan vars)         |
| `DISCORD_BOT_TOKEN`      | Discord bot token (from clan vars, if set) |
| `MOLTBOT_*`              | Legacy aliases (mirrored)                  |
| `CLAWDBOT_*`             | Legacy aliases (mirrored)                  |

## Related Projects

- [nix-openclaw](https://github.com/openclaw/nix-openclaw) - Nix packaging and home-manager module
- [clawdinators](https://github.com/openclaw/clawdinators) - Production reference implementation
- [nix-steipete-tools](https://github.com/openclaw/nix-steipete-tools) - Plugin tools (summarize, peekaboo, etc.)

## Notes

- Gateway must be reachable by nodes at the configured `gatewayEndpoint`
- Node pairing is auto-approved when connecting via the generated token
- Darwin nodes run as user-level launchd agents (not system daemons)
- NixOS nodes run as system-level systemd services
