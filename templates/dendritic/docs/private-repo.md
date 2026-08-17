# Keeping machines in a private repo

The public repo holds the architecture; a private flake input holds the hosts you'd rather not publish (real hostnames, IPs, VPN topology, service layout).

## Does a private input break `nix flake init -t`?

No. `nix flake init` copies the template's files and stops — it never reads the new flake's inputs, so no lock and no fetch happens. The private input only matters at `nix flake lock` / `nix flake check` / build time, and only for someone who lacks access.

Two consequences worth being deliberate about:

- **The input must be commented out in the committed template**, which it is. Otherwise the first `nix flake check` someone runs fails on a repo they can't clone.
- **Never add a private input to the flake that _serves_ the template.** Evaluating `templates.<name>` evaluates that flake's outputs, which does pull its inputs.

## Shape of the private repo

It needs no flake-parts, no import-tree, no inputs at all — just paths:

```nix
# nix-private/flake.nix
{
  description = "Private machines and modules";

  outputs = _: {
    # Picked up by modules/flake-parts/systems.nix
    machines = {
      nixos.secret-host = ./machines/secret-host/configuration.nix;
      darwin.work-laptop = ./machines/work-laptop/configuration.nix;
    };

    # Merged into flake.modules by modules/flake-parts/private.nix
    modules.nixos.vpnTopology = ./modules/vpn-topology.nix;

    # Imported as a flake-parts module — perSystem packages, overlays,
    # extra flake outputs, anything modules/flake-parts/ can do
    flakeModules.default = ./flake-modules/private.nix;
  };
}
```

An inputless flake locks instantly and adds nothing to your dependency graph. All three exports are optional; the readers use `or` fallbacks.

## Which side may reference which

**Private → public: yes.** The public flake is what evaluates the private files, so they get the same `specialArgs` local ones do. A private machine imports public modules by name:

```nix
{ modules, ... }:
{
  imports = with modules.nixos; [ base sops example vpnTopology ];
  networking.hostName = "secret-host";
  nixpkgs.hostPlatform = "x86_64-linux";
}
```

`vpnTopology` there is the private repo's own module, sitting in the same `modules.nixos` namespace as the public ones. Private flake-parts modules likewise see `config.flake`, `inputs`, and everything the public modules see.

This is not a flake cycle: the private repo exports paths and declares no dependency on the public one.

**Public → private: only at the cost of a standalone-evaluable public repo.** Reference a private module from a public machine and, without the input, evaluation dies:

```
error: undefined variable 'vpnTopology'
```

So the rule is one-directional: public modules stay self-contained, private files may consume them. If a public machine genuinely needs private data, put the _machine_ in the private repo, or guard the import with `lib.optionalAttrs`/`or` in the same style `private.nix` uses.

Mutual flake inputs (each declaring the other) do lock — each side pins a revision, so there's no true cycle — but it makes bootstrapping and updates miserable for no gain. The path-export design avoids needing it.

## Layout trap

Keep machine files **outside** any directory swept by import-tree. A `configuration.nix` under `modules/` gets loaded as a flake-parts module and fails with an infinite-recursion error, because machine configs reference `modules` in their `imports`.

## Activating it

```bash
# flake.nix: uncomment and point at your repo
#   private.url = "git+ssh://git@github.com/you/nix-private";
nix flake lock
nixos-rebuild switch --flake .#secret-host
```

`git+ssh://` authenticates with your SSH agent, which is the least friction. The `github:you/nix-private` form needs a token in `nix.conf` instead:

```
access-tokens = github.com=ghp_...
```

Deploy hosts need their own access. A NixOS builder pulling the flake itself needs the key; if you build locally and push closures (`nixos-rebuild --target-host`), only your workstation needs it.

Local iteration without committing to the private repo:

```bash
nix flake lock --override-input private path:/home/you/src/nix-private
# or per-command
nixos-rebuild build --flake .#secret-host --override-input private path:../nix-private
```

## What still leaks

`flake.lock` records the private repo's URL, revision, and commit timestamp. If the public repo is public, that metadata is public: the repo's existence, its name, and your commit cadence. The contents stay private. If even that is too much, use a git submodule (`nix build '.?submodules=1#...'`) or keep the whole configuration private and publish only the template.

## Secrets

Secrets belong in sops either way — a private repo is not an encryption strategy. The private flake can carry its own `sops/secrets.yaml` and reference it by relative path from its own modules; paths resolve against the input's store copy, so nothing needs to change in `modules/system/sops.nix`. `sops updatekeys` runs in whichever repo owns the file.
