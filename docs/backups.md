# Backups

Three layers, each on its own schedule:

| Layer                  | What                                                                         | Where                                                        | Schedule                    |
| :--------------------- | :--------------------------------------------------------------------------- | :----------------------------------------------------------- | :-------------------------- |
| ZFS snapshots          | `rpool/tank`, `tank/appdata`, `tank/backups`, `rpool/home` on `pp-nas1`      | the NAS pool (Sanoid)                                        | hourly, daily, monthly      |
| Borg                   | router state: Vaultwarden, Gitea, Headscale, UniFi backups, SQLite snapshots | append-only repo on the NAS, `/tank/backups/borg/pp-router1` | 02:00                       |
| Restic to Google Drive | each Linux host's state, encrypted by restic                                 | `restic-backups/<hostname>` in Google Drive                  | 04:00 plus up to 45 minutes |

Postgres dumps land in `/tank/backups/postgres` at 01:15, so the 04:00 run carries them off-site, and the router's Borg repo with them.

The Google Drive tier is defined in `modules/services/backup/restic-gdrive.nix` and switched on per host with `my.backup.googleDrive.enable`. `restic-gcs.nix` (a Cloud Storage bucket with soft delete) exists but is not enabled anywhere.

## What each host sends to Drive

- `pp-nas1`: all of `/tank`, `/var/lib` and `/home`, minus Immich thumbnails and transcoded video and the films and TV folders. The run first snapshots `rpool/tank`, `rpool/tank/appdata`, `rpool/tank/backups`, `rpool/var` and `rpool/home` in one atomic `zfs snapshot` and reads from those snapshots, so every database file is captured at the same instant. It refuses to start unless a finished, non-empty Postgres dump (`all.sql.*`) newer than 26 hours exists.
- `pp-router1`: the same paths and excludes as its Borg job, after the same SQLite `.backup` step.
- `pp-wsl1`: `/home/pperanich`, minus caches and build output.
- `pp-ld1`, `pp-rpi1`: import the module, enabled when they are re-imaged.
- `pp-ml1`: not covered by this tier; the macOS backup is a separate piece of work.

Each run backs up, prunes to 7 daily, 4 weekly and 12 monthly snapshots, then reads back 2% of the repository's data (`restic check --read-data-subset=2%`).

## Monitoring

- `restic_last_success_timestamp_seconds{repo="gdrive"}` and `restic_snapshots_total{repo="gdrive"}` go to the node-exporter textfile directory on hosts that run one (`pp-router1`, `pp-nas1`).
- Each enabled host publishes `restic_backup_configured`. `ResticBackupStale` fires when a configured host has gone 48 hours without a successful run, or has never had one; `ResticSnapshotsDropped` fires when the snapshot count falls by more than 3 in two days, which daily pruning never does. A failed run also raises `SystemdUnitFailed`.
- Every enabled host also pings Healthchecks.io, which keeps watching when the router (and with it Prometheus and Alertmanager) is down, and is the only monitor on hosts without a node exporter (`pp-wsl1`): set `healthchecksPingUrlSecret`, and each run pings `/start`, then success or `/fail`.

## Google setup (once)

All hosts share one Google Cloud project and Desktop OAuth client (decision 0004), so any host's token can see and delete every host's backups. Each host still has its own refresh token and restic password, so no host can read another's data.

