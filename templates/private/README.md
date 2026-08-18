# Private machines

A repo for hosts you do not want in a public config, built entirely from a
public config you already have. One input, no vendoring, no submodule, and no
deployment tool: you switch these machines the same way you switch any other
NixOS or nix-darwin host.

Use this when you already run the dendritic layout publicly and want machines
whose names, addresses or services should not be visible. If you are starting
from nothing, start with the `dendritic` template instead.

## Layout

```
flake.nix                    one input: your public config
modules/flake-parts/
  hosts.nix                  machines/ -> nixosConfigurations/darwinConfigurations
  flake-parts.nix            this repo's own flake.modules tree
  nixpkgs.nix                pkgs for the dev shell and treefmt
  shell.nix                  nh, sops, age, ssh-to-age, treefmt
  fmt.nix                    treefmt
modules/users/example.nix    the account, and which home profile it gets
home-profiles/example/       upstream homeManager modules, composed
machines/nixos/<host>/
  configuration.nix          upstream modules + this host's settings
  hardware-configuration.nix
machines/darwin/<host>/
  configuration.nix
sops/
  .sops.yaml                 admin + per-host age recipients
  secrets.yaml               placeholder until you encrypt it
docs/upstream-contract.md    what one input buys, and what it costs
```

Adding a host is creating `machines/<class>/<name>/configuration.nix`. Nothing
else needs to know about it.

## Setup

1. **Point `flake.nix` at your public config.** Replace
   `github:you/your-config`. It has to be fetchable from wherever you build.

2. **Rename the machine and the user.** `machines/nixos/example-nixos/` plus
   `networking.hostName`; `modules/users/example.nix`, `home-profiles/example/`,
   and the `example` line in each machine's import list. Delete the class you
   are not using. Drop in a real `hardware-configuration.nix` from
   `nixos-generate-config --show-hardware-config`.

3. **Pick the upstream modules the machine imports** in its
   `configuration.nix`, and the home modules in `home-profiles/<user>/`. Each
   one brings its own required secret keys; read `docs/upstream-contract.md`
   first.

4. **Set up secrets.** Everything here decrypts with age keys, and there are
   two: yours (for editing) and each host's (for activation).

   ```bash
   git init && git add -A && git commit -m "Initial config"
   nix develop

   ssh-to-age < ~/.ssh/id_ed25519.pub            # -> the &admin recipient
   ssh-keyscan <host> | ssh-to-age               # -> the &<host> recipient
   $EDITOR sops/.sops.yaml                       # paste both in
   sops sops/secrets.yaml                        # write and encrypt the real file
   ```

5. **Switch.** From the machine itself:

   ```bash
   nh os switch .            # NixOS   (nixos-rebuild switch --flake .#<host>)
   nh darwin switch .        # macOS   (darwin-rebuild switch --flake .#<host>)
   ```

   `nh` picks the configuration matching the local hostname, elevates itself,
   and prints a package diff before activating. `-H <host>` overrides the name,
   `-n` is a dry run, and `--target-host <user>@<host>` deploys to another
   machine over ssh. Plain `nixos-rebuild`/`darwin-rebuild` work unchanged.

## The three settings that are easy to miss

All live in `machines/<class>/<host>/configuration.nix` and all are already
there:

- `sops.defaultSopsFile` pointing at _this_ repo's `sops/secrets.yaml`. Without
  it the host looks for secrets in the upstream's store path.
- `sops.age.keyFile = null`, because the upstream defaults it to
  `/var/lib/sops-nix/key.txt`, which is provisioned by a tool this repo does
  not use.
- `sops.age.sshKeyPaths`, which is what replaces that key file: the host
  decrypts with an age key derived from its own SSH host key.

## Where secrets live

One place: `sops/secrets.yaml`, encrypted to the recipients in
`sops/.sops.yaml`. The system decrypts it at activation and writes the user's
SSH private key to disk before home-manager runs, so the home profile's own
sops has a key to work with.

`sops.validateSopsFiles` is on, so a key an imported module expects but the
file does not have fails the build rather than the activation. That is the
whole safety net for the upstream contract — use it.
