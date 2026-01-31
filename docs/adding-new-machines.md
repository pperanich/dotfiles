# Adding New Machines to Clan

This guide covers adding a new machine to the clan-managed infrastructure and configuring secrets.

## Prerequisites

- Access to an admin workstation with the clan CLI and age key (`~/.config/sops/age/keys.txt`)
- SSH access to the target machine (for NixOS) or local access (for Darwin)
- The machine's hostname decided (following naming convention)

## Machine Naming Convention

```
{prefix}-{os}{type}{num}   # General-purpose machines
{prefix}-{role}{num}       # Dedicated-role machines
```

| Component  | Options                                            |
| ---------- | -------------------------------------------------- |
| **Prefix** | `pp` (personal), `peranpl1` (work)                 |
| **OS**     | `l` (Linux/NixOS), `m` (macOS/Darwin), `wsl` (WSL) |
| **Type**   | `l` (laptop), `d` (desktop)                        |
| **Role**   | `nas`, `rpi`, `router`, etc.                       |

Examples: `pp-ll1` (personal Linux laptop), `pp-nas1` (personal NAS), `peranpl1-ml2` (work Mac laptop)

## Step 1: Create Machine Configuration

### For NixOS Machines

```bash
mkdir -p machines/<hostname>
```

Create `machines/<hostname>/configuration.nix`:

```nix
{
  config,
  lib,
  pkgs,
  modules,
  ...
}:
{
  imports = [ ] ++ (with modules.nixos; [
    base
    # Add other modules as needed
  ]);

  networking.hostName = "<hostname>";

  # Machine-specific configuration here
}
```

For physical machines, generate hardware configuration:

```bash
# On the target machine:
nixos-generate-config --show-hardware-config > hardware-configuration.nix

# Or use nixos-facter for more detailed config:
nix run nixpkgs#nixos-facter -- -o facter.json
```

### For Darwin Machines

Create `machines/<hostname>/configuration.nix`:

```nix
{
  config,
  lib,
  pkgs,
  modules,
  ...
}:
{
  imports = [ ] ++ (with modules.darwin; [
    base
    # Add other modules as needed
  ]);

  networking.hostName = "<hostname>";

  # Machine-specific configuration here
}
```

## Step 2: Add Machine to Clan Inventory

Edit `modules/flake-parts/clan.nix`:

```nix
inventory = {
  machines = {
    # ... existing machines ...

    "<hostname>" = {
      machineClass = "nixos";  # or "darwin"
      tags = [
        "laptop"  # or "desktop", "server", etc.
        "nixos"   # or "darwin"
        "all"
      ];
    };
  };

  # Add to any relevant service instances
  instances = {
    # Example: add to wireguard
    wireguard-home.roles.peer.machines."<hostname>" = { };

    # Example: add to syncthing
    syncthing.roles.peer.machines."<hostname>" = { };
  };
};
```

## Step 3: Generate Machine Secrets

From your admin workstation:

```bash
# Generate all vars for the new machine
clan vars generate <hostname>

# This creates:
# - sops/secrets/<hostname>-age.key/secret (machine's age private key)
# - sops/machines/<hostname>/key.json (machine's age public key)
# - vars/per-machine/<hostname>/ (machine-specific vars)
```

For machines with user passwords, you may be prompted interactively.

## Step 4: Add Machine to secrets.yaml Recipients

Edit `sops/.sops.yaml` to add the machine's key:

```yaml
keys:
  - &hosts "":
      # ... existing hosts ...
      - &<hostname> <age-public-key-from-key.json>

creation_rules:
  - path_regex: secrets.yaml$
    key_groups:
      - age:
          # ... existing recipients ...
          - *<hostname>
```

Get the public key:

```bash
cat sops/machines/<hostname>/key.json | grep publickey
```

Re-encrypt secrets.yaml:

```bash
cd sops && nix shell nixpkgs#sops nixpkgs#age-plugin-yubikey -c sops updatekeys secrets.yaml
```

## Step 5: Enable Machine Self-Upload (Optional)

By default, only admin workstations can run `clan vars upload`. To enable a machine to upload its own secrets:

```bash
# Add machine as recipient to its own age.key secret
clan secrets machines add-secret <hostname> <hostname>-age.key

# Re-encrypt with machine included
clan secrets get <hostname>-age.key | \
  clan secrets set <hostname>-age.key --machine <hostname> --user pperanich-pperanich-ml1
```

