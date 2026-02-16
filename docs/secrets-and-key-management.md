# Secrets and Key Management

This document explains how secrets and age keys work in this clan-managed infrastructure, including the distinction between machine keys and user keys, and common anti-patterns to avoid.

## Key Concepts

### Two Types of Age Keys

| Key Type        | Location                                 | Purpose                                                       | Managed By                   |
| --------------- | ---------------------------------------- | ------------------------------------------------------------- | ---------------------------- |
| **Machine Key** | `/var/lib/sops-nix/key.txt`              | Decrypt secrets deployed TO this machine at boot/activation   | clan-core + sops-nix         |
| **User Key**    | `~/.config/sops/age/keys.txt` or SSH key | User identity for running `clan vars upload`, editing secrets | User (manual or SSH-derived) |

### Machine Keys

Machine keys are automatically generated and managed by clan-core:

```bash
# Generate machine age key (creates keypair, stores in vars/)
clan vars generate <hostname>

# Upload machine key to the machine
clan vars upload <hostname>
```

The machine's age key is:

- Stored encrypted in `sops/secrets/<hostname>-age.key/secret`
- Deployed to `/var/lib/sops-nix/key.txt` on the target machine
- Used by sops-nix to decrypt system-level secrets at activation time
- Owned by `root:root` with mode `0400`

### User Keys

User keys represent a person's identity. There are two approaches:

#### Option 1: SSH-Derived Key (Recommended)

Your SSH ed25519 key can be used as an age key. This is the simplest approach:

```bash
# Convert SSH public key to age format
cat ~/.ssh/id_ed25519.pub | ssh-to-age
# or: nix run nixpkgs#ssh-to-age -- < ~/.ssh/id_ed25519.pub
```

**Advantages:**

- No separate key to manage
- SSH key already synced across machines (via sops)
- sops-nix automatically imports SSH keys as age keys

#### Option 2: Standalone Age Key

A dedicated age key at `~/.config/sops/age/keys.txt`:

```bash
# Generate standalone age key
age-keygen -o ~/.config/sops/age/keys.txt

# Or via clan
clan secrets key generate
```

**When to use:**

- Hardware security keys (YubiKey via age-plugin-yubikey)
- If you need a key independent of your SSH key
- Legacy setups (not recommended for new configurations)

## How Secrets Are Encrypted

Secrets in `sops/secrets.yaml` are encrypted for multiple recipients defined in `sops/.sops.yaml`:

```yaml
creation_rules:
  - path_regex: secrets.yaml$
    key_groups:
      - age:
          # Admin users (can edit secrets)
          - *pperanich           # SSH-derived age key
          - *pperanich-pperanich-ml1  # Standalone age key
          # Machine keys (can decrypt at runtime)
          - *pp-ll1
          - *pp-nas1
          - *pp-router1
```

**Key insight:** A secret can be decrypted by ANY key in the recipient list. This means:

- Machines can decrypt secrets deployed to them (via machine key)
- Users can decrypt secrets to edit them (via user key)

## This Repository's Configuration

### SSH Key Deployment (Breaking the Chicken-and-Egg)

The SSH private key is deployed via **system-level sops** in user modules, which runs BEFORE home-manager. This is done identically on both NixOS and Darwin:

```nix
# modules/users/pperanich.nix (NixOS)
sops.secrets."private_keys/pperanich" = {
  sopsFile = "${sopsFolder}/secrets.yaml";
  owner = "pperanich";
  group = "users";  # "staff" on Darwin
  mode = "0400";
  path = "/home/pperanich/.ssh/id_ed25519";  # /Users/... on Darwin
};
```

### Home-Manager Sops Configuration

Home-manager sops uses the **SSH key** (already deployed by system-level sops) on both platforms:

```nix
# modules/system/sops.nix
sops.age = {
  # Use SSH key for decryption (converted to age key automatically)
  sshKeyPaths = [
    "${config.home.homeDirectory}/.ssh/id_ed25519"
  ];
};
```

### Why This Works

```
┌─────────────────────────────────────────────────────────────┐
│  1. System activation starts                                │
│                          ↓                                  │
│  2. System sops decrypts using MACHINE key                  │
│     (/var/lib/sops-nix/key.txt)                             │
│                          ↓                                  │
│  3. SSH private key deployed to ~/.ssh/id_ed25519           │
│                          ↓                                  │
│  4. Home-manager activation starts                          │
│                          ↓                                  │
│  5. Home-manager sops uses SSH key to decrypt API keys      │
│                          ↓                                  │
│  ✅ No chicken-and-egg!                                     │
└─────────────────────────────────────────────────────────────┘
```

**Key insight:** System-level sops uses the machine key (which is always available), and deploys the SSH key first. Then home-manager sops can use the SSH key for everything else.

**No separate `~/.config/sops/age/keys.txt` needed** - the SSH key serves as the user's age key on all platforms.

