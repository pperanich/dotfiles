# 0009: hermes-agent keeps its own nixpkgs

## Status

Accepted 2026-11-21.

## Context

AGENTS.md has module and package inputs follow `nixpkgs`. With `hermes-agent` v0.23.3 following it, pp-nas1 failed to build: Hermes patches `patchelf` with upstream commit `59acc3d` (NixOS/patchelf#672) to stop autoPatchelf corrupting its prebuilt node, and that patch targets patchelf 0.19.2. Our nixpkgs ships patchelf 0.15.2, where 4 of its 6 hunks fail, taking ffmpeg, node, pnpm and Hermes down with it.

`patchelfUnstable` (0.19.2-unstable-2026-10-20) already contains `59acc3d`, so handing it to Hermes would fail the same patch as already applied. Hermes publishes a Cachix cache (`hermes-agent.cachix.org`), but it does not hold the package pp-nas1 builds.

## Decision

- `hermes-agent` uses the nixpkgs pinned in its own lock file (`02c087f`, patchelf 0.19.2), the combination its CI tests.
- Lock it with `nix flake update hermes-agent`, which takes Hermes's lock file. `nix flake lock` after removing the follow resolved Hermes's `nixos-unstable` URL fresh instead, to a revision with patchelf 0.15.2.

## Consequences

- pp-nas1 carries a second nixpkgs closure for Hermes. Its paths are on cache.nixos.org, so it costs download, not compiles: the dry run builds only patchelf, Python wheel installs, the webapp and TUI, and autoPatchelf over Hermes's prebuilt node, ffmpeg and pnpm.
- Revisit when Hermes drops its patchelf override or nixpkgs' default patchelf reaches a release containing `59acc3d`; then `hermes-agent` can follow `nixpkgs` again.