## Step 6: Initial Deployment

### For NixOS (New Installation)

```bash
# Build installation media or use existing NixOS
# Then from admin workstation:

# Upload secrets to the machine
clan vars upload <hostname>

# Deploy configuration
clan machines update <hostname>
```

### For NixOS (Existing System)

```bash
# Upload secrets
clan vars upload <hostname>

# Deploy
clan machines update <hostname>

# Or manually on the machine:
sudo nixos-rebuild switch --flake /path/to/dotfiles#<hostname>
```

### For Darwin

```bash
# Upload secrets (from admin workstation)
clan vars upload <hostname>

# On the Darwin machine:
darwin-rebuild switch --flake /path/to/dotfiles#<hostname>
```

## Step 7: Configure Self-Upload on Machine

After initial deployment, if you enabled self-upload in Step 5:

```bash
# On the target machine, copy the deployed key to SOPS search path
sudo cat /var/lib/sops-nix/key.txt > ~/.config/sops/age/keys.txt
chmod 600 ~/.config/sops/age/keys.txt

# Add machine's host key to its own known_hosts (for NixOS self-SSH)
ssh-keyscan -H $(hostname -I | awk '{print $1}') >> ~/.ssh/known_hosts

# Verify self-upload works
cd ~/dotfiles && git pull
clan vars upload <hostname>
```

## Quick Reference Commands

```bash
# Generate vars for a machine
clan vars generate <hostname>

# Regenerate specific generator
clan vars generate <hostname> --generator openssh --regenerate

# Upload secrets to machine
clan vars upload <hostname>

# List machine vars
clan vars list <hostname>

# Check vars health
clan vars check <hostname>

# Fix vars encryption
clan vars fix <hostname>

# Deploy machine
clan machines update <hostname>

# List all machines
clan machines list

# Add machine to a secret
clan secrets machines add-secret <hostname> <secret-name>

# Get machine's public key
clan secrets machines get <hostname>
```

## Troubleshooting

### "Host key verification failed"

The machine needs its own IP in known_hosts for self-SSH:

```bash
ssh root@<machine-ip> "ssh-keyscan -H <machine-ip> >> ~/.ssh/known_hosts"
```

### SOPS decryption failures

Check that the machine's key matches what's in the repo:

```bash
# On machine: get actual key
ssh root@<ip> "nix-shell -p age --run 'age-keygen -y /var/lib/sops-nix/key.txt'"

# In repo: check registered key
cat sops/machines/<hostname>/key.json
```

If they don't match, see [clan-machines-update-troubleshooting.md](./clan-machines-update-troubleshooting.md).

### "clan vars upload" fails on target machine

The machine isn't a recipient of its own age.key secret. Either:

1. Run from admin workstation instead
2. Follow Step 5 to enable self-upload

## Architecture Overview

```
sops/
├── .sops.yaml                    # Traditional sops-nix config (for secrets.yaml)
├── secrets.yaml                  # App secrets (tailscale, borg, etc.)
├── machines/<hostname>/
│   └── key.json                  # Machine's age PUBLIC key
└── secrets/<hostname>-age.key/
    ├── secret                    # Machine's age PRIVATE key (encrypted)
    ├── machines/<hostname>       # Symlink if machine can self-decrypt
    └── users/pperanich-...       # Symlink to admin user

vars/
├── per-machine/<hostname>/       # Machine-specific vars
│   ├── openssh/                  # SSH host keys
│   ├── emergency-access/         # Emergency passwords
│   └── syncthing/               # Service-specific vars
└── shared/                       # Vars shared across machines
    └── user-password-*/          # User passwords
```

## Key Concepts

| Concept                | Description                                                    |
| ---------------------- | -------------------------------------------------------------- |
| **Clan-generated key** | Age keypair created by `age-keygen`, stored encrypted in repo  |
| **Machine key.json**   | Public key used to encrypt secrets FOR this machine            |
| **age.key secret**     | Encrypted private key, uploaded to `/var/lib/sops-nix/key.txt` |
| **Self-upload**        | Machine can decrypt its own age.key to run `clan vars upload`  |
| **Admin upload**       | Admin workstation decrypts age.key and uploads to machine      |
