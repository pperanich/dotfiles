---
name: clan-core
description: Use when managing NixOS infrastructure with clan-core, setting up distributed services (backups, networking, VPN), adding machines to roles, generating secrets/credentials, or scaling multi-machine deployments - provides declarative patterns for inventory, roles, tags, vars, and clan services instead of manual per-machine configuration
---

# Clan-Core Infrastructure Management

## Overview

**Clan-core** is a declarative infrastructure framework built on NixOS that manages fleets of machines through **inventory**, **roles**, **tags**, and **vars**. Instead of configuring each machine individually, you define services once and assign machines to roles.

**Core principle**: Define services at the fleet level, not the machine level. Machines participate in services through roles.

## When to Use

Use clan-core patterns when:

- Setting up multi-machine services (backups, VPN, monitoring)
- Managing distributed infrastructure with shared services
- Need declarative secret/credential generation
- Scaling from 2-100+ machines
- Team collaboration on infrastructure

**Don't use** for:

- Single standalone NixOS machine (use standard NixOS)
- Desktop configurations without fleet management
- When clan-core is not installed in the project

## Core Concepts

### 1. Inventory → Services Across Machines

Traditional NixOS configures each machine separately. Clan uses **inventory** to define services once:

```nix
# ❌ Traditional: Configure per-machine
machines/worker-1/configuration.nix:
  services.borgbackup.jobs.backup = { ... };
machines/worker-2/configuration.nix:
  services.borgbackup.jobs.backup = { ... };
# Repeat for all machines...

# ✅ Clan: Define service once, assign machines to roles
inventory.instances.borgbackup = {
  roles.client.tags = ["workers"];        # All worker machines
  roles.server.machines."backup-host" = {};
};

inventory.machines = {
  "worker-1".tags = ["workers"];
  "worker-2".tags = ["workers"];
  # Adding worker-3: just add it here with tag!
};
```

**Scaling**: Traditional approach requires editing N files. Clan requires editing 1 line.

### 2. Roles → Client/Server Patterns

Services define **roles** (e.g., `client`, `server`, `peer`). Machines participate through roles:

```nix
inventory.instances = {
  borgbackup = {
    # Server role: receives backups
    roles.server.machines."backup-host" = {
      settings.directory = "/var/lib/borgbackup";
    };

    # Client role: sends backups
    roles.client.machines."laptop" = {
      settings.backupFolders = [ /home /etc ];
    };
    roles.client.machines."workstation" = {
      settings.backupFolders = [ /home /var ];
    };
  };
};
```

**Pattern**: One machine can have different roles in different services (laptop is borgbackup client, wireguard peer, monitoring target).

### 3. Tags → Grouping for Scale

**Tags** group machines by function, eliminating repetition:

```nix
inventory = {
  machines = {
    "worker-1".tags = ["workers" "backup-targets"];
    "worker-2".tags = ["workers" "backup-targets"];
    "worker-3".tags = ["workers"];
    "web-1".tags = ["webservers" "backup-targets"];
    "web-2".tags = ["webservers" "backup-targets"];
    "backup-host" = {};  # No tags, special role
  };

  instances = {
    # Borgbackup: all backup-targets are clients
    borgbackup = {
      roles.client.tags = ["backup-targets"];
      roles.server.machines."backup-host" = {};
    };

    # Monitoring: all workers + webservers monitored
    prometheus = {
      roles.target.tags = ["workers" "webservers"];
      roles.server.machines."monitoring" = {};
    };
  };
};
```

**Common tag patterns**:

- `"all"`: Every machine (e.g., SSH configs, monitoring)
- `"servers"`, `"workers"`, `"webservers"`: By function
- `"backup-targets"`, `"vpn-clients"`: By service participation

### 4. Vars → Declarative Generation

**Vars** replace manual secret/credential generation with declarative generators:

```nix
# ❌ Traditional: Manual generation
# 1. Run: mkpasswd -m sha-512 > /tmp/hash
# 2. Copy hash into config
# 3. Commit hardcoded hash
# 4. Share secret separately via Slack/email

# ✅ Clan vars: Declarative generation
clan.core.vars.generators.root-password = {
  prompts.password = {
    description = "Root password";
    type = "hidden";  # Don't show while typing
  };
  files.hash.secret = false;  # Hash is not secret
  script = ''
    mkpasswd -m sha-512 < $prompts/password > $out/hash
  '';
  runtimeInputs = [ pkgs.mkpasswd ];
};

users.users.root.hashedPasswordFile =
  config.clan.core.vars.generators.root-password.files.hash.path;
```

