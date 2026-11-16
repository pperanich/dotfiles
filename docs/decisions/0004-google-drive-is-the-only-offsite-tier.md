# 0004: Google Drive is the only off-site backup tier

## Status

Accepted 2026-11-14. The code is in place; each host is enabled once its token and secrets exist (`docs/backups.md`, "Enable a host").

## Context

The earlier plan sent the NAS off-site twice: restic to a Cloud Storage bucket with object versioning and 30-day soft delete, and restic to Google Drive. Both modules exist (`modules/services/backup/restic-gcs.nix`, `restic-gdrive.nix`).

The Google AI subscription already includes Drive storage far larger than the roughly 80 GB the NAS sends. A bucket would be billed to a card. The monthly Cloud credits that come with the subscription go to another project.

## Decision

- Every Linux host backs up to Google Drive with restic, through one shared Google Cloud project and `drive.file` OAuth client. Each host has its own refresh token and restic password. One project per host would stop a host's token from seeing the others' files, but every External project needs its own branding and publishing; the owner chose one project and accepts the cross-host deletion risk below.
- The Cloud Storage tier stays in the repository, disabled.
- The router keeps its append-only Borg job to the NAS as the copy that can be restored over the LAN while the router, and with it the internet connection, is down.
- The macOS backup is a separate piece of work after this branch merges.

## Consequences

- No monthly cost.
- Drive has no object lock. Someone with root on any host can read its token and delete every host's repository, though not read them. `ResticSnapshotsDropped` reports such a deletion within a day, and a quarterly copy to an unplugged USB disk (`docs/backups.md`, "Offline copy") is the recovery path.
- The project and OAuth client need one-time console setup (branding, publishing, the Desktop client), which no CLI can do. A new host only runs `rclone authorize` against the existing client.