## Registering User Keys with Clan

User public keys are registered in `sops/users/<username>/key.json`:

```bash
# Show current key
clan secrets users get <username>

# Register/update user key (use SSH-derived key)
SSH_AGE_KEY=$(cat ~/.ssh/id_ed25519.pub | ssh-to-age)
clan secrets users add <username> $SSH_AGE_KEY --force
```

**Important:** The registered key should match the key you actually have. If they're mismatched:

- You won't be able to decrypt secrets encrypted for "you"
- `clan vars upload` may fail

### Verifying Key Alignment

```bash
# Your local key (what you can actually use)
clan secrets key show

# Registered user key (what's in the repo)
clan secrets users get <username>

# SSH key converted to age (should match if using SSH-derived)
cat ~/.ssh/id_ed25519.pub | ssh-to-age
```

All three should produce the same public key for SSH-derived setups.

## Anti-Patterns to Avoid

### 1. Copying Machine Key to User Directory

**Wrong:**

```bash
# DON'T DO THIS
sudo cat /var/lib/sops-nix/key.txt > ~/.config/sops/age/keys.txt
```

**Why it's wrong:**

- Blurs the distinction between machine identity and user identity
- Machine keys are for system-level decryption, not user operations
- If machine key is rotated, user config breaks

**Correct approach:** Use SSH-derived key or standalone user key.

### 2. Running `clan vars upload` from Target Machine

**Wrong:**

```bash
# On pp-ll1, trying to upload to itself
clan vars upload pp-ll1
```

**Why it's problematic:**

- Requires root SSH access to self (extra setup)
- The machine's age key is for RECEIVING secrets, not SENDING
- Creates confusion about key ownership

**Correct approach:** Run `clan vars upload` from your admin workstation (Mac) where you have your personal key.

### 3. Multiple Mismatched Keys for Same User

**Wrong:** Having different keys in:

- `~/.config/sops/age/keys.txt` (standalone key)
- `clan secrets users get` (registered key)
- `.sops.yaml` (recipient list)

**Why it's wrong:**

- Secrets encrypted for one key can't be decrypted by another
- Leads to "permission denied" or "no identity matched" errors

**Correct approach:** Pick ONE key (preferably SSH-derived) and ensure all references match.

### 4. Setting `keyFile` to Machine Key on Linux

**Wrong:**

```nix
sops.age.keyFile = "/var/lib/sops-nix/key.txt";  # Machine key
```

**Why it's wrong:**

- Machine key is `0400 root:root` - user can't read it
- Even with `keys` group, it's mixing machine/user concerns
- SSH key already works and is deployed for the user

**Correct approach:** Don't set `keyFile` on Linux; let sops-nix use `sshKeyPaths`.

## Workflow Summary

### Adding a New User to Secrets

1. Ensure their SSH public key is in the repo:

   ```bash
   # modules/users/<username>_id_ed25519.pub
   ```

2. Register their age key (SSH-derived):

   ```bash
   AGE_KEY=$(cat modules/users/<username>_id_ed25519.pub | ssh-to-age)
   clan secrets users add <username> $AGE_KEY
   ```

3. Add to `.sops.yaml` recipients:

   ```yaml
   - &<username> <age-public-key>
   ```

4. Re-encrypt secrets:
   ```bash
   cd sops && sops updatekeys secrets.yaml
   ```

### Deploying Secrets to a New Machine

1. Generate machine vars (creates age keypair):

   ```bash
   clan vars generate <hostname>
   ```

2. Add machine to `.sops.yaml` recipients

3. Re-encrypt secrets for new machine

4. Upload vars and deploy:
   ```bash
   clan vars upload <hostname>
   clan machines update <hostname>
   ```

## Troubleshooting

### "permission denied" on `/var/lib/sops-nix/key.txt`

**Cause:** Home-manager sops trying to read machine key (wrong approach).

**Fix:** Remove `keyFile` config on Linux, use SSH key only.

### "no identity matched any of the recipients"

**Cause:** Your key isn't in the recipient list for that secret.

**Fix:**

1. Check which keys can decrypt: `sops -d <file>` (will show error with key list)
2. Ensure your key is in `.sops.yaml` and re-run `sops updatekeys`

### Clan user key doesn't match local key

**Cause:** Key was regenerated or registered incorrectly.

**Fix:**

```bash
# Get your actual key
LOCAL_KEY=$(clan secrets key show | jq -r '.[0].publickey')

# Update registration
clan secrets users add <username> $LOCAL_KEY --force
```

## References

- [sops-nix documentation](https://github.com/Mic92/sops-nix)
- [clan-core secrets documentation](https://docs.clan.lol/getting-started/secrets/)
- [age encryption](https://github.com/FiloSottile/age)
- [ssh-to-age](https://github.com/Mic92/ssh-to-age)