**Generate**: `clan vars generate <machine>`
**Deploy**: `clan machines update <machine>` (automatically includes vars)

**Vars handle**:

- Password hashes
- SSH keys (host and user)
- TLS certificates
- API tokens
- WireGuard keys
- Database credentials

### 5. Clan Services → Pre-Built Modules

Clan ships with multi-host services. Use them instead of creating custom modules:

```nix
# ❌ Don't create custom modules for common services
modules/borgbackup-server.nix
modules/borgbackup-client.nix

# ✅ Use clan's built-in borgbackup service
inventory.instances.borgbackup = {
  module.name = "borgbackup";  # Optional, defaults to instance name
  module.input = "clan-core";  # Optional, defaults to clan-core

  roles.client.tags = ["workers"];
  roles.server.machines."backup-host" = {};
};
```

**Available clan services**: borgbackup, syncthing, monitoring, networking, and more. See [clan services reference](https://docs.clan.lol/services/definition).

## Quick Reference

| Task                                | Traditional NixOS           | Clan-Core                                        |
| ----------------------------------- | --------------------------- | ------------------------------------------------ |
| **Add service to 5 machines**       | Edit 5 machine configs      | Add tag to machines, use `roles.<role>.tags`     |
| **Generate password**               | `mkpasswd` → copy to config | `clan.core.vars.generators.<name>` → auto-deploy |
| **Distributed service**             | Custom modules per role     | `inventory.instances.<service>` with roles       |
| **Scale to 50 machines**            | Edit 50 files               | Add machines to tags                             |
| **Share secrets in team**           | Manual via Slack/1Password  | `clan secrets` with sops integration             |
| **Add machine to existing service** | Copy config, modify, test   | Add to tag or role, rebuild                      |

## Common Patterns

### Pattern: Fleet-Wide Backup

```nix
{
  inventory = {
    machines = {
      "laptop".tags = ["all"];
      "workstation".tags = ["all"];
      "server-1".tags = ["all"];
      "backup-host" = {};
    };

    instances.borgbackup = {
      roles.client.tags = ["all"];
      roles.server.machines."backup-host" = {};

      # Per-role settings
      roles.client.settings = {
        backupFolders = [ /home /etc ];
      };

      # Per-machine override
      roles.client.machines."server-1".settings = {
        backupFolders = [ /home /etc /var/lib/postgresql ];
      };
    };
  };
}
```

### Pattern: User Password with Vars

```nix
{
  clan.core.vars.generators.alice-password = {
    prompts.password.description = "Password for alice";
    prompts.password.type = "hidden";
    files.hash.secret = false;
    script = ''
      mkpasswd -m sha-512 < $prompts/password > $out/hash
    '';
    runtimeInputs = [ pkgs.mkpasswd ];
  };

  users.users.alice = {
    isNormalUser = true;
    hashedPasswordFile =
      config.clan.core.vars.generators.alice-password.files.hash.path;
  };
}
```

### Pattern: WireGuard VPN with Generated Keys

```nix
{
  inventory.instances.wireguard-vpn = {
    roles.peer.tags = ["all"];
    roles.server.machines."vpn-hub" = {};
  };

  # Keys generated automatically via vars
  # No manual `wg genkey` needed
}
```

## Workflow

### Creating New Clan

```bash
# 1. Create from template
nix run "https://git.clan.lol/clan/clan-core/archive/main.tar.gz#clan-cli" \
  -- flakes create

# 2. Choose template
# - default: Standard clan
# - flake-parts: With flake-parts organization
# - minimal: GUI-managed

# 3. Activate environment
cd my-clan
direnv allow  # or: nix develop

# 4. Verify setup
clan show
```

### Adding Machines

```bash
# 1. Add machine to clan
clan machines create <machine-name>

# 2. Add to inventory (in clan.nix or inventory.nix)
inventory.machines.<machine-name>.tags = ["workers" "backup-targets"];

# 3. Assign to service roles
inventory.instances.<service>.roles.<role>.machines.<machine-name> = {};
# Or via tags:
inventory.instances.<service>.roles.<role>.tags = ["workers"];
```

### Deploying

```bash
# Generate vars (secrets, keys, credentials)
clan vars generate <machine>

# Deploy to machine
clan machines update <machine>

# Or deploy to physical/cloud machine (first time)
clan machines install <machine> \
  --target-host root@<IP> \
  --update-hardware-config nixos-facter
```

## Common Mistakes

| Mistake                            | Why Wrong                          | Fix                                  |
| ---------------------------------- | ---------------------------------- | ------------------------------------ |
| Creating custom borgbackup modules | Clan has built-in service          | Use `inventory.instances.borgbackup` |
| Manually running `mkpasswd`        | Not declarative, not team-friendly | Use `clan.core.vars.generators`      |
| Per-machine service config         | Doesn't scale                      | Use inventory with roles/tags        |
| Hardcoded secrets in config        | Security risk, not collaborative   | Use `clan secrets` and vars          |
| Not using tags                     | Repetitive machine lists           | Group machines by function with tags |
| Configuring machines individually  | High maintenance                   | Configure at service level via roles |

## Common Rationalizations (STOP and Use Clan Patterns)

If you catch yourself thinking these thoughts, STOP. Use clan patterns instead:

| Rationalization                              | Reality                                                                | What to Do                                                    |
| -------------------------------------------- | ---------------------------------------------------------------------- | ------------------------------------------------------------- |
| "Too simple for inventory"                   | Even 2-machine services benefit from roles. You'll add machines later. | Always use inventory for multi-machine services               |
| "Just this one machine needs X"              | "Just one" becomes "just five" becomes unmaintainable.                 | Use inventory with per-machine settings override              |
| "User said quick, so I'll skip declarative"  | Declarative IS quicker. Manual = 30 min/machine. Clan = 2 min.         | "Quick" means use clan patterns, not skip them                |
| "I don't know inventory syntax"              | The skill shows examples. Copy them.                                   | Read the patterns section, adapt examples                     |
| "Tags are overkill for 2 machines"           | You'll add machine #3 next week. Plan for scale now.                   | Use tags even for 2 machines                                  |
| "I'll configure directly in machine files"   | That's traditional NixOS, not clan. You lose all clan benefits.        | Always use inventory for distributed services                 |
| "Manual is fine for secrets I generate once" | "Once" becomes "rotating" becomes "new team member".                   | Use vars for ALL generated secrets                            |
| "Creating a module is more flexible"         | Clan services are parameterized. You lose team's service improvements. | Check clan services first, use `extraModules` if truly custom |

**If you're about to configure services in individual machine files, you're doing it wrong.** Use inventory.

## Decision Tree

```
Need to configure infrastructure?
├─ Single machine?
│  └─ Use standard NixOS (no clan needed)
├─ Multi-machine service (backup, VPN, monitoring)?
│  ├─ Service spans machine boundaries? → Use inventory.instances
│  ├─ Need roles (client/server)? → Define roles in inventory
│  ├─ Many machines same role? → Use tags
│  └─ Need secrets/keys? → Use vars generators
└─ Scaling existing service?
   └─ Add machines to tags, not individual configs
```

## Integration with Other Tools

Clan integrates with:

- **sops-nix**: Encrypted secrets (automatic with vars)
- **nixos-anywhere**: Remote machine installation
- **disko**: Declarative disk management
- **nixos-facter**: Hardware detection

## Tips

1. **Start with tags**: Plan machine groupings before configuring services
1. **Use "all" tag**: For services every machine needs (monitoring, SSH)
1. **Per-role then per-machine**: Set defaults in `roles.<role>.settings`, override in `roles.<role>.machines.<name>.settings`
1. **Vars for all secrets**: Even if you think you'll only generate once
1. **Check clan services first**: Before writing custom modules
1. **Templates for new projects**: Don't manually create flake structure

## Real-World Impact

**Without clan** (traditional NixOS):

- Adding machine to backup: Edit server config, client config, generate keys, copy keys, test
- Time: 30+ minutes per machine
- Scaling to 20 machines: Prohibitive maintenance burden

**With clan**:

- Adding machine to backup: Add machine to "backup-targets" tag
- Time: 1 line of code
- Scaling to 100 machines: Same 1 line per machine, roles handle the rest

## Further Reading

Clan documentation locations:

- `~/Documents/repos/oss/clan-core/docs/site/`
- Inventory guide: `guides/inventory/inventory.md`
- Vars guide: `guides/vars/vars-overview.md`
- Services: `services/definition.md`
- Templates: `concepts/templates.md`
