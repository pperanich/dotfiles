# AGENTS.md - Dotfiles Repository Guide

Guidelines for AI agents working in this Nix-based dotfiles repository.

## Build/Lint/Test Commands

### Primary Commands
```bash
# Enter development shell (includes formatters, linters, clan-cli)
nix develop

# Format all files (Nix, JSON, YAML, Shell, Lua)
nix fmt

# Check flake for errors
nix flake check

# Update all flake inputs
nix flake update

# Update specific input
nix flake update nixpkgs
```

### System Build Commands
```bash
# NixOS system rebuild
sudo nixos-rebuild switch --flake .#<hostname>

# Darwin (macOS) system rebuild
darwin-rebuild switch --flake .#<hostname>

# Home-manager standalone
home-manager switch --flake .#<username>

# Via clan-core (preferred for multi-machine)
clan machines update <hostname>
clan machines list
clan machines show <hostname>
```

### Hostnames Reference
- `peranpl1-ml1`, `peranpl1-ml2` - Darwin laptops (x86_64-darwin)
- `pperanich-ml1` - Darwin laptop
- `pperanich-ll1` - NixOS laptop (MacBook w/ T2)
- `pperanich-ld1` - NixOS desktop
- `pperanich-lm1` - NixOS mini
- `pperanich-wsl1` - WSL instance

## Architecture Overview

This is a **dendritic Nix flake** using:
- **flake-parts**: Composable flake architecture
- **import-tree**: Automatic module discovery (all `.nix` files in `/modules` auto-imported)
- **clan-core**: Infrastructure-as-code machine deployment
- **GNU Stow**: Legacy dotfiles deployment

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
- **Machines**: `{user}-{os}{type}{num}` (e.g., `pperanich-ll1` = Linux Laptop 1)
  - OS: `l`=Linux, `m`=macOS, `w`=Windows, `wsl`=WSL
  - Type: `l`=laptop, `d`=desktop, `m`=mini, `raspi`=Raspberry Pi
- **Modules**: lowercase, descriptive (e.g., `nix-configuration.nix`, `ssh-server.nix`)
- **Functions**: camelCase in lib (e.g., `mkHomeConfigurations`, `relativeToRoot`)
- **Options**: follow upstream conventions

### Directory Structure
```
/modules/           # Auto-imported modules (dendritic pattern)
  flake-parts/      # Flake infrastructure (fmt, shell, clan, nixpkgs)
  system/           # Core system configs (nix, sops, backups)
  shell/            # Shell environments (zsh, tools)
  editors/          # Editor configs (nvim, emacs, vscode)
  desktop/          # Desktop apps (fonts, yabai, skhd)
  network/          # Network services (tailscale, ssh)
  users/            # User account modules
  languages/        # Language-specific (rust, tex)
  virtualization/   # Docker, qemu, lxd
/machines/          # Host-specific configurations
/home-profiles/     # User environment compositions
/home/              # Raw dotfiles (deployed via stow)
/lib/               # Custom library functions (lib.my.*)
/overlays/          # Nixpkgs overlays
/pkgs/              # Custom package definitions
/sops/              # Encrypted secrets
/vars/              # Non-secret variables
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
Managed via sops-nix with age encryption:
```bash
# Edit secrets (requires age key)
sops sops/secrets.yaml
```
Never commit plaintext secrets.

## Pre-commit Hooks
Configured via git-hooks.nix:
- `nix-fmt`: Auto-format on commit

## Common Pitfalls
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