1. In the [Google Cloud console](https://console.cloud.google.com), create the project (ours is `pp-backup-nas1`) and enable the Google Drive API under APIs & Services, Library.
2. Google Auth Platform, Branding: app name `pp-backup`, support email, homepage `https://prestonperanich.com`, privacy policy `https://prestonperanich.com/privacy`, authorized domain `prestonperanich.com`. Upload no logo: a logo triggers a brand review. Brand verification is not needed; ignore its findings about the homepage and privacy page.
3. Data access: add `https://www.googleapis.com/auth/drive.file`. Audience: user type External, then Publish app. Publishing needs the Branding fields; an app left in Testing issues refresh tokens that expire after 7 days, and backups stop a week later.
4. Clients, Create client, type Desktop app. Save the client ID and secret in the password manager; a restore through the same `drive.file` sandbox needs that same client.

## Enable a host

1. On `pp-ml1`, authorize the client for this host. A browser opens; sign in, accept the unverified-app warning (Advanced, Go to pp-backup) and allow access:

   ```bash
   req=$(jq -nc --arg id '<client-id>' --arg secret '<client-secret>' \
     '{client_id: $id, client_secret: $secret, scope: "drive.file"}' | base64 | tr '+/' '-_' | tr -d '=\n')
   nix shell nixpkgs#rclone -c rclone authorize drive "$req"
   ```

   Passing the ID and secret as two plain arguments instead requests full access to the whole Drive; Google then warns about "sensitive info", which `drive.file` never does. It prints a token. Write the rclone config into the host's sops file as `rclone-gdrive-conf` without saving it to disk:

   ```ini
   [gdrive]
   type = drive
   client_id = <client-id>
   client_secret = <client-secret>
   scope = drive.file
   token = <the JSON from rclone authorize, on one line>
   ```

2. Generate the restic password and store it as `restic-gdrive-password` in the same file, and in the password manager and on the paper emergency sheet. Without it the backups cannot be restored:

   ```bash
   openssl rand -base64 32 | tr -d '\n' | jq -Rs . | sops --config sops/.sops.yaml set --value-stdin sops/machines/<hostname>.yaml '["restic-gdrive-password"]'
   ```

3. Create a check named `gdrive-<hostname>` in Healthchecks.io (period 1 day, grace 2 hours) and store its ping URL as `healthchecks-gdrive-ping-url`.
4. Set `enable = true` in the host's `my.backup.googleDrive` block and deploy the host.
5. Create the repository once, by hand. `initialize` is off on purpose: with it on, a run that cannot see the repository would start a new, empty one and keep succeeding.

   ```bash
   ssh -t pperanich@<hostname>.home.arpa 'sudo restic-gdrive init'
   ```

6. Start the first run and follow it (the NAS sends about 80 GB the first time):

   ```bash
   ssh -t pperanich@<hostname>.home.arpa 'sudo systemctl start restic-backups-gdrive; journalctl -fu restic-backups-gdrive'
   ```

7. Do a test restore (next section) before relying on it.

## Restore

The `restic-gdrive` command on each host carries the repository, password and rclone settings:

```bash
sudo restic-gdrive snapshots
sudo restic-gdrive ls latest /tank/appdata/radicale
sudo restic-gdrive restore latest --target /tmp/restore --include /tank/backups/postgres
```

Restore into a scratch directory first, check the files (open a SQLite file with `sqlite3 <file> 'pragma integrity_check'`, look at the dump with `zstdcat /tmp/restore/tank/backups/postgres/all.sql.zstd | head`), then copy into place with the service stopped.

To restore when the host itself is gone, run restic from any machine with the host's `rclone-gdrive-conf` and `restic-gdrive-password` from the password manager:

```bash
RCLONE_CONFIG=./rclone.conf RESTIC_PASSWORD_FILE=./restic-password \
  nix shell nixpkgs#restic nixpkgs#rclone -c restic -r rclone:gdrive:restic-backups/<hostname> snapshots
```

Router state can also come back over the LAN from Borg on the NAS, with no internet: `ssh -t pperanich@pp-router1.home.arpa 'sudo borg-job-remote list'`.

## Offline copy

Drive protects against losing a disk, the NAS or the house. It does not protect against someone with root on a host, who can read that host's token and delete every host's repository. Once a quarter, copy each repository to a USB disk that stays unplugged otherwise:

```bash
sudo RCLONE_CONFIG=/run/secrets/rclone-gdrive-conf nix shell nixpkgs#restic nixpkgs#rclone -c \
  restic -r /mnt/usb/restic/<hostname> --password-file <usb-password-file> \
  copy --from-repo rclone:gdrive:restic-backups/<hostname> --from-password-file /run/secrets/restic-gdrive-password
```

The first time, create the USB repository with the same command but `init --copy-chunker-params` in place of `copy`, so both repositories share chunking and later copies stay incremental.
