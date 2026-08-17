# Private machines

A clan for hosts you do not want in a public repo, built entirely from a public
config you already have. One input, no vendoring, no submodule.

Use this when you already run the dendritic layout publicly and want to add
machines whose names, addresses or services should not be visible. If you are
starting from nothing, start with the `dendritic` template instead.

This repo runs a clan. If you only need one or two private hosts and no
inventory, the lighter option is the upstream's exported `lib.mkHost`, which
builds `nixosConfigurations` from a downstream flake with no clan at all: see
route B in the dendritic template's `docs/private-repo.md`.

## Layout

```
flake.nix                    one input: your public config
modules/flake-parts/
  clan.nix                   the inventory; the file you edit most
  nixpkgs.nix                pkgs for this repo's own outputs
  shell.nix                  clan-cli, sops, age, ssh-to-age, treefmt
  fmt.nix                    treefmt
machines/<host>/
  configuration.nix          upstream modules + this host's settings
  hardware-configuration.nix
sops/
  .sops.yaml                 admin + per-machine age recipients
  secrets.yaml               placeholder until you encrypt it
docs/upstream-contract.md    what one input buys, and what it costs
```

## Setup

1. **Point `flake.nix` at your public config.** Replace
   `github:you/your-config`. It needs to be fetchable from wherever you deploy.

2. **Rename the machine.** `machines/secret-host/` plus `networking.hostName`,
   `clan.core.networking.targetHost` and the `secret-host` entry in
   `modules/flake-parts/clan.nix`. Drop in a real
   `hardware-configuration.nix` from `nixos-generate-config`.

3. **Pick the upstream modules the machine imports** in its
   `configuration.nix`. Each one brings its own required secret keys with it;
   read `docs/upstream-contract.md` first.

4. **Set up secrets.**

   ```bash
   git init && git add -A        # flakes only see tracked files
   nix develop
   clan vars generate secret-host   # host keys, the machine age key, passwords
   ```

   Put your admin recipient and the machine's clan-generated age key into
   `sops/.sops.yaml`, then `sops sops/secrets.yaml` to write the real file.

5. **Deploy.**

   ```bash
   clan machines update secret-host
   ```

## The two settings that are easy to miss

Both live in `machines/<host>/configuration.nix` and both are already there:

- `sops.defaultSopsFile` pointing at _this_ repo's `sops/secrets.yaml`. Without
  it the machine looks for secrets in the upstream's store path.
- `sops.age.keyFile = "/var/lib/sops-nix/key.txt"`, which `clan vars upload`
  provisions.

## Where secrets live

Two systems, and it is worth being clear which owns what:

- **clan vars** — what clan generates for you: host SSH keys, the machine age
  key, root and user passwords. Stored in this repo's `vars/`.
- **sops/secrets.yaml** — what you author: API tokens, service passwords, and
  the keys the upstream's modules demand.
