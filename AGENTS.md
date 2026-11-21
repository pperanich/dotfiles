# AGENTS.md - Dotfiles Repository Guide

Guidelines for AI agents working in this Nix-based dotfiles repository.

## Build/Lint/Test Commands

### Primary Commands

```bash
# Enter development shell (treefmt, sops, ssh-to-age, age-plugin-yubikey, deploy-rs, nh, home-manager)
nix develop

# Format all files (Nix, JSON, YAML, Shell, Lua)
nix fmt

# Check flake for errors
nix flake check

# Update all flake inputs except the pinned ones (never a bare `nix flake update`)
bin/update-inputs.sh

# Update specific inputs
bin/update-inputs.sh nixpkgs home-manager

# Before deploying an update: what each host would compile instead of download
bin/build-report.sh

# After adding a private input: only the named hosts may fetch it (tests committed HEAD)
bin/check-private-input.sh feed-me pp-nas1
```

### Flake inputs

- Every host follows `nixpkgs` on `nixpkgs-unstable` ([decision 0005](docs/decisions/0005-nixpkgs-unstable-for-every-host.md)); home-manager, nix-darwin and nixos-wsl follow their main branches. Run `bin/build-report.sh` before deploying an update, and snapshot the NAS before one that upgrades a service with a database.
- Inputs that provide modules or `lib` (home-manager, nix-darwin, sops-nix, disko, deploy-rs) follow `nixpkgs`. Package inputs with their own binary cache (llm-agents) do not, or their cache never matches. Other package inputs follow `nixpkgs`; they compile either way.
- Pinned in `bin/update-inputs.sh`: `nix-apple-fonts` (a bump rebuilds every font) and `nixpkgs-mongodb` (UniFi's MongoDB compiles for hours on the router). The personal site keeps its own nixpkgs, whose flake still evaluates `x86_64-darwin`.

### System Build Commands

```bash
# Darwin (pp-ml1 has no sshd, so it always switches locally)
nh darwin switch . -H pp-ml1

# NixOS hosts: deploy-rs builds on the target, activates, and rolls back if
# it cannot reconnect (needs the dev shell; logs in as root with pp-ml1's key)
deploy .#pp-wsl1                                  # target pp-wsl1.pp-ts
deploy --hostname pp-nas1.pp-ts .#pp-nas1             # tailnet names: Nix-launched ssh on
deploy --hostname pp-router1.pp-ts .#pp-router1       # the Mac cannot resolve home.arpa

# Build or dry-run without activating
deploy --dry-activate --hostname pp-router1.pp-ts .#pp-router1
nh darwin build . -H pp-ml1

# Evaluation checks (Linux closures build on their targets, not on the Mac)
nix flake check --no-build
nix build --no-link .#checks.aarch64-darwin.{treefmt,hosts-eval,deploy-nodes-eval,backup-module-eval}
```

Deploy nodes are defined in `modules/flake-parts/deploy.nix`. `pp-rpi1` is powered off until it is re-imaged, so it has no node; its configuration still evaluates.

### Hostnames Reference

- `pp-ml1` - Darwin laptop (Apple Silicon), the only admin machine
- `pp-nas1` - NixOS NAS (BeeLink MeMini)
- `pp-router1` - NixOS router, also runs Headscale
- `pp-rpi1` - NixOS Raspberry Pi, powered off until re-imaged
- `pp-wsl1` - WSL instance

## Architecture Overview

This is a **dendritic Nix flake** using:

- **flake-parts**: Composable flake architecture
- **import-tree**: Automatic module discovery (all `.nix` files in `/modules` auto-imported)
- **`modules/flake-parts/hosts.nix`**: Builds every `machines/<host>/configuration.nix` as a `nixosConfigurations` or `darwinConfigurations` entry; the class comes from the `nixpkgs.hostPlatform` that file declares
- **deploy-rs**: Remote NixOS deployment with rollback (`modules/flake-parts/deploy.nix`)
- **sops-nix**: One encrypted file per host, decrypted with the host's SSH key
- **Headscale and Tailscale**: Remote access. Headscale runs on `pp-router1`, every host runs a Tailscale client, and tailnet names are `<host>.pp-ts`. `home.arpa` names resolve on the LAN only
- **GNU Stow**: Dotfiles deployment (runs automatically as a home-manager activation script)

### Module Export Pattern

Every module exports to `flake.modules.<platform>.<name>`:

```nix
# modules/example/foo.nix
_: {
  flake.modules.homeManager.foo = { pkgs, ... }: { ... };
  flake.modules.nixos.foo = { ... }: { ... };
  flake.modules.darwin.foo = { ... }: { ... };
}
```

## Code Style Guidelines

### Nix Formatting

Enforced via treefmt-nix with:

- `nixfmt` - Nix files
- `deadnix` - Remove dead code
- `statix` - Linting/suggestions
- `shfmt` - Shell scripts
- `stylua` - Lua files
- `prettier` - JS/TS/MD
- `jsonfmt` - JSON
- `yamlfmt` - YAML

Run `nix fmt` before committing.

### Nix Code Conventions

```nix
# Function arguments: use destructuring with trailing comma
{ inputs, config, lib, pkgs, ... }:

# Let bindings for complex expressions
let
  overlays = import ../../overlays { inherit inputs; };
in
{ ... }

# Use `with` sparingly, prefer explicit references
home.packages = with pkgs; [ ripgrep fd ];

# Module imports: use `with` for readability in import lists
imports = with modules.darwin; [ base rust ];

# Attribute sets: align colons for readability in small sets
{ name = "foo"; value = 42; }

# Platform conditionals
++ lib.optionals pkgs.stdenv.hostPlatform.isDarwin [ ... ]
++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [ ... ]
```

### Naming Conventions

- **Machines**: `{prefix}-{os}{type}{num}` or `{prefix}-{role}{num}` for dedicated-role machines
  - Prefix: `pp` for personal
  - OS codes: `l`=Linux, `m`=macOS, `wsl`=WSL
  - Type codes: `l`=laptop, `d`=desktop
  - Role names: `nas`, `rpi` for dedicated-purpose machines
  - Examples: `pp-ml1` (macOS Laptop 1), `pp-nas1` (NAS 1), `pp-rpi1` (Raspberry Pi 1)
- **Modules**: lowercase, kebab-case filenames (e.g., `cloudflare-dns.nix`, `cloudflare-tunnel.nix`)
- **Export names**: camelCase (e.g., `cloudflareDns`, `cloudflareTunnel`, `routerFirewall`)
- **Functions**: camelCase in lib (e.g., `mkHomeConfigurations`, `relativeToRoot`)
- **Custom options**: Use `my.*` namespace (e.g., `my.router.*`, `my.jellyfin.*`, `my.pperanich.desktop`)
- **Upstream-style modules**: Use `services.*` only for modules structured like upstream NixOS modules (none at present)

### Directory Structure

```
/modules/           # Auto-imported modules (dendritic pattern)
  flake-parts/      # Flake infrastructure (hosts, deploy, nixpkgs, fmt, shell)
  desktop/          # Desktop apps (fonts, applications, sketchybar)
  router/           # NixOS router framework (firewall, DHCP, DNS, VLANs)
  services/         # Self-hosted services (immich, nextcloud, vaultwarden, etc.)
  shell/            # Shell environment (nvim, opencode, rust, tools)
  system/           # Core system configs (base, sops, tailscale)
  users/            # User account modules (pperanich)
/machines/          # Host-specific configurations
/home-profiles/     # User environment compositions
/home/              # Raw dotfiles (symlinked via stow activation)
/docs/              # Guides (adding machines, secrets, services)
/lib/               # Custom library functions (lib.my.*)
/overlays/          # Nixpkgs overlays
/pkgs/              # Custom package definitions
/agent-kit/         # Guards and hooks for Claude Code, Codex and pi (see agent-kit/README.md)
/bin/               # Install and helper scripts
/templates/         # Flake templates (dendritic, private)
/sops/              # Encrypted secrets (machines/<host>.yaml, users/, cloudflared-tunnel.json, .sops.yaml)
```

### Error Handling

- Prefer `lib.mkIf` for conditional enabling
- Use `lib.optionals` for conditional list items
- Use `lib.mkDefault` for overridable defaults
- Never use `builtins.throw` unless truly unrecoverable

### Module Best Practices

1. Single responsibility per module
2. Export to correct platform (`nixos`, `darwin`, `homeManager`)
3. Provide sensible defaults
4. Use `lib.my.relativeToRoot` for path references
5. Minimize cross-module dependencies

### Design Rules

These apply to new and rewritten code. Existing code is brought into line when it is next touched.

1. The owning module registers itself: a service declares its own SQLite path, alert, insecure-package permit and mount dependency.
2. No host names under `modules/`. Options are named by role; anything about one machine lives in `machines/`.
3. No `config.x or false` across modules. If two modules need the same fact, one declares an option for it.
4. Programs over about 30 lines live in `pkgs/` or `bin/`, not in Nix strings.
5. Comments: two lines at most, no finding or decision codes, no history.
6. Every transition flag names the step that removes it.
7. Anything that moves data or repartitions is rehearsed on a throwaway target before review.
8. A departure from an agreed plan gets a short decision record in the same change.

### Secrets in Modules

The module that knows an env var name owns the template. Machines name sops
keys; they never spell `SOME_TOKEN=`.

```nix
options.my.svc.adminPasswordSecret = lib.mkOption { type = with lib.types; nullOr str; default = null; };

config = {
  assertions = [{
    assertion = cfg.adminPasswordSecret != null;
    message = "my.svc.adminPasswordSecret is unset; the service would start without a password.";
  }];

  sops.templates."svc.env" = {
    content = "IDM_ADMIN_PASSWORD=${config.sops.placeholder.${cfg.adminPasswordSecret}}";
    owner = "svc";
    restartUnits = [ "svc.service" ];  # rotation takes effect on activation
  };
};
```

- Gate `mkIf` on the service's own `enable`, never on whether a secret happens
  to be set — a missing secret should be a loud assertion, not a silent skip.
- `restartUnits` on every template, or a rotated secret sits unused until reboot.
- `sops.validateSopsFiles = true` (set in `modules/system/sops.nix`) makes a key
  missing from the host's sops file a build failure rather than an activation one.
  Key names are plaintext in a sops file, so the check decrypts nothing.
- When a machine must reference a var name (e.g. inside a Caddy vhost), export
  it from the module as a read-only option. Note `{$''${var}}` inside an
  indented string is a literal-`$` escape, not an interpolation — build such
  strings by concatenation (see `my.radicale.basicAuthHashPlaceholder`).
- `EnvironmentFile` is read by PID 1 before the unit drops privileges, so the
  rendered file needs no per-service `owner`. Prefer `LoadCredential` where the
  service supports it.

## Special Files and Patterns

### Extended Library

Custom functions available as `lib.my.*`:

- `lib.my.relativeToRoot` - Path relative to flake root
- `lib.my.getHomeDirs` - Discover home profile directories
- `lib.my.mkHomeConfigurations` - Generate home-manager configs

### Overlays (`/overlays/default.nix`)

Applied globally to nixpkgs. Use for:

- Version pinning
- Patch application
- Package modifications

### Secrets

All secrets are sops-nix secrets, encrypted with age. There is one file per host and no shared file:

- `sops/machines/<host>.yaml` for each host
- `sops/users/pperanich-desktop.yaml` for the API keys home-manager reads on the admin workstation
- `sops/cloudflared-tunnel.json` for the tunnel credential (admin recipients and `pp-router1`)

Rules live in `sops/.sops.yaml`. Every file is encrypted to the admin age key, two YubiKey recipients, and that host's age key (derived from its SSH host key). A host decrypts with `/etc/ssh/ssh_host_ed25519_key` alone (`sops.age.keyFile = null`); home-manager decrypts with `~/.config/sops/age/keys.txt`. Modules reference secrets via `sops.secrets.<name>.path`.

```bash
# Edit a file (--config is needed outside the dev shell, which exports SOPS_CONFIG)
sops --config sops/.sops.yaml sops/machines/<hostname>.yaml

# After changing recipients in sops/.sops.yaml
sops --config sops/.sops.yaml updatekeys sops/machines/<hostname>.yaml
```

Encrypting to the YubiKey recipient needs `age-plugin-yubikey` on `PATH`. Encrypted files are excluded from treefmt in `modules/flake-parts/fmt.nix`; keep new ones under those globs. See [docs/secrets-and-key-management.md](docs/secrets-and-key-management.md).

Never commit plaintext secrets.

## Pre-commit Hooks

Configured via git-hooks.nix:

- `nix-fmt`: Auto-format on commit

## Common Pitfalls

Fleet operations (sudo in a visible pane, secrets via the clipboard, snapshots before upgrades) and a table of known traps are in [docs/operations.md](docs/operations.md).

1. **Module not found**: Check export path matches `flake.modules.<platform>.<name>`
2. **Stow conflicts**: Check `/home` directory for file conflicts
3. **State version mismatch**: Keep `stateVersion` consistent
4. **Overlay order**: Overlays in `/overlays/default.nix` apply globally

## Testing Changes

```bash
# Quick syntax check
nix flake check

# Build without switching (dry-run)
nixos-rebuild build --flake .#<hostname>
darwin-rebuild build --flake .#<hostname>

# Show what would change
nvd diff /run/current-system result
```

## Commit Guidelines

- Use conventional commits: `feat:`, `fix:`, `docs:`, `refactor:`, `chore:`
- Test locally before committing
- Run `nix fmt` before commit (enforced by pre-commit hook)
