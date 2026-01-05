# Clan-Core Baseline Testing Scenarios

These scenarios test whether agents naturally follow clan-core's declarative patterns without explicit guidance.

## Scenario 1: Multi-Machine Backup Setup

**Pressure types**: Time (quick setup needed), Complexity (5+ machines)

**Prompt**:
"I need to set up borgbackup for my infrastructure. I have 5 worker machines (worker-1 through worker-5) and one backup server (backup-host). All workers should back up to the backup server. I need this working quickly. The clan flake structure already exists."

**What we're testing**:

- Will they use inventory with roles (client/server)?
- Will they use tags to group machines efficiently?
- Will they configure per-role vs per-machine?

**Expected failures WITHOUT skill**:

- Manual per-machine configuration instead of tags
- Missing inventory.instances structure
- Not understanding client vs server roles
- Trying to configure in machine files instead of inventory

______________________________________________________________________

## Scenario 2: User Password with Secrets

**Pressure types**: Exhaustion (end of long session), Authority (security best practices)

**Prompt**:
"Add a new admin user 'alice' to machine 'prod-1' with a secure password. Make sure it follows security best practices and can be managed across the team."

**What we're testing**:

- Will they use vars for declarative password generation?
- Will they manually create password hash and put it in config?
- Will they understand vars vs secrets distinction?

**Expected failures WITHOUT skill**:

- Manual mkpasswd command with copy-paste
- Hardcoding hash in configuration
- Not using vars generators
- Not understanding collaborative secrets management

______________________________________________________________________

## Scenario 3: New Clan from Scratch

**Pressure types**: Sunk cost (already started), Time (quick deliverable)

**Prompt**:
"I need to create a new clan project for managing my homelab. I have 3 machines total. I want to use flake-parts for organization. Set this up for me."

**What we're testing**:

- Will they use `clan flakes create --template`?
- Will they manually create flake.nix structure?
- Will they know about templates?

**Expected failures WITHOUT skill**:

- Manually writing flake.nix from scratch
- Not using built-in templates
- Missing clan.nix structure
- Not activating environment (direnv/nix develop)

______________________________________________________________________

## Scenario 4: Distributed Service with Secrets

**Pressure types**: Complexity (multi-host), Security (secrets), Time

**Prompt**:
"Set up a wireguard VPN service across 4 machines: vpn-hub should be the server, and laptop, desktop, and phone should be clients. Generate all necessary keys and credentials."

**What we're testing**:

- Will they use inventory.instances with roles?
- Will they use vars for key generation?
- Will they understand role-based configuration?
- Will they use tags for grouping clients?

**Expected failures WITHOUT skill**:

- Manual key generation with wg genkey
- Per-machine configuration files
- Not using inventory abstraction
- Manually copying keys around
- Not using vars generators for wireguard keys

______________________________________________________________________

## Scenario 5: Scaling Existing Service

**Pressure types**: Existing system (modification fear), Time, Scale

**Prompt**:
"I already have borgbackup configured for 2 machines. Now I need to add 8 more worker machines (worker-3 through worker-10) to back up to the same server. What's the fastest way to do this?"

**What we're testing**:

- Will they discover/use tags for scaling?
- Will they copy-paste machine entries?
- Will they understand inventory patterns for scale?

**Expected failures WITHOUT skill**:

- Manually adding each machine to roles.client.machines
- Not refactoring to use tags
- Missing the "all" tag pattern
- Not understanding how inventory scales
