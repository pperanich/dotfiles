# Hermes on the NAS

The phone opens `https://hermes.prestonperanich.com` on the LAN or tailnet. Caddy forwards to the Webapp on NAS loopback port 9120. The gateway runs as `hermes`. Its workspace instructions give it the Rex address for `hermes-worker` on `pp-wsl1`. Coding sessions have their own home and provider login on WSL. [Fleet TLS routing](split-horizon-tls.md)

## First sign-in

After the WSL, router and NAS configurations have been activated, retrieve the Webapp password on the admin Mac. From the dotfiles root, this copies only the recovery field to the clipboard. Save it in the password manager and use the login name `operator`.

```sh
sops --config sops/.sops.yaml decrypt --extract '["hermes"]["web-password-recovery"]' \
  sops/machines/pp-nas1.yaml | pbcopy
```

In a private terminal on `pp-nas1`, authorize the coordinator’s ChatGPT subscription. Complete the device prompt in your browser.

```sh
sudo -Hu hermes env HERMES_HOME=/var/lib/hermes/.hermes \
  /etc/profiles/per-user/hermes/bin/hermes auth add openai-codex --type oauth
```

On `pp-wsl1`, authorize the worker’s Codex CLI separately.

```sh
sudo -Hu hermes-worker /etc/profiles/per-user/hermes-worker/bin/codex login --device-auth
sudo -Hu hermes-worker /etc/profiles/per-user/hermes-worker/bin/codex login status
```

The NAS uses the `openai-codex` provider with `gpt-6-sol`. Set `my.hermesCoordinator.model` to another model available to the subscription if needed. From the phone, confirm sign-in is required and send a short chat message before trying a coding task.

## Verify a worker

Run these commands in a NAS terminal. The first asks the remote Rex server for its identity. The second opens a disposable pane that reports the actual Unix user, host and Codex version.

```sh
worker=http://hermes-worker@100.64.0.4:7297
rex_cli=/etc/profiles/per-user/hermes/bin/rex
sudo -Hu hermes "$rex_cli" --autostart=false -S "$worker" whoami --json
sudo -Hu hermes "$rex_cli" --autostart=false -S "$worker" new --json --keep-open \
  hermes-smoke -- /run/current-system/sw/bin/bash -lc 'id -un; hostname; codex --version'
```

Capture the returned session and block with `rex capture -s SESSION -b BLOCK --trim` using the same account and server. Expect `hermes-worker` and `pp-wsl1`. From the NAS, requesting `http://pperanich@100.64.0.4:7297` should be denied. Then give Hermes a small task in a disposable checkout owned by the worker. Restart the gateway mid-task and ask the same chat to return the commit and test result from the original worker pane. [Rex login server](https://www.superlogical.com/rex/docs/linux/login-server)

Headscale permits TCP 7297 from `tag:nas` to the WSL address `100.64.0.4`. Rex verifies `tag:nas` before admitting the caller to the worker account. This permission belongs to the NAS node. To inspect that worker yourself, use the same service-account Rex command from a NAS terminal. Recheck the WSL address and the account mapping after pp-wsl1 is re-enrolled.

The worker has a private Linux home and no additional Unix groups. WSL lets every Linux user run Windows programs as the Windows user through the interop sockets in `/run/WSL`, and the drives under `/mnt` are readable by everyone unless the mount sets a umask. pp-wsl1 therefore denies the worker both directories with ACLs (`systemd.tmpfiles.rules`) and mounts the drives with `umask=077`. WSLg's X server accepts any local client and shares the clipboard with Windows, so the tracked `home/.wslconfig` turns WSLg off. Check from a pperanich shell on pp-wsl1 after each deploy and `wsl --shutdown`. The binary is copied off `/mnt` so the second check tests the socket, not the drive:

```sh
sudo -u hermes-worker ls /mnt/c          # Permission denied
d=$(mktemp -d) && chmod 755 "$d" && cp /mnt/c/Windows/System32/whoami.exe "$d"/ && chmod 755 "$d/whoami.exe"
sudo -u hermes-worker env WSL_INTEROP="$(ls /run/WSL/*_interop | head -1)" "$d/whoami.exe"   # connect failed 13
"$d/whoami.exe"                          # pp-wd1\prest
rm -r "$d"
```

The worker still shares the kernel, the network (mirrored, so Windows `localhost` services are reachable) and the WSL plumbing with Windows. The WSL restic job covers `/home/pperanich` only. Keep accepted commits in the project’s usual durable repository. Recovering NAS chat history does not restore uncommitted worker edits or its Codex login.

## Credentials and recovery

Nix delivers only the scrypt verifier and the signing key to systemd through `/run/secrets/rendered/hermes-web.env`. The recovery password stays in the encrypted NAS SOPS file. To rotate the password, update the recovery value and its matching Hermes-format verifier together. Changing either the verifier or the signing key ends existing browser sessions. The next activation restarts the gateway on a template change. The provider refreshes its own `auth.json` under `/var/lib/hermes/.hermes`. This directory and the workspace are covered by the NAS’s existing ZFS snapshot and restic backup. Reconcile a restored chat’s worker IDs against live Rex panes before resuming dispatch. [Fleet secret handling](operations.md) · [Backups](backups.md)

The coordinator imports the official Hermes v0.23.3 NixOS module with its matching package. They supply the compiled Webapp, gateway service and state initialization. Numtide packages Hermes separately and supplies the Codex CLI used on the worker. The independent nix-hermes-agent project has a separate release and module configuration to maintain. [Official module](https://github.com/NousResearch/hermes-agent/blob/v0.23.3/nix/nixosModules.nix) · [Upstream Nix guide](https://hermes-agent.nousresearch.com/docs/getting-started/nix-setup) · [Numtide packages](https://github.com/numtide/llm-agents.nix) · [Independent module](https://github.com/0xrsydn/nix-hermes-agent)
