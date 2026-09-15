# Private machines

Build private NixOS and nix-darwin hosts from an existing public dendritic
config. Upstream supplies the package set and reusable modules; this repo owns
its machines, user profile, private dotfiles, and encrypted secrets.

The default flake has one direct input, `upstream`. Local switches use `nh`,
`nixos-rebuild`, or `darwin-rebuild`. Remote deployment with rollback is
available in [optional/deploy-rs](optional/deploy-rs/README.md).

## Layout

```
flake.nix                    public upstream; optional deploy-rs input
lib/repo.nix                 checkout path relative to $HOME
modules/flake-parts/
  hosts.nix                  discover hosts and set nh defaults
  flake-parts.nix            this repo's flake.modules tree
  nixpkgs.nix                 upstream package set for shell and formatting
  shell.nix                  nh, sops, age, ssh-to-age, treefmt
  fmt.nix                    formatting checks
modules/users/example.nix    account and desktop/server profile selection
modules/home/stow.nix        private dotfiles activation
modules/shell/api-keys.nix   optional secret-name discovery
home/                       plain private dotfiles
home-profiles/example/      shared upstream + private home modules
machines/<host>/
  configuration.nix         module imports, platform, host settings
  hardware-configuration.nix (NixOS only)
sops/                       recipient configuration and encrypted secrets
optional/deploy-rs/          remote deployment example
docs/upstream-contract.md   interfaces and constraints
```

A directory under `machines/` containing `configuration.nix` becomes a host.
The file must declare `nixpkgs.hostPlatform` directly: that selects NixOS or
Darwin before the module system runs. Importing a hardware file that declares
it is insufficient. Strings, platform attrsets, and `lib.mkDefault` wrappers
are supported; the value cannot depend on `config` or `pkgs`.

## Setup

1. **Choose the upstream and checkout location.** Set `inputs.upstream.url`
   in `flake.nix`. Clone this repo to `~/nix-private`, or change
   `lib/repo.nix` to the desired home-relative path, such as
   `repos/nix-private`. Both private Stow and argument-free `nh` use it.

2. **Rename the examples.** Rename the machine directories and hostnames,
   `modules/users/example.nix` and its `username`,
   `home-profiles/example/` and its `home.username`, and the profile import
   paths in the user module. Update each machine's `example` module import
   and `my.example.desktop` option, and the corresponding secret keys and
   recipient names. Delete unused machines and their recipient entries.
   Replace the NixOS hardware placeholder with the output of
   `nixos-generate-config --show-hardware-config`, keeping
   `nixpkgs.hostPlatform` in `configuration.nix` too.

3. **Select modules and a home profile.** The NixOS example sets
   `my.example.desktop = false`; Darwin sets it to `true`.
   This selects fonts and applications in the same home profile. It does
   not disable desktop services imported elsewhere. Read the
   [upstream contract](docs/upstream-contract.md) before adding modules
   that declare secrets. Uncomment `apiKeys` in the profile to discover
   this repo's API tokens.

4. **Prepare persistent host keys before the first activation.** Start the
   development shell after making the files visible to Nix:

   ```bash
   git init
   git add -A
   nix develop
   ```

   On macOS, enable **System Settings > General > Sharing > Remote Login**
   for the account that will connect. On each target, create missing host
   keys without replacing existing ones:

   ```bash
   sudo ssh-keygen -A
   ```

   Obtain the admin recipient on your workstation and the host recipient
   on each target (using the development shell's `ssh-to-age`):

   ```bash
   ssh-to-age < ~/.ssh/id_ed25519.pub
   ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub
   ```

   If the target lacks `ssh-to-age`, copy its public host key to the
   workstation and convert it there. Put the recipients in
   `sops/.sops.yaml`. The admin recipient must match the user private key
   stored under `private_keys/<user>`, since Home Manager uses that key.

5. **Replace and encrypt the placeholder secrets.** Before the first switch,
   fill in the password hash and user SSH private key. The checked-in file
   starts as plaintext, so encrypt it explicitly:

   ```bash
   $EDITOR sops/secrets.yaml
   sops --config sops/.sops.yaml encrypt --in-place sops/secrets.yaml
   git add -A
   ```

   For later edits and recipient changes:

   ```bash
   sops sops/secrets.yaml
   sops --config sops/.sops.yaml updatekeys sops/secrets.yaml
   ```

   The development shell derives `SOPS_AGE_KEY` from your local
   `~/.ssh/id_ed25519` when available. Commit only the encrypted file.

6. **Check and switch on the target.**

   For an existing NixOS machine, complete the
   [account migration](#adopting-an-existing-nixos-machine) first. The example
   manages accounts declaratively, including password updates and removals.

   ```bash
   nix flake check
   nh os switch . -H example-nixos
   # Or on macOS:
   nh darwin switch . -H example-darwin
   ```

   Replace the example selector with the machine directory name. The first
   switch needs an explicit selector if the current hostname differs.
   Start a new shell after activation; `nh os switch` or
   `nh darwin switch` then uses the installed platform-specific reference.
   These references take precedence over the development shell's
   `NH_FLAKE`, so pass an explicit flake when working on another checkout.

## Adopting an existing NixOS machine

The NixOS example explicitly sets `users.mutableUsers = false` in the machine
file. This applies the SOPS-provided password hash on each activation, even
when the account already exists. It also removes users and groups absent
from the evaluated configuration and replaces manually changed passwords.

Before enabling this policy on an existing installation:

1. Inventory the target with `getent passwd` and `getent group`. Declare every
   account and group you need to retain, directly or through its service
   module. Preserve existing UIDs, GIDs, home directories, and required group
   memberships. Include administrative and recovery accounts.
2. For gradual adoption, temporarily set `users.mutableUsers = true` in the
   machine file. This preserves accounts created outside Nix and leaves
   existing passwords unchanged, including when `passwords/<user>` changes.
   Keep declarations for accounts previously managed by Nix: removing those
   declarations can still remove the accounts even with this setting.
3. Verify the encrypted password hashes and the retained administrator's
   access, then set `users.mutableUsers = false`. Build and review
   `nixos-rebuild dry-activate --flake .#<host>` on the target before switching.

The policy stays in each machine file because it affects all accounts on that
machine. Darwin continues to use the account created by macOS.

## Private dotfiles

Place private configuration under `home/` at its intended path within
`$HOME`. The `stowPrivate` module activates after upstream's `stowHome`.
It warns if the checkout is missing, so clone the private repo at the
location in `lib/repo.nix` before expecting the files to appear.

The two repos can share directories but must not own the same file. Use
separate application profiles when personal and private configurations
differ. Stow reports a collision instead of overwriting an existing file;
inspect and move the conflicting file before retrying.

Private Stow uses `--no-folding`, linking files individually so runtime
files created beside them stay in real home directories. Keep mutable files
such as credentials, sessions, and installed dependencies out of `home/`.
Applications can still overwrite a symlinked file itself, so only track
configuration they do not rewrite. The upstream checkout must also exist
or be accessible to its own Stow activation.
