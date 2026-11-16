# Operating the Fleet

How day-to-day changes are made from `pp-ml1`, and the traps that have cost time before. Deploy commands are in [the index](index.md#deploy-to-a-machine); secrets layout is in [Secrets and Key Management](secrets-and-key-management.md).

## Working methods

- **Sudo runs in a terminal pane the owner can see.** Open a split running `ssh -t pperanich@<host>.pp-ts`, or `nix develop --command deploy ...`, and let the owner type the password. Copy a script to the host first and run `sudo bash /tmp/<script>.sh 2>&1 | tee /tmp/<script>.log`, so the result can be read back even if the pane closes. Never `set -e` in the interactive shell itself.
- **Secrets never pass through a chat or a log.** The owner copies a new token to the clipboard; the command that stores it reads `pbpaste` (for example `sops set --value-stdin`). Generated values go straight from the host into sops or Bitwarden without being printed.
- **Bitwarden through `bw serve`.** The owner runs `export BW_SESSION="$(bw unlock --raw)"; bw serve --hostname 127.0.0.1 --port 8087` in their own terminal. Use its REST API with `curl` and print only names and IDs. Homelab entries match on host, token entries never match.
- **Snapshot before a database-migrating upgrade.** On the NAS: `sudo systemctl start postgresqlBackup.service`, then `sudo zfs snapshot -r rpool/var@<name> rpool/tank@<name>`. On the router, copy the Gitea and Grafana SQLite files with both services stopped. A generation rollback restores programs, not migrated data.
- **Test a restore, not just a backup.** Restore files that never change (Immich originals) and compare them with `cmp` against the live copies; check the Postgres dump with `zstd -t`. `restic ls` needs `--recursive` below the top directory.

## Traps

| Symptom                                                                            | Cause and fix                                                                                                                                                                                                           |
| :--------------------------------------------------------------------------------- | :---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Could not resolve hostname <host>.home.arpa` from `deploy` or `--store ssh-ng://` | ssh launched by Nix on the Mac cannot resolve `home.arpa`, while the same ssh from a shell can. Use `<host>.pp-ts`.                                                                                                     |
| sops finds no creation rule, or cannot encrypt to the YubiKey                      | Pass `--config sops/.sops.yaml` outside the dev shell, and have `age-plugin-yubikey` on `PATH`. The shell exports `SOPS_CONFIG` for this repo, so sops in another repo needs that repo's `--config`.                    |
| `no matches found` for `.#host`                                                    | zsh `extendedglob` reads `#` as a glob. Quote the flake reference.                                                                                                                                                      |
| `nix fmt` changes nothing but the treefmt check fails                              | treefmt's cache ignores formatter upgrades: `nix fmt -- --no-cache`.                                                                                                                                                    |
| A bare `nix flake update` rebuilds fonts or MongoDB                                | It also bumps pinned inputs. Use `bin/update-inputs.sh`, and `bin/build-report.sh` before deploying.                                                                                                                    |
| `mismatch in field 'narHash'` for a tarball input                                  | The URL changed contents after locking. Drop the input's lock entry and `nix flake lock`; if the tarball cache still serves the old copy, set `narHash` to the hash the error reports.                                  |
| A new substituter is ignored                                                       | It applies only after the switch that adds it. For that switch: `nh darwin switch . -H pp-ml1 -- --option extra-substituters <url>`.                                                                                    |
| deploy-rs rolls back over one failed unit, or leaves the system half switched      | Any unit failing at activation fails the deploy. Afterwards compare `readlink /run/current-system` with `/nix/var/nix/profiles/system`; if they differ, fix the unit and redeploy so both point at the same generation. |
| A failed Caddy start makes the rollback fail too                                   | systemd's start limit: `systemctl reset-failed`, then run the old generation's `switch-to-configuration switch`.                                                                                                        |
| A rotated secret has no effect after deploy                                        | The service reads it only at start. Give the secret `restartUnits`.                                                                                                                                                     |
| A changed admin password is ignored                                                | Grafana, Nextcloud and Paperless read it only at first setup. Reset in place (see below).                                                                                                                               |
| `vaultwarden-admin-hash.service` fails                                             | `vaultwarden-admin-token` holds the raw token; the unit hashes it at start and rejects a PHC string.                                                                                                                    |
| `gitea` or `grafana` is not found on the router                                    | Neither CLI is on `PATH`. Use the binary from `systemctl show <unit> -p ExecStart` (Grafana's is inside the `unit-script` file).                                                                                        |
| Sites behind the Cloudflare tunnel return 530 after a tunnel replacement           | The CNAMEs still name the old tunnel: `sudo systemctl start cf-tunnel-dns-sync` on the router.                                                                                                                          |
| Postgres logs `database "<db>" has a collation version mismatch`                   | glibc changed with a nixpkgs update. Stop the apps, then per database: `REINDEX DATABASE <db>` and `ALTER DATABASE <db> REFRESH COLLATION VERSION` (`template0` has no version and refuses; leave it).                  |
| A NAS deploy in the middle of a backup restarts it                                 | The restic unit keeps running, but its ZFS snapshot unit restarts if its definition changed. Deploy outside the 04:30 window when that unit changes.                                                                    |
| `determinate-nixd status` says `invalid-token`                                     | The FlakeHub token was revoked. Public flakes still fetch; `determinate-nixd login` restores the FlakeHub cache.                                                                                                        |
| `ping` to the router over the tailnet fails                                        | Use `tailscale ping`. Headscale pre-auth keys take the numeric user ID (`--user 1`).                                                                                                                                    |
| home-manager links the wrong version of a dotfile                                  | Links point into `~/dotfiles`, not the checkout you built from. Keep `~/dotfiles` on `main`.                                                                                                                            |

## Resetting an admin password in place

```bash
# Grafana (router): the binary and config.ini come from the unit's ExecStart
sudo <grafana> cli --homepath /var/lib/grafana --config <config.ini> admin reset-admin-password --password-from-stdin

# Nextcloud (NAS)
sudo OC_PASS='<new>' nextcloud-occ user:resetpassword --password-from-env admin

# Paperless (NAS): call set_password on the user
sudo paperless-manage shell
```
