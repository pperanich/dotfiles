# Private machines in a separate flake

This repo is public and serves a flake template, so it can never declare a private input: evaluating `templates.dendritic` evaluates the whole module tree, and a repo nobody else can fetch would break `nix flake init -t` for everyone. See `templates/dendritic/docs/private-repo.md` for the measurements.

The arrangement that avoids that is a private flake which consumes this one and builds its own hosts. It runs no clan and no deployment tool: a private machine is switched with `nixos-rebuild`, `darwin-rebuild`, or `nh`, like any other.

```bash
nix flake init -t github:pperanich/dotfiles#private
```

## The private flake

```nix
# nix-private/flake.nix
{
  description = "Private machines";

  inputs.upstream.url = "github:pperanich/dotfiles";

  outputs =
    inputs@{ upstream, ... }:
    upstream.inputs.flake-parts.lib.mkFlake {
      inputs = upstream.inputs // inputs;
    } (upstream.inputs.import-tree ./modules);
}
```

`modules/flake-parts/hosts.nix` turns `machines/<class>/<host>/` into `nixosConfigurations`/`darwinConfigurations` by calling `nixosSystem` or `darwinSystem` directly, with this repo's `modules` and `lib` as specialArgs. A machine file there reads exactly like one here:

```nix
{ modules, ... }:
{
  imports = [ ./hardware-configuration.nix ] ++ (with modules.nixos; [ base sops secretuser ]);

  sops = {
    defaultSopsFile = ../../../sops/secrets.yaml;
    age = {
      keyFile = null;
      sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    };
  };

  networking.hostName = "secret-host";
  nixpkgs.hostPlatform = "x86_64-linux";
}
```

One input, no vendoring, no submodule.

## Pass your own `self`

`mkFlake` needs `inputs`, and it is tempting to write `inputs = upstream.inputs // { self = upstream; }` to satisfy it. Don't: `self` is what `machines/` resolves against, so that makes the private flake enumerate **this** repo's machines. Write `upstream.inputs // inputs` and let your own `self` land on top.

## Secrets

The private repo owns its own `sops/secrets.yaml`, encrypted to your admin key and to each host's age key (derived from its SSH host key with `ssh-to-age`). Three settings in the machine file make that work, and all three override upstream defaults:

| setting                   | why                                                                   |
| ------------------------- | --------------------------------------------------------------------- |
| `sops.defaultSopsFile`    | otherwise the host reads this repo's secrets, which it cannot decrypt |
| `sops.age.keyFile = null` | our default is `/var/lib/sops-nix/key.txt`, which clan provisions     |
| `sops.age.sshKeyPaths`    | what replaces it, with no clan in the picture                         |

`modules/system/sops.nix` sets the first two with `lib.mkOverride 900` specifically so a plain assignment downstream wins: `mkDefault` would tie with clan-core's own definition and error out. If a future edit makes either a plain assignment, every private machine breaks with `has conflicting definition values`.

Every module a private machine imports brings its declared keys with it, and `validateSopsFiles = true` means a key missing from the private `secrets.yaml` fails the build rather than the activation:

```
sops-install-secrets: manifest is not valid: secret private_keys/pperanich in
/nix/store/…-secrets.yaml is not valid: the key 'private_keys' cannot be found
```

The homeManager `sops` module declares no secrets itself, so importing it is free. Secrets that a private repo would rather not carry live in their own modules: the six provider tokens are `modules/shell/api-keys.nix` (`homeManager.apiKeys`), which the private template's profile deliberately omits. Keep that split when adding secrets — a key declared beside the wiring is a key every downstream profile is forced to store.

## The user module is copied, not imported

`modules/users/pperanich.nix` here hardcodes this repo's sops file and leaves account creation (`isNormalUser`, `hashedPasswordFile`) to clan's `users` service. A private machine has neither, so the template ships its own `modules/users/<user>.nix` that creates the account properly, and composes the **same** upstream homeManager modules in `home-profiles/<user>/`. Keep that list matching `home-profiles/pperanich/` and a private host feels identical to log into.

One non-obvious line in that module: `extraSpecialArgs = { inherit pkgs; … }`. home-manager otherwise builds its own nixpkgs without our overlays, and the first upstream home module that wants an overlaid package fails with `attribute 'sops-install-secrets' missing`.

## What this costs

These hosts are not in this repo's clan inventory, so they cannot be a peer in the `pp-wg` wireguard instance, a borgbackup client of `pp-router1`, a syncthing peer, or a holder of the clan's sshd CA certificates. Anything of that kind has to be configured by hand in the private repo. `protonvpn` references `clan.core` directly and will not evaluate outside a clan at all.

If a private machine genuinely needs the mesh, the only arrangement that keeps one fleet is to invert the repos: move the inventory and `vars/`+`sops/` into the private repo, and let this one keep modules, the templates, and no machines. One clan has exactly one `directory`, and that directory is where clan reads `sops/secrets`, `sops/groups` and in-repo vars, so there is no split where public vars stay public and private vars stay private inside one clan.

## Switching

```bash
cd ~/nix-private && nix develop
nh os switch .              # or: sudo nixos-rebuild switch --flake .#<host>
nh darwin switch .          # or: darwin-rebuild switch --flake .#<host>
```

`nh` selects the configuration matching the local hostname, elevates itself, and prints a package diff first. `-H <host>` names another, `-n` is a dry run, and `--target-host <user>@<host>` deploys to a different machine over ssh.
