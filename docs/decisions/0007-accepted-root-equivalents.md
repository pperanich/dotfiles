# 0007: Accepted root-equivalent access

## Status

Accepted 2026-11-15, recording choices made on 2026-11-11 and 2026-11-13.

## Context

Two settings give root-equivalent power without going through sudo. Both were questioned during the November 2026 security work and both were kept.

## Decision

- **`pperanich` is a trusted Nix user** (`my.pperanich.trustedNixUser`, default true; off on `pp-nas1` and `pp-router1` since [0008](0008-deploys-log-in-as-root.md)). Other users are not. A trusted user can, for example, import unsigned store paths, which is root-equivalent on that host. It keeps remote builds and `nix copy` to the host working without extra signing setup.
- **The console gives a root shell without a password** in initrd and in stage-2 emergency and rescue mode (`modules/flake-parts/hosts.nix`). Root has no password, and console recovery must work even when secrets fail to install. Physical access to these machines already allows booting other media.

## Consequences

- Anyone who can run commands as `pperanich` on a host can become root there without the sudo password.
- Anyone at a host's keyboard can get a root shell by booting into emergency mode. Disk encryption (the `nas-zfs-encryption` branch) is what would change that for the NAS.
- Set `my.pperanich.trustedNixUser = false` on a host where remote builds are not needed.
