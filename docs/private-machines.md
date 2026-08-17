# Private machines in a separate flake

This repo is public and serves a flake template, so it can never declare a private input: evaluating `templates.dendritic` evaluates the whole module tree, and a repo nobody else can fetch would break `nix flake init -t` for everyone. See `templates/dendritic/docs/private-repo.md` for the measurements.

The arrangement that avoids that is a private flake which consumes this one and runs its own clan.

## The private flake

`nix flake init -t github:pperanich/dotfiles#private` scaffolds this. The shape:

```nix
# nix-private/flake.nix
{
  description = "Private machines";

  inputs = {
    upstream.url = "github:pperanich/dotfiles";
    # Declared, but resolved to upstream's lock rather than fetched twice.
    # Required: clan resolves `module.input` in the inventory against the lock
    # file, so without it every service instance dies with
    #   error: Flake doesn't provide input with name 'clan-core'
    clan-core.follows = "upstream/clan-core";
  };

  outputs =
    inputs@{ self, upstream, ... }:
    upstream.inputs.flake-parts.lib.mkFlake {
      # Upstream's inputs under their bare names, so a flake-parts module
      # copied from the template still finds `inputs.nixpkgs`. Handing over
      # only `{ self, upstream }` means rewriting every such reference.
      inputs = upstream.inputs // { inherit self upstream; };
    } (upstream.inputs.import-tree ./modules);
}
```

with `modules/flake-parts/clan.nix` holding the inventory:

```nix
{ inputs, config, ... }:
{
  imports = [ inputs.clan-core.flakeModules.default ];
  flake.clan = {
    meta.name = "pperanich-private";
    specialArgs = { inherit (inputs.upstream) inputs lib modules; };
    inventory.machines.secret-host = {
      machineClass = "nixos";
      tags = [ "all" ];
    };
  };
}
```

`machines/secret-host/configuration.nix` in the private repo is an ordinary machine file:

```nix
{ modules, ... }:
{
  imports = with modules.nixos; [ base sops caddyDns01 ];

  sops.defaultSopsFile = ../../sops/secrets.yaml; # this repo's own, see below
  networking.hostName = "secret-host";
  nixpkgs.hostPlatform = "x86_64-linux";
}
```

One input, no vendoring. `clan machines update secret-host` runs from the private repo, and `clan vars` writes into the private repo's `vars/` and `sops/`.

## Pass your own `self`

`mkFlake` needs `inputs`, and it is tempting to write `inputs = upstream.inputs // { self = upstream; }` to satisfy it. Don't. Clan derives its machine directory from `self`, so that makes the private flake discover **this** repo's `machines/` — `nixosConfigurations` comes back holding all seven public machines plus yours, silently.

The merge itself is fine, and useful; it is `self` that has to stay yours. `upstream.inputs // { inherit self upstream; }` keeps upstream's inputs reachable by their bare names while `nixosConfigurations` lists only your machines.

## Secrets

`sops.defaultSopsFile` is resolved where `modules/system/sops.nix` is written, so a private machine importing our `sops` module inherits **this** repo's `sops/secrets.yaml` — a store path its age key is probably not a recipient of. Override it in the private machine (the module's defaults use `mkDefault`, so a plain assignment wins).

Every module you import brings its declared keys with it, and `validateSopsFiles = true` means a key missing from the private `secrets.yaml` fails the build rather than activation:

```
sops-install-secrets: manifest is not valid: secret private_keys/pperanich in
/nix/store/…-secrets.yaml is not valid: the key 'private_keys' cannot be found
```

`sops.age.keyFile` points at `/var/lib/sops-nix/key.txt`, which `clan vars upload` provisions — one reason a private machine wants clan rather than a bare `nixosSystem` call.

## What does not span the two clans

Clan service instances are per-inventory. A machine in `pperanich-private` cannot be:

- a peer in the public clan's `pp-wg` wireguard instance
- a `borgbackup` client of `pp-router1`
- a `syncthing` peer
- a holder of the public clan's sshd CA certificates

Each clan has its own inventory, its own vars store, and its own `clan machines list`. Fine for an isolated host; wrong for anything that needs the mesh.

## Can the public inventory be extended from downstream?

Not by mutating it. `flake.clan` is evaluated inside this flake; once it is an input, its outputs are values.

You can re-evaluate a superset: export the inventory as a flake-parts module here, import it in the private flake, add machines, and let the private flake instantiate the whole fleet. Clan supports the pieces — `clan.self`, `clan.directory`, `clan.machines` for inline machine definitions.

The blocker is that one clan has exactly one `directory`, and that directory is where clan reads `sops/secrets`, `sops/groups` and in-repo vars (`nixosModules/clanCore/sops.nix`). A merged fleet therefore has a single secrets store: either the public repo holds the private machines' vars, or every machine's vars move into the private repo. There is no split where public vars stay public and private vars stay private inside one clan.

So the options are:

1. **Two clans** (this document). Private hosts are isolated; no shared service instances.
2. **Invert it.** Move the inventory and `vars/`+`sops/` into the private repo, which consumes this one for modules; this repo keeps modules, the template, and no machines. One fleet, everything sensitive private, at the cost that the public repo stops demonstrating real machine configs.

Option 2 is the only one that keeps a single mesh. Pick it if a private host needs wireguard or borg; otherwise option 1 is much less disruptive.

## Non-clan alternative

For hosts that are not fleet members at all — a throwaway test VM, an installer image — a downstream flake can call `nixosSystem` directly with this repo's modules:

```nix
dotfiles.inputs.nixpkgs.lib.nixosSystem {
  specialArgs = { inherit (dotfiles) inputs lib modules; };
  modules = [ ./configuration.nix ];
}
```

That skips clan entirely, so the machine gets no vars, no generated host keys, and no `/var/lib/sops-nix/key.txt`. It also needs its own account creation, since `modules/users/pperanich.nix` adds shell, groups and keys but relies on clan's `users` service to create the account:

```nix
users.users.pperanich = { isNormalUser = true; home = "/home/pperanich"; };
```

Modules that reference `clan.core` directly — currently `protonvpn` — fail to evaluate this way.
