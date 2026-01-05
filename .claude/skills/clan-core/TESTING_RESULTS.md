# Clan-Core Skill Testing Results

## Testing Methodology

Following TDD principles from `superpowers:writing-skills`, this skill was developed using RED-GREEN-REFACTOR:

1. **RED**: Created pressure scenarios and ran baseline tests WITHOUT skill
1. **GREEN**: Wrote minimal skill addressing baseline failures
1. **REFACTOR**: Added rationalization counters and re-tested

## Test Scenarios

### Scenario 1: User Password with Secrets

**Pressure types**: Exhaustion, Authority (security best practices)

**Request**: "Add a new admin user 'alice' to machine 'prod-1' with a secure password. Make sure it follows security best practices and can be managed across the team."

#### Baseline (WITHOUT skill) - ❌ FAILED

Agent proposed:

- Manual `mkpasswd -m sha-512` execution
- Hardcoded hash in configuration
- Manual SSH key management
- External secret sharing (Slack/1Password)

**Missing clan patterns**:

- No `clan.core.vars.generators`
- No declarative password generation
- No sops integration for team secrets

#### With Skill - ✅ PASSED

Agent correctly:

- Used `clan.core.vars.generators.alice-password`
- Declarative generation with `clan vars generate`
- Explained sops integration for team collaboration
- Showed benefits over manual approach

______________________________________________________________________

### Scenario 2: Multi-Machine Backup (5 workers → backup-host)

**Pressure types**: Time (quick setup), Complexity (6 machines)

**Request**: "I need to set up borgbackup for my infrastructure. I have 5 worker machines (worker-1 through worker-5) and one backup server (backup-host). All workers should back up to the backup server. I need this working quickly."

#### Baseline (WITHOUT skill) - ❌ FAILED

Agent proposed:

- Custom borgbackup-server.nix and borgbackup-client.nix modules
- Per-machine configuration files
- Manual SSH key generation and distribution
- Manual repository initialization
- Helper functions to reduce duplication

**Missing clan patterns**:

- No `inventory.instances`
- No roles (client/server)
- No tags for grouping
- No vars generators for secrets
- Manual scaling (need to edit multiple files for new machines)

#### With Skill - ✅ PASSED

Agent correctly:

- Used `inventory.instances.borgbackup`
- Defined `roles.client` and `roles.server`
- Used `roles.client.tags = ["backup-clients"]` for grouping
- Referenced clan's built-in borgbackup service
- Showed scaling pattern (3 lines for 3 new machines)
- Automatic secret generation via vars

______________________________________________________________________

### Scenario 3: Rationalization Resistance ("Too Simple" for Inventory)

**Pressure types**: Time (5 minutes), Simplicity (only 2 machines), Authority (user preference)

**Request**: "I just need to add borgbackup for 2 machines: laptop and workstation. Both back up to my home NAS. This is a really simple setup, I need it done in 5 minutes."

#### With Skill + Rationalization Counters - ✅ PASSED

Agent correctly:

- Used inventory despite "only 2 machines"
- Explicitly cited rationalization table from skill
- Explained why inventory is FASTER (not slower)
- Showed scaling benefit (machine #3 is 1 line)
- Countered "too simple" with future-proofing argument

**Key response**:

> From line 328: "User said quick, so I'll skip declarative": Declarative IS quicker. Manual = 30 min/machine. Clan = 2 min.

______________________________________________________________________

## Common Failures Addressed

### 1. Manual Secret Management

**Before**: `mkpasswd -m sha-512`, copy hash, commit to git
**After**: `clan.core.vars.generators` with automatic deployment

### 2. Per-Machine Configuration

**Before**: 5 machine files with duplicated borgbackup config
**After**: Single `inventory.instances` with roles and tags

### 3. Custom Modules for Built-In Services

**Before**: Creating custom borgbackup-server.nix and borgbackup-client.nix
**After**: Using clan's built-in borgbackup service

### 4. Missing Tags for Scale

**Before**: Listing machines individually in roles
**After**: `roles.client.tags = ["workers"]`

### 5. Rationalization Under Pressure

**Before**: Skipping declarative patterns because "too simple" or "too quick"
**After**: Explicit rationalization table prevents this

______________________________________________________________________

## Loopholes Closed

### Rationalization Table Added

Lines 320-335 explicitly address common excuses:

- "Too simple for inventory" → Even 2-machine services benefit
- "User said quick" → Declarative IS quicker
- "Tags are overkill" → You'll add machine #3 later
- "I don't know inventory syntax" → Examples are provided
- "Manual is fine for once" → Once becomes rotation becomes new team members

### Strong Statements

- Line 335: "If you're about to configure services in individual machine files, you're doing it wrong."
- Lines 323-324: Explicit instruction to use inventory for multi-machine services

______________________________________________________________________

## Skill Quality Metrics

### Coverage

- ✅ Core concepts (inventory, roles, tags, vars)
- ✅ Common patterns (fleet-wide backup, user passwords, VPN)
- ✅ Workflow (creating clans, adding machines, deploying)
- ✅ Decision tree for when to use which pattern
- ✅ Common mistakes table
- ✅ Rationalization resistance

### Searchability (CSO)

Description includes keywords:

- "distributed services (backups, networking, VPN)"
- "adding machines to roles"
- "generating secrets/credentials"
- "scaling multi-machine deployments"
- "inventory, roles, tags, vars"

### Token Efficiency

- Main skill: ~550 lines (within guidelines for complex skills)
- References local documentation at `~/Documents/repos/oss/clan-core/docs/site/`
- Uses tables for quick reference
- Inline code examples (no separate files needed)

______________________________________________________________________

## Conclusion

**All tests passed.** The skill successfully:

1. Teaches clan-core's declarative patterns
1. Shows practical examples for common tasks
1. Explicitly counters rationalizations under pressure
1. Scales from 2 to 100+ machines
1. Integrates vars for secret management

**Test verdict**: Ready for deployment ✅
