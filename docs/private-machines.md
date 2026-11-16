# Private machines in a separate flake

This repo is public and serves a flake template, so it can never declare a private input: evaluating `templates.dendritic` evaluates the whole module tree, and a repo nobody else can fetch would break `nix flake init -t` for everyone. See `templates/dendritic/docs/private-repo.md` for the measurements.

The private flake consumes this one and builds its own hosts. Local switches use `nixos-rebuild`, `darwin-rebuild`, or `nh`; the template also includes an optional deploy-rs module for remote deployment with rollback.

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

`modules/flake-parts/hosts.nix` turns `machines/<host>/` into `nixosConfigurations`/`darwinConfigurations`, choosing the builder from the `nixpkgs.hostPlatform` declared directly in each `configuration.nix`. It passes the merged module tree and upstream library as specialArgs:

```nix
{ modules, ... }:
{
  imports = [ ./hardware-configuration.nix ] ++ (with modules.nixos; [ base sops secretuser ]);

  sops = {
    defaultSopsFile = ../../sops/secrets.yaml;
    age = {
      keyFile = null;
      sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    };
  };

  networking.hostName = "secret-host";
  nixpkgs.hostPlatform = "x86_64-linux";
}
```

The default has one direct input. Optional deploy-rs adds a second input while keeping its activation package on upstream's nixpkgs. See the [template setup guide](../templates/private/README.md) and [deployment guide](../templates/private/optional/deploy-rs/README.md).

## Pass your own `self`

`mkFlake` needs `inputs`, and it is tempting to write `inputs = upstream.inputs // { self = upstream; }` to satisfy it. Don't: `self` is what `machines/` resolves against, so that makes the private flake enumerate **this** repo's machines. Write `upstream.inputs // inputs` and let your own `self` land on top.

## Secrets

The private repo owns its own `sops/secrets.yaml`, encrypted to your admin key and to each host's age key (derived from its SSH host key with `ssh-to-age`). Three settings in the machine file make that work:

| setting                   | why                                                                                                     |
| ------------------------- | ------------------------------------------------------------------------------------------------------- |
| `sops.defaultSopsFile`    | upstream points a host at `sops/machines/<host>.yaml` in this repo, which a private host cannot decrypt |
| `sops.age.keyFile = null` | upstream already sets this: the host decrypts with its SSH host key alone                               |
| `sops.age.sshKeyPaths`    | the host key sops reads; upstream already sets `/etc/ssh/ssh_host_ed25519_key`                          |

Only `defaultSopsFile` has to change. `modules/system/sops.nix` sets it, `keyFile` and `validateSopsFiles` with `lib.mkOverride 900` specifically so a plain assignment downstream wins. If a future edit makes any of them a plain assignment upstream, every private machine that assigns it breaks with `has conflicting definition values`.

Every module a private machine imports brings its declared keys with it, and `validateSopsFiles = true` means a key missing from the private `secrets.yaml` fails the build rather than the activation:

```
sops-install-secrets: manifest is not valid: secret passwords/example in
/nix/store/…-secrets.yaml is not valid: the key 'passwords' cannot be found
```

The homeManager `sops` module declares no secrets itself. The private template offers an optional local `apiKeys` replacement that discovers names under its own `api_keys` mapping instead of requiring upstream's fixed provider list. Keep secret declarations separate from shared SOPS wiring.

System decryption must use the persistent host key, including on macOS: enable Remote Login and create the host keys before the first Darwin activation. Home Manager decrypts with the user's own `~/.ssh/id_ed25519`, which never goes into `secrets.yaml`, so encrypt to each host's recipient and to the user key's recipient on every machine that user logs in to.

## The user module is copied, not imported

`modules/users/pperanich.nix` here creates the `pperanich` account, authorizes the login keys in `lib/default.nix` (`sshKeys`) and imports `home-profiles/pperanich`. A private machine wants its own user and keys, so the template ships its own `modules/users/<user>.nix`, and composes the **same** upstream homeManager modules in `home-profiles/<user>/`. Keep that list matching `home-profiles/pperanich/` and a private host feels identical to log into.

One non-obvious line in that module: `extraSpecialArgs = { inherit pkgs; … }`. home-manager otherwise builds its own nixpkgs without our overlays, and the first upstream home module that wants an overlaid package fails with `attribute 'sops-install-secrets' missing`.

## What this costs

These hosts are not in this repo's `machines/`, so this repo knows nothing about them. They have no deploy-rs node here, no entry in `lib/ssh-host-keys.nix` (so the fleet does not pin their host keys), and no recipient in `sops/.sops.yaml`. They are not Headscale nodes until you enroll them, and they are not a borg client of `pp-router1` unless the private repo configures it. Anything of that kind has to be set up by hand in the private repo.

A private machine can join the tailnet by importing the upstream `tailscale` module and enrolling with a tagged pre-auth key, as in [Adding New Machines](adding-new-machines.md).

## Switching

```bash
cd ~/nix-private && nix develop
nh os switch .              # or: sudo nixos-rebuild switch --flake .#<host>
nh darwin switch .          # or: darwin-rebuild switch --flake .#<host>
```

`nh` selects the configuration matching the local hostname, elevates itself, and prints a package diff first. `-H <host>` names another, `-n` is a dry run, and `--target-host <user>@<host>` deploys to a different machine over ssh.

After the first activation and a new shell, `NH_OS_FLAKE` or `NH_DARWIN_FLAKE` selects this repo and its machine directory automatically. `lib/repo.nix` supplies the home-relative checkout path for both these defaults and the private `home/` Stow activation. A shared home profile uses `my.<user>.desktop` to select desktop imports through explicit Home Manager `extraSpecialArgs`.
