# Adding New Machines

This guide covers adding a NixOS host and a Darwin host: the host configuration, its SSH host key, its sops file, the first install, a deploy-rs node, and Headscale enrollment.

## Prerequisites

- `pp-ml1` (the only admin machine) with this repo checked out, inside `nix develop`. The dev shell provides `sops`, `ssh-to-age`, `age`, `age-plugin-yubikey`, `deploy-rs` and `nh`.
- The admin age key at `~/.config/sops/age/keys.txt`, or the YubiKey plugged in.
- Network access to the target (LAN or tailnet), and root on the installer for a bare-metal NixOS install.
- The hostname decided (see below).

## Machine Naming Convention

```
{prefix}-{os}{type}{num}   # General-purpose machines
{prefix}-{role}{num}       # Dedicated-role machines
```

| Component  | Options                                            |
| ---------- | -------------------------------------------------- |
| **Prefix** | `pp` (personal)                                    |
| **OS**     | `l` (Linux/NixOS), `m` (macOS/Darwin), `wsl` (WSL) |
| **Type**   | `l` (laptop), `d` (desktop)                        |
| **Role**   | `nas`, `rpi`, `router`, etc.                       |

Examples: `pp-ml1` (personal Mac laptop), `pp-nas1` (personal NAS)

## How a host gets built

`modules/flake-parts/hosts.nix` treats every `machines/<host>/configuration.nix` as a host. It reads `nixpkgs.hostPlatform` from that file to choose between `nixosConfigurations` and `darwinConfigurations`, so the file must set `nixpkgs.hostPlatform` directly (not through `hardware-configuration.nix` alone). For NixOS hosts it also picks up `machines/<host>/disko.nix` and `machines/<host>/facter.json` when they exist, and applies a baseline: key-only SSH, `PermitRootLogin = "no"`, networkd, and an emergency shell on the console.

The same file holds a list called `expectedHosts`, checked by `checks.hosts-eval`. A new host fails `nix flake check` until you add its name there (the list is alphabetical).

## Step 1: Create the host configuration

### NixOS

Create `machines/<hostname>/configuration.nix`:

```nix
{ modules, ... }:
{
  imports = [
    ./hardware-configuration.nix
  ]
  ++ (with modules.nixos; [
    base
    sops
    tailscale
    pperanich
  ]);

  networking.hostName = "<hostname>";
  nixpkgs.hostPlatform = "x86_64-linux";

  my.pperanich.passwordHashSecret = "passwords/pperanich";
  users.mutableUsers = false;
}
```

`pperanich` creates the login user. `passwordHashSecret` names the sops key holding the yescrypt hash that `sudo` and the console accept; with `users.mutableUsers = false` the host has no other password. Login is by SSH key only, using the keys in `lib/default.nix` (`sshKeys`).

For hardware configuration, either generate `hardware-configuration.nix` on the target:

```bash
nixos-generate-config --show-hardware-config > hardware-configuration.nix
```

or use `disko.nix` and `facter.json` as `pp-nas1` and `pp-router1` do (`nix run nixpkgs#nixos-facter -- -o facter.json` on the target).

### Darwin

Create `machines/<hostname>/configuration.nix`:

```nix
{ modules, ... }:
{
  imports = with modules.darwin; [
    base
    sops
    tailscale
    pperanich
  ];

  networking.hostName = "<hostname>";
  nixpkgs.hostPlatform = "aarch64-darwin";
}
```

### Both

Add the hostname to `expectedHosts` in `modules/flake-parts/hosts.nix`.

## Step 2: Create and pin the host key

The host's sops recipient is derived from `/etc/ssh/ssh_host_ed25519_key`. Create the key before the sops file so you know the recipient.

### NixOS (bare-metal install with nixos-anywhere)

`bin/install.sh` generates the key into a staging directory and prints the age recipient:

```bash
bin/install.sh --host <hostname> --prepare-extra-files ~/tmp/<hostname>-extra
```

The directory holds `etc/ssh/ssh_host_ed25519_key` (mode 0600) and its `.pub`. Step 6 copies it onto the new machine. Delete the directory when the install is done.

To use a key that already exists on a running host instead, read the public half over SSH and convert it:

```bash
ssh pperanich@<hostname>.home.arpa cat /etc/ssh/ssh_host_ed25519_key.pub | ssh-to-age
```

### Darwin

macOS creates the key itself. Convert the public half on the Mac:

```bash
ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub
```

If the file is missing, create it with `sudo ssh-keygen -t ed25519 -N "" -f /etc/ssh/ssh_host_ed25519_key`. System decryption must use this key because the user key is itself installed by sops.

