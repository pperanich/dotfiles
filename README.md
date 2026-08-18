# Dotfiles

Nix-based system configuration using [flake-parts](https://flake.parts/), [clan-core](https://docs.clan.lol/), and the dendritic pattern via [import-tree](https://github.com/vic/import-tree).

## Quick Start

One command on a fresh machine. It clones this repo, installs Determinate Nix
if missing, and switches the configuration matching the machine's hostname:

```bash
curl -fsSL https://raw.githubusercontent.com/pperanich/dotfiles/main/bin/install.sh | bash
```

It prints a plan and asks for confirmation before touching anything. From an
existing checkout, run `./bin/install.sh` instead and it uses that working tree
rather than cloning.

Safe to re-run: the checkout is fast-forwarded (never reset, and skipped
entirely when dirty), Nix is only installed when absent, and each `switch` is
idempotent.

Useful flags:

| Flag            | Purpose                                                   |
| --------------- | --------------------------------------------------------- |
| `--dry-run`     | Print the plan and exit                                   |
| `--host <name>` | Pick a configuration other than the detected hostname     |
| `--home-only`   | Standalone home-manager instead of the system config      |
| `--dir <path>`  | Clone target (default `~/dotfiles`, or `$DOTFILES_DIR`)   |
| `--ref <ref>`   | Branch or tag to use (default `main`, or `$DOTFILES_REF`) |
| `-y`, `--yes`   | Skip the confirmation prompt                              |

`./bin/install.sh --help` lists the rest. Manual setup without the script is
[below](#manual-setup).

Once installed, day-to-day work happens in the dev shell:

```bash
cd ~/dotfiles
nix develop                     # formatters, linters, clan-cli
clan machines update <hostname> # deploy
```

## How It Works

### The One-Liner Flake

The entire flake output is a single expression:

```nix
outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules);
```

`import-tree` recursively discovers every `.nix` file under `modules/` and merges them into one flake-parts module. There are no manual import lists to maintain — drop a file into `modules/` and it becomes part of the flake.

### Three Layers

The configuration is organized into three layers that build on each other:

**1. Flake infrastructure** (`modules/flake-parts/`) — Configures the flake itself: nixpkgs settings, the dev shell, formatting, clan-core integration, and home-manager wiring. These are standard flake-parts modules that set up the plumbing everything else depends on.

**2. Reusable modules** (`modules/`) — Each file exports configuration under `flake.modules.{nixos,darwin,homeManager}.<name>`. For example, `modules/shell/tools.nix` exports `flake.modules.homeManager.tools`, which defines shell packages. A module can export to one platform or all three. This is the "dendritic pattern" — modules grow like branches, each self-contained and independently composable.

```nix
# modules/shell/rust.nix — exports a home-manager module
_: {
  flake.modules.homeManager.rust = { pkgs, ... }: {
    home.packages = with pkgs; [ rustup cargo-edit ... ];
  };
}
```

**3. Machine configurations** (`machines/`) — Each host picks the modules it needs by name. The `modules` attrset is passed as a `specialArg` by clan-core, so machines can simply reference `modules.nixos.base`, `modules.darwin.sops`, etc.

```nix
# machines/pp-ml1/configuration.nix
{ modules, ... }:
{
  imports = with modules.darwin; [
    base sops pperanich rust sketchybar kimaki
  ];
  networking.hostName = "pp-ml1";
  nixpkgs.hostPlatform = "aarch64-darwin";
}
```

### User & Home-Manager Integration

User modules (e.g., `modules/users/pperanich.nix`) bridge system and user config. They export to both `flake.modules.nixos.pperanich` and `flake.modules.darwin.pperanich`, handling:

- System user creation (shell, groups, SSH keys)
- Secrets deployment via sops-nix (the system decrypts secrets _before_ home-manager runs, solving the bootstrap chicken-and-egg)
- Home-manager activation, which loads a **home profile**

**Home profiles** (`home-profiles/`) compose home-manager modules the same way machines compose system modules — by importing from the `homeManager` attrset:

```nix
# home-profiles/pperanich/default.nix
{ homeManager, ... }:
{
  imports = with homeManager; [ base sops nvim rust tools opencode fonts applications ];
  home.username = "pperanich";
}
```

A `generic` profile exists for shared/service accounts, and `mkHomeConfigurations` in `lib/` auto-generates standalone `homeConfigurations` from all profiles (useful for non-NixOS hosts).

### Clan-Core & Inventory

Clan-core manages the machine fleet. `modules/flake-parts/clan.nix` defines the **inventory** — which machines exist, their tags, and which clan services they participate in.

Services are assigned by **roles and tags**. For example, the wireguard instance declares `pp-router1` as the controller and other machines as peers. The borgbackup instance makes `pp-router1` the server and `pp-nas1` a client. Tags like `"all"` or `"nixos"` apply services to groups of machines at once.

Deployment is a single command:

```bash
clan machines update pp-nas1    # builds, uploads, and activates
```

### Secrets: Hybrid Approach

Two systems handle secrets with different strengths:

- **Clan vars** — Machine bootstrap secrets (age keypairs, SSH host keys, user passwords, wireguard keys). Generated with `clan vars generate`, uploaded with `clan vars upload`. These are the foundation that everything else decrypts with.
- **sops-nix** — Application secrets (service passwords, API tokens). Encrypted in `sops/secrets.yaml`, decrypted at activation time using the machine's age key. Modules reference secrets via `sops.secrets.<name>.path`.

### Stow for Dotfiles

Non-Nix config files live in `home/` and are symlinked into `$HOME` via GNU Stow. This runs automatically as a home-manager activation script, so `home-manager switch` handles both Nix-managed and plain dotfiles in one step.

### Custom Packages & Overlays

Custom packages live in `pkgs/` and are built with `nix build .#<name>`. An `additions` overlay in `overlays/` makes them available as regular packages (e.g., `pkgs.runmat`, `pkgs.cf`) across all configurations.

The overlays file (`overlays/default.nix`) serves three purposes:

- **Input overlays** — Pulls in overlays from flake inputs (emacs, neovim-nightly, rust-overlay, ghostty, sops-nix, etc.) so their packages are available in nixpkgs.
- **Additions** — Injects custom packages from `pkgs/` into the package set.
- **Modifications** — Patches or overrides for upstream packages. For example, `atuin` gets a ZFS performance patch, and `my-curl`/`my-git` allow per-machine OpenSSL overrides while keeping a consistent package name.

Every platform's `base` module applies all overlays automatically via `builtins.attrValues`, so there's no per-machine overlay wiring needed.

## Machines

| Hostname   | OS     | Type    | Description                      |
| ---------- | ------ | ------- | -------------------------------- |
| pp-ml1     | Darwin | Laptop  | Personal MacBook (Apple Silicon) |
| pp-ll1     | NixOS  | Laptop  | Personal Linux laptop            |
| pp-ld1     | NixOS  | Desktop | Personal Linux desktop           |
| pp-nas1    | NixOS  | Server  | NAS (BeeLink)                    |
| pp-router1 | NixOS  | Server  | Router                           |
| pp-rpi1    | NixOS  | SBC     | Raspberry Pi 3B+ GPIO debugger   |
| pp-wsl1    | NixOS  | VM      | WSL instance                     |

## Common Commands

```bash
# Development
nix develop                           # Enter dev shell
nix fmt                               # Format all files
nix flake check                       # Validate flake

# Machine deployment
clan machines list                    # List all machines
clan machines update <hostname>       # Deploy to machine
clan vars generate <hostname>         # Generate machine secrets
clan vars upload <hostname>           # Upload secrets only

# Secrets
clan vars list <hostname>             # List vars for machine
clan secrets get <secret>             # Decrypt a secret

# Manual builds
sudo nixos-rebuild switch --flake .#<hostname>    # NixOS
darwin-rebuild switch --flake .#<hostname>        # Darwin
home-manager switch --flake .#<username>          # Home-manager
```

## Starting your own

The same architecture, stripped of everything personal, ships as a flake template:

```bash
nix flake init -t github:pperanich/dotfiles#dendritic
```

It includes the flake-parts/import-tree plumbing, NixOS + Darwin + home-manager base modules, sops-nix wiring, example machines, and an opt-in clan setup. Source: [templates/dendritic/](templates/dendritic/).

A second template covers the other half: machines you would rather not name in a public repo. It is a flake whose only input is a public config you already run, so there is one version to bump and no way for its nixpkgs to drift from the modules it imports.

```bash
nix flake init -t github:pperanich/dotfiles#private
```

It runs no clan and no deployment tool: `machines/<class>/<host>/` becomes a `nixosConfigurations` or `darwinConfigurations` entry, and you switch it with `nixos-rebuild`, `darwin-rebuild` or `nh`. It ships its own user module and home profile composing this repo's home modules, plus the three sops overrides a downstream machine needs. Source: [templates/private/](templates/private/), background in [docs/private-machines.md](docs/private-machines.md).

`bin/install.sh` offers both interactively when it finds no configuration for the machine it is running on.

## Documentation

Detailed guides are available in the [docs/](docs/) directory:

- **[Adding New Machines](docs/adding-new-machines.md)** - Complete onboarding guide
- **[Private Machines](docs/private-machines.md)** - Running hosts from a private flake that consumes this one
- **[Troubleshooting](docs/clan-machines-update-troubleshooting.md)** - Debug deployment issues

## Manual Setup

Skipping the bootstrap script, install Nix:

```bash
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
```

then switch directly:

```bash
# NixOS
sudo nixos-rebuild switch --flake .#<hostname>

# Darwin (first run; afterwards use darwin-rebuild)
nix run nix-darwin -- switch --flake .#<hostname>

# Home-manager (standalone)
nix run home-manager -- switch --flake .#<username>
```

## References

- [Flake-parts](https://flake.parts/)
- [Clan-core](https://docs.clan.lol/)
- [import-tree](https://github.com/vic/import-tree)
- [sops-nix](https://github.com/Mic92/sops-nix)
- [NixOS](https://nixos.org/manual/nixos/stable/)
- [nix-darwin](https://github.com/LnL7/nix-darwin)
- [home-manager](https://nix-community.github.io/home-manager/)

## License

MIT
