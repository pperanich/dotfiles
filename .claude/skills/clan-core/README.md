# Clan-Core Skill

A comprehensive skill for managing NixOS infrastructure with clan-core's declarative patterns.

## Overview

This skill teaches Claude Code how to work with **clan-core**, a declarative infrastructure framework built on NixOS. Instead of configuring each machine individually, clan-core manages fleets through **inventory**, **roles**, **tags**, and **vars**.

## What This Skill Covers

### Core Concepts

- **Inventory**: Define services once, assign machines to roles
- **Roles**: Client/server patterns for distributed services (e.g., borgbackup client/server)
- **Tags**: Group machines by function for scalable configuration
- **Vars**: Declarative secret and credential generation
- **Clan Services**: Pre-built multi-host services

### Common Workflows

- Setting up distributed services (backups, VPN, monitoring)
- Managing secrets and credentials declaratively
- Scaling from 2 to 100+ machines
- Team collaboration on infrastructure
- Adding machines to existing services

## When to Use

Use this skill when:

- Managing multiple NixOS machines with shared services
- Setting up borgbackup, wireguard, or other distributed services
- Need declarative password/key generation
- Scaling infrastructure (avoid per-machine config duplication)
- Working with clan-core projects

Don't use for:

- Single standalone NixOS machines (use standard NixOS patterns)
- Desktop configurations without fleet management
- Projects that don't use clan-core

## Key Patterns Taught

### Pattern 1: Fleet-Wide Services with Tags

```nix
inventory = {
  machines = {
    "worker-1".tags = ["workers" "backup-clients"];
    "worker-2".tags = ["workers" "backup-clients"];
    "backup-host" = {};
  };

  instances.borgbackup = {
    roles.client.tags = ["backup-clients"];  # All tagged machines
    roles.server.machines."backup-host" = {};
  };
};
```

Adding worker-3? Just add one line:

```nix
"worker-3".tags = ["workers" "backup-clients"];
```

### Pattern 2: Declarative Secret Generation

```nix
clan.core.vars.generators.alice-password = {
  prompts.password.description = "Password for alice";
  prompts.password.type = "hidden";
  files.hash.secret = false;
  script = ''
    mkpasswd -m sha-512 < $prompts/password > $out/hash
  '';
  runtimeInputs = [ pkgs.mkpasswd ];
};

users.users.alice.hashedPasswordFile =
  config.clan.core.vars.generators.alice-password.files.hash.path;
```

Then: `clan vars generate <machine>` - no manual password management!

## Development Process (TDD)

This skill was created following the **writing-skills** TDD methodology:

### RED Phase: Baseline Testing

- Created pressure scenarios simulating real use cases
- Ran tests WITHOUT skill to document natural agent behavior
- Identified failure patterns:
  - Manual `mkpasswd` commands instead of vars
  - Custom modules instead of clan services
  - Per-machine configs instead of inventory
  - No use of roles/tags for grouping

### GREEN Phase: Minimal Skill

- Wrote skill addressing specific baseline failures
- Focused on:
  - Inventory patterns with roles and tags
  - Vars for declarative generation
  - Built-in clan services
  - Scaling patterns

### REFACTOR Phase: Bulletproofing

- Added "Common Rationalizations" table
- Addressed pressure scenarios:
  - "Too simple for inventory" (only 2 machines)
  - "User said quick" (time pressure)
  - "I don't know the syntax" (lack of examples)
- All tests passed with skill present

## Test Results

✅ **Scenario 1**: User password with declarative generation
✅ **Scenario 2**: Multi-machine backup with inventory/roles/tags
✅ **Scenario 3**: Rationalization resistance under pressure

See `TESTING_RESULTS.md` for detailed test outcomes.

## Files

- **SKILL.md**: Main skill documentation (~550 lines)
- **TESTING_RESULTS.md**: Detailed test results and scenarios
- **clan-baseline-scenarios.md**: Test scenarios used for development

## Integration

This skill is registered in the `nix-skills` plugin in your custom skills marketplace:

```json
{
  "name": "nix-skills",
  "skills": ["./dendritic-nix", "./clan-core"]
}
```

It works alongside your existing `dendritic-nix` skill, which briefly mentions clan-core integration.

## Local Documentation

The skill references your local clan-core documentation at:
`~/Documents/repos/oss/clan-core/docs/site/`

This provides detailed reference for:

- Inventory guide: `guides/inventory/inventory.md`
- Vars guide: `guides/vars/vars-overview.md`
- Services: `services/definition.md`
- Templates: `concepts/templates.md`

## Usage

When working on clan-core projects, Claude will automatically detect when this skill applies based on:

- Keywords: "clan", "inventory", "distributed services", "borgbackup", "vars"
- Context: Multi-machine NixOS infrastructure
- File patterns: `clan.nix`, `inventory.nix`, clan flake structure

The skill provides:

- Quick reference tables for common operations
- Decision trees for choosing patterns
- Before/after comparisons (traditional vs. clan)
- Common mistakes and how to fix them
- Rationalization resistance for pressure scenarios

## Benefits

**For you:**

- Consistent clan-core patterns across all agent sessions
- No more manual secret management explanations
- Automatic use of inventory/roles/tags for scale
- Faster infrastructure changes (minutes vs. hours)

**For the agent:**

- Clear patterns for multi-machine services
- Examples to copy and adapt
- Explicit rationalization counters
- Searchable documentation

## Next Steps

1. The skill is now registered and ready to use
1. Claude will automatically load it when working with clan-core
1. Test it on your actual clan infrastructure
1. Update skill based on real-world usage patterns

## Contributing

If you find patterns that agents still miss, follow the TDD cycle:

1. Document the failure scenario
1. Run baseline test without skill updates
1. Add pattern/example to SKILL.md
1. Re-test to verify compliance
1. Update TESTING_RESULTS.md

---

**Skill Status**: ✅ Complete and tested
**Last Updated**: 2025-11-05
**Version**: 1.0
