# Dendritic Nix configuration

NixOS + nix-darwin + home-manager in one flake, built from [flake-parts](https://flake.parts) and [import-tree](https://github.com/vic/import-tree).

Every `.nix` file under `modules/` is imported automatically. There is no import list to keep in sync: a module is one concern, and it exports itself to whichever platforms need it.

```nix
# modules/shell/tools.nix
{ ... }:
{
  flake.modules = {
    nixos.tools = { pkgs, ... }: { environment.systemPackages = [ pkgs.ripgrep ]; };
    darwin.tools = { pkgs, ... }: { environment.systemPackages = [ pkgs.ripgrep ]; };
    homeManager.tools = { pkgs, ... }: { home.packages = [ pkgs.ripgrep ]; };
  };
}
```

A machine is then just a list of those names:

```nix
imports = with modules.nixos; [ base sops example tools ];
```

## Layout

```
flake.nix                    inputs only; outputs come from ./modules
modules/
  flake-parts/               the flake's own plumbing
    flake-parts.nix          enables flake.modules.<class>.<name>
    nixpkgs.nix              systems, overlays, lib.my.*
    systems.nix              machines/ -> nixos/darwinConfigurations
    home.nix                 home-profiles/ -> homeConfigurations
    private.nix              optional private repo of machines/modules
    fmt.nix                  treefmt
    shell.nix                nix develop
    packages.nix             pkgs/ -> nix build .#name
  system/base.nix            baseline config, all three platforms
  system/sops.nix            secrets wiring, all three platforms
  users/example.nix          system user + its home profile
machines/nixos/<host>/       one dir per NixOS host
machines/darwin/<host>/      one dir per macOS host
home-profiles/<user>/        composition of homeManager modules
lib/default.nix              helpers, exposed as lib.my.*
overlays/default.nix         applied to every pkgs in the repo
pkgs/                        custom packages
sops/                        .sops.yaml + encrypted secrets.yaml
optional/clan/               opt-in multi-machine deployment
docs/sops.md                 secrets walkthrough
docs/private-repo.md         keeping real machines out of a public repo
```

## Getting started

```bash
nix flake init -t github:you/your-config#dendritic   # or copy this directory
git init && git add -A                               # flakes only see tracked files
nix develop
nix flake check
```

Then, in order:

1. **Rename the example user.** `modules/users/example.nix` (filename + the `username` binding), `home-profiles/example/`, and the `example` entry in each machine's imports.
2. **Set up secrets.** Follow `docs/sops.md`. Nothing switches successfully until `sops/secrets.yaml` is real — the shipped file is an unencrypted placeholder.
3. **Replace the example machines.** Drop real hardware config into `machines/nixos/<host>/hardware-configuration.nix`, fix `networking.hostName` and `nixpkgs.hostPlatform`, delete the class dir you don't need.

## Deploying

```bash
sudo nixos-rebuild switch --flake .#example-nixos
darwin-rebuild switch --flake .#example-darwin
home-manager switch --flake .#example        # standalone, no system config
nix build .#hello-dendritic                  # custom package smoke test
```

## Conventions worth keeping

- One concern per module file; export to every platform that needs it.
- Custom options live under `my.*`. Use `services.*` only for modules shaped like upstream NixOS ones.
- Filenames kebab-case, export names camelCase (`cloudflare-dns.nix` exports `cloudflareDns`).
- Repo-wide helpers go in `lib/default.nix` and are reached as `lib.my.<name>` (the extended lib is passed to machines via `specialArgs`).
- `nix fmt` before committing — `nix flake check` fails on unformatted files. To enforce it on commit, add [git-hooks.nix](https://github.com/cachix/git-hooks.nix) and point its `treefmt` hook at `config.treefmt.build.wrapper`. It is left out here because its `pre-commit` closure is expensive to build on macOS when the binary cache misses.

## Adding things

**A module**: create `modules/<area>/<name>.nix` exporting `flake.modules.<class>.<name>`. It is live immediately; add the name to a machine's imports to use it.

**A machine**: `mkdir machines/nixos/<host>`, add `configuration.nix` (copy the example), generate `hardware-configuration.nix`, add the host's age recipient to `sops/.sops.yaml`, run `sops updatekeys sops/secrets.yaml`.

**A user**: copy `modules/users/example.nix` and `home-profiles/example/`, add password and SSH key entries to `sops/secrets.yaml`.

## Private machines

Uncomment the `private` input in `flake.nix` to pull hosts and modules from a separate private flake, and they join `nixosConfigurations` / `darwinConfigurations` alongside the local ones. The private repo needs no inputs of its own — it exports paths. While the input stays commented out, `modules/flake-parts/private.nix` contributes nothing, so a fresh clone still evaluates. Details in [docs/private-repo.md](docs/private-repo.md).

## Multi-machine deployment

Past a few hosts, `optional/clan/README.md` covers swapping `systems.nix` for a [clan](https://clan.lol) inventory: tag-based service assignment and generated per-machine secrets.