### Pin the key

Both platforms read `lib/ssh-host-keys.nix` and put each entry in `known_hosts` under `<host>`, `<host>.home.arpa` and `<host>.pp-ts`. Add the public key without its trailing comment:

```nix
  <hostname> = "ssh-ed25519 AAAA...";
```

A Darwin host with Remote Login off (like `pp-ml1`) needs no entry, since nothing connects to it.

## Step 3: Add the recipient and creation rule

Edit `sops/.sops.yaml`. Add the age recipient under the `&hosts` group:

```yaml
- &hosts "":
    # ... existing hosts ...
    - &<hostname> age1...
```

Then add a rule for the host's file. Every rule lists the admin key, the YubiKey and the host, and nothing else:

```yaml
- path_regex: (^|sops/)machines/<hostname>\.yaml$
  key_groups:
    - age:
        - *pperanich-admin
        - *yubikey0-slot1
        - *yubikey1-slot1
        - *<hostname>
```

A workstation whose home-manager reads `sops/users/pperanich-desktop.yaml` also needs its host recipient in that rule. Home-manager runs as the user and cannot read the host key, so it uses its own age key. Generate it on the new workstation, never on `pp-ml1`, where that path holds the admin key:

```bash
test -e ~/.config/sops/age/keys.txt || age-keygen -o ~/.config/sops/age/keys.txt
```

Add the public key it prints to `.sops.yaml` (as an anchor under `&users`) and to the `pperanich-desktop` rule, then run `updatekeys` on that file. `pp-ml1` uses the admin key at that path, which is already a recipient. See [Secrets and Key Management](secrets-and-key-management.md).

## Step 4: Create the host's sops file

Every secret a module declares must exist in the file, or the build fails (`sops.validateSopsFiles = true`). Create it and add the keys the host's modules need:

```bash
sops --config sops/.sops.yaml sops/machines/<hostname>.yaml
```

Every NixOS host needs `passwords/pperanich`, nested as `passwords:` then `pperanich:`. Generate the hash for the password `sudo` should accept:

```yaml
passwords:
  pperanich: $y$... # output of: nix shell nixpkgs#mkpasswd -c mkpasswd -m yescrypt
```

Add the keys for each service you enable. Build the host (Step 5) to find any you missed: the error names the key.

The new file is excluded from treefmt by the `sops/machines/*.yaml` glob, so `nix fmt` leaves it alone.

## Step 5: Check the build

```bash
nix flake check --no-build
```

Linux closures build on their targets, not on the Mac, so this evaluates the NixOS host without building it.

## Step 6: First install

### NixOS, bare metal

Boot the installer, make sure root SSH works on it, then install with the staged host key:

```bash
nix run github:nix-community/nixos-anywhere -- \
  --extra-files ~/tmp/<hostname>-extra \
  --flake .#<hostname> root@<installer-ip>
rm -rf ~/tmp/<hostname>-extra
```

The machine reboots into its configuration with the host key in place, so sops decrypts on first boot. Root SSH is off on the installed system; log in as `pperanich`.

### NixOS, already installed

sshd creates `/etc/ssh/ssh_host_ed25519_key` on first start, so the machine already has a key. Convert it as in Step 2, finish Steps 3 to 5, and deploy (Step 7). The sops file must already be encrypted to that key when the new configuration first activates.

### Darwin

On the Mac, in a checkout of this repo:

```bash
darwin-rebuild switch --flake .#<hostname>   # first run, after nix-darwin is installed
nh darwin switch . -H <hostname>             # every run after
```

`bin/install.sh --host <hostname>` installs Nix and bootstraps nix-darwin if neither is present. After a rebuild, check that sops installed the secrets: no `sops-install-secrets` error in the output, `readlink /run/secrets` moved forward, and `tail ~/Library/Logs/SopsNix/stderr` is clean. A Mac has no automatic rollback.

## Step 7: Add the deploy-rs node (NixOS)

Edit `modules/flake-parts/deploy.nix`. Add the node to `nodes`:

```nix
<hostname> = {
  hostname = "<hostname>.home.arpa"; # or <hostname>.pp-ts once it has joined the tailnet
  remoteBuild = true;
  profiles.system.path =
    deployPkgs."x86_64-linux".deploy-rs.lib.activate.nixos
      self.nixosConfigurations.<hostname>;
};
```

and add its name to `expectedNodes` in the same file (alphabetical). `checks.deploy-nodes-eval` asserts that every node builds remotely, so keep `remoteBuild = true`. Use `deployPkgs."aarch64-linux"` for an ARM host.

