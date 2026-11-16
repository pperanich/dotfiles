# 0005: Every host follows nixpkgs-unstable

## Status

Accepted 2026-11-15.

## Context

The hosts followed the 26.05 release: `nixos-26.05` for NixOS and, briefly, `nixpkgs-26.05-darwin` for the Mac, because each channel only advances once Hydra has built its platform. A dry-run of every host after an input update showed that most source builds came from overlays, unfree or insecure packages and our own packages, not from the channel. Immich 2.7.5 in 26.05 is end-of-life with known CVEs, which also keeps Hydra from building it.

## Decision

- One input, `nixpkgs` on `nixpkgs-unstable`, for every host. That channel advances only once Hydra's trunk jobset has built it for Linux and darwin, so both platforms download from the binary cache.
- home-manager, nix-darwin and nixos-wsl follow their main branches, which track unstable.
- Pinned on purpose, outside the rolling channel: `nix-apple-fonts` (its fonts rebuild on any bump), `nixpkgs-mongodb` (UniFi's MongoDB, unfree and hours to compile on the router), and the personal site's own nixpkgs (its flake still evaluates `x86_64-darwin`, which unstable dropped).

## Consequences

- No release bump every six months; instead, option renames and major service upgrades arrive with whichever weekly update carries them. `bin/build-report.sh` before a deploy, and a ZFS snapshot of the NAS before a deploy that upgrades a service with a database.
- `nixpkgs-unstable` is not gated on NixOS's own tests, unlike `nixos-unstable`. A broken boot or service is caught by deploy-rs's rollback for activation failures only.
- The first move (2026-11-15) carried major upgrades: Immich 3, Paperless 3, Jellyfin 12, Home Assistant 2026.11, Gitea 28 and Grafana 13.
