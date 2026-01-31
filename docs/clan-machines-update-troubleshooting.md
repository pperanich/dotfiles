# Troubleshooting `clan machines update`

This document describes common issues and debugging steps when running `clan machines update <machine>`.

## Issue 1: "Host key verification failed"

### Symptoms

```
[machine] Host key verification failed.
[machine] error: failed to start SSH connection to '<ip>'
[machine] Command 'nix-copy-closure ... --to root@<ip> ...' returned non-zero exit status 1.
```

### Root Cause

When `clan machines update` runs, it:

1. SSHs **to** the target machine
2. Runs `nixos-rebuild --target-host root@<ip>` **on** that machine
3. The target machine then runs `nix-copy-closure` back to itself

The host key verification failure happens **on the target machine**, not on your workstation. The target machine doesn't have its own IP in its `known_hosts`.

### Solution

Add the target machine's host key to its own `known_hosts`:

```bash
# From your workstation, run:
ssh root@<target-ip> "ssh-keyscan -H <target-ip> >> ~/.ssh/known_hosts"
```

### If Host Key Changed

If you see "REMOTE HOST IDENTIFICATION HAS CHANGED", the target machine's SSH host keys were regenerated (reinstall, etc.):

```bash
# 1. Fix on your workstation
ssh-keygen -R <target-ip>
ssh-keyscan -H <target-ip> >> ~/.ssh/known_hosts

# 2. Fix on the target machine itself
ssh root@<target-ip> "ssh-keygen -R <target-ip>; ssh-keyscan -H <target-ip> >> ~/.ssh/known_hosts"
```

---

## Issue 2: SOPS Decryption Failure

### Symptoms

```
sops-install-secrets: Imported /etc/ssh/ssh_host_ed25519_key as age key with fingerprint age1xxx...
sops-install-secrets: failed to decrypt '...': Error getting data key: 0 successful groups required, got 0
Activation script snippet 'setupSecrets' failed (1)
```

### Root Cause

The machine's age key (derived from its SSH host key) doesn't match the key the secrets are encrypted to. This happens when:

1. The machine was reinstalled and got new SSH host keys
2. The `sops/machines/<machine>/key.json` file wasn't updated to match

### Debugging Steps

1. **Check what key the machine is using**:

   ```bash
   ssh root@<target-ip> "nix-shell -p ssh-to-age --run 'cat /etc/ssh/ssh_host_ed25519_key.pub | ssh-to-age'"
   ```

   This shows the actual age public key derived from the machine's SSH host key.

2. **Check what key is in the repo**:

   ```bash
   cat sops/machines/<machine>/key.json
   ```

3. **Check what keys a secret is encrypted to**:
   ```bash
   cat vars/per-machine/<machine>/openssh/ssh.id_ed25519/secret | head -30
   ```
   Look at the `"recipient"` fields in the `"age"` array.

### Solution

1. **Update the machine key in the repo**:

   ```bash
   # Get the actual key from the machine
   ACTUAL_KEY=$(ssh root@<target-ip> "nix-shell -p ssh-to-age --run 'cat /etc/ssh/ssh_host_ed25519_key.pub | ssh-to-age'")

   # Update the key.json file
   echo "[{\"publickey\": \"$ACTUAL_KEY\", \"type\": \"age\"}]" > sops/machines/<machine>/key.json
   ```

2. **Re-encrypt secrets with the new key**:

   ```bash
   clan vars fix <machine>
   ```

3. **If per-machine secrets still fail** (common!), `clan vars fix` only updates shared secrets. You must regenerate per-machine secrets individually:

   ```bash
   # Regenerate specific generators that are failing
   clan vars generate <machine> --generator openssh --regenerate
   clan vars generate <machine> --generator emergency-access --regenerate

   # Or regenerate all (may require interactive input for passwords)
   clan vars generate <machine> --regenerate
   ```

   **Note**: `clan vars fix` may report "already up to date" even when secrets are encrypted to wrong keys. Always regenerate per-machine secrets after updating the machine key.

4. **Commit and retry**:
   ```bash
   git add sops/machines/<machine>/key.json vars/
   clan machines update <machine>
   ```

---

## Issue 3: Clock Skew Warnings

### Symptoms

```
tar: key.txt: time stamp 2026-01-31 19:14:01 is 9.21 s in the future
```

### Root Cause

The target machine's clock is out of sync with your workstation. Common in WSL environments.

### Solution

On the target machine (especially WSL):

```bash
# Option 1: Sync from hardware clock
sudo hwclock -s

# Option 2: Use NTP
sudo ntpdate time.windows.com

# Option 3: For WSL specifically
wsl --shutdown  # Then restart WSL
```

---

## Issue 4: nftables Syntax Errors

### Symptoms

```
ruleset.conf:13:25-30: Error: syntax error, unexpected accept
  iifname "enp5s0" icmp accept
                        ^^^^^^
```

### Root Cause

Invalid nftables rule syntax. Common issues:

- `icmp accept` → needs type specifier: `icmp type { echo-request, echo-reply } accept`
- `icmpv6 accept` → needs type specifier: `icmpv6 type { ... } accept`
- `rt mss` → should be `rt mtu` for MSS clamping

### Solution

Fix the nftables rules in your router/firewall module. See `modules/router/firewall.nix` for examples.

---

## Issue 5: Sysctl Conflicts

### Symptoms

```
error: The option `boot.kernel.sysctl."net.ipv6.conf.all.forwarding"' is defined multiple times
```

### Root Cause

Multiple modules (e.g., router module, WireGuard, tailscale) are setting the same sysctl value.

### Solution

Use `lib.mkForce` for values that must override others, or `lib.mkDefault` for values that should be overridable:

```nix
boot.kernel.sysctl = {
  # Use mkForce when this module MUST have this value
  "net.ipv4.conf.all.forwarding" = lib.mkForce 1;

  # Use mkDefault when this is a sensible default but can be overridden
  "net.ipv6.conf.all.forwarding" = lib.mkDefault 1;
};
```

---

## General Debugging Tips

1. **Add `-v` for verbose SSH output**:

   ```bash
   NIX_SSHOPTS="-v" clan machines update <machine>
   ```

2. **Check the full command being run**:
   The error output shows the exact SSH and nixos-rebuild commands. Try running them manually.

3. **Test SSH connectivity separately**:

   ```bash
   ssh root@<target-ip> hostname
   ```

4. **Test nix-copy-closure separately**:

   ```bash
   nix-copy-closure --to root@<target-ip> /nix/store/some-path
   ```

5. **Check clan configuration**:
   ```bash
   grep -r "targetHost\|buildHost" machines/<machine>/
   ```