Deploy from `pp-ml1`:

```bash
deploy .#<hostname>
# or, naming the address:
deploy --hostname <hostname>.home.arpa .#<hostname>
```

deploy-rs logs in as root with `pp-ml1`'s key, runs `nix flake check`, builds on the target, and rolls back by itself if it cannot reconnect within about 30 seconds.

A Darwin host has no deploy node; it switches locally (Step 6).

## Step 8: Enroll in Headscale

Every host joins the tailnet served by Headscale on `pp-router1`. On the router, create a single-use pre-auth key with the tag the host should hold. `preauthkeys create` takes the numeric user ID (`sudo headscale users list`; `pperanich` is 1):

```bash
ssh pperanich@pp-router1.home.arpa
sudo headscale preauthkeys create --user 1 --expiration 1h --tags tag:<tag>
```

Then on the new host, run the helper that the `tailscale` module installs:

```bash
sudo tailscale-headscale-up --auth-key <key>
```

It sets the login server (`https://hs.prestonperanich.com:9443`) and the DNS option for the host. A host still logged in to another tailnet refuses with `can't change --login-server without --force-reauth`; add `--force-reauth`, which logs it out of the old one.

To join unattended instead, set `my.tailscale.authKeySecret = "<sops-key>";` in the host's configuration and store the pre-auth key under that name in its sops file.

Verify from the router and from `pp-ml1`:

```bash
sudo headscale nodes list          # on the router
ssh pperanich@<hostname>.pp-ts true  # on pp-ml1
```

macOS caches failed DNS lookups, so a newly enrolled `*.pp-ts` name may not resolve at first: `sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder`. `ping` to the router over the tailnet times out by design (its firewall allows only SSH, HTTPS and DNS on `tailscale0`); use `tailscale ping`.

## Choosing and adding tags

The ACL lives in `modules/services/headscale.nix` (`defaultPolicy`):

| Tag          | Reaches                                              | Use for                          |
| ------------ | ---------------------------------------------------- | -------------------------------- |
| `tag:admin`  | everything                                           | admin workstations               |
| `tag:mobile` | router `:53` and `:443`, NAS `:443`                  | phones                           |
| `tag:dev`    | router `:53` and `:443`                              | development hosts (WSL, Windows) |
| `tag:iot`    | router `:53`                                         | constrained devices              |
| `tag:server` | router `:53`                                         | constrained servers              |
| `tag:router` | NAS `:22` and `:443`                                 | the router only                  |
| `tag:nas`    | nothing as a source; the NAS is a destination for it | the NAS                          |

SSH from `tag:dev`, `tag:mobile`, `tag:iot` and `tag:server` is blocked. To add a tag, add it to `tagOwners` and write an `acls` entry for it in that file, then deploy the router.

To change the tag of an enrolled node: `sudo headscale nodes tag -i <id> -t tag:<tag>` (find the ID with `headscale nodes list`).

## Checklist

1. `machines/<hostname>/configuration.nix`, with `nixpkgs.hostPlatform` set
2. `expectedHosts` in `modules/flake-parts/hosts.nix`
3. Host key created; entry in `lib/ssh-host-keys.nix` (unless sshd is off)
4. Recipient and creation rule in `sops/.sops.yaml`
5. `sops/machines/<hostname>.yaml` with every key the modules declare
6. First install or switch
7. NixOS: node and `expectedNodes` in `modules/flake-parts/deploy.nix`
8. Headscale pre-auth key, `tailscale-headscale-up`, `headscale nodes list`

## Troubleshooting

### Host key verification failed

The pinned key in `lib/ssh-host-keys.nix` does not match what the host serves. Read the real one and compare:

```bash
ssh-keyscan -t ed25519 <hostname>.home.arpa
```

### "no identity matched any of the recipients" or a failed sops install

The host's key is not a recipient of its file. Compare what the host has with what the rule lists:

```bash
ssh pperanich@<hostname>.home.arpa cat /etc/ssh/ssh_host_ed25519_key.pub | ssh-to-age
grep -n <hostname> sops/.sops.yaml
```

If they differ, fix `.sops.yaml` and run `sops --config sops/.sops.yaml updatekeys sops/machines/<hostname>.yaml`.

### The build says a key cannot be found

A module declares a secret that the host's sops file lacks. Add the named key with `sops --config sops/.sops.yaml sops/machines/<hostname>.yaml`.

### Deploy rolled back

Check `journalctl _COMM=sudo` on the host for `authentication failure` (a sudo typo), then re-run. If the host does not come back at all, use the console: the initrd and the emergency and rescue shells open without a password.
