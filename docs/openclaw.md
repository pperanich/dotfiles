# OpenClaw on the NAS

OpenClaw runs next to [Hermes](hermes.md) so the two can be compared. The phone or a browser opens `https://openclaw.prestonperanich.com` on the LAN or tailnet. Caddy forwards to the gateway on NAS loopback port 18789. The gateway runs as `openclaw` from the official `nix-openclaw` flake, with the sandboxing in `modules/services/openclaw.nix` added on top. Coding tasks go over Rex to its own account, `openclaw-worker`, on `pp-wsl1`, isolated the same way as `hermes-worker`.

## First sign-in

The Control UI authenticates with the gateway token. On the admin Mac, from the dotfiles root, copy it to the clipboard and paste it into the Control UI's connection settings:

```sh
sops --config sops/.sops.yaml decrypt --extract '["openclaw-gateway-token"]' \
  sops/machines/pp-nas1.yaml | pbcopy
```

Caddy adds `X-Forwarded-For`, so OpenClaw never treats a browser as a same-host client and every new browser must be approved once. In a terminal on `pp-nas1`:

```sh
sudo openclaw-ctl devices list
sudo openclaw-ctl devices approve <deviceRequestId>
```

`openclaw-ctl` runs the OpenClaw CLI as `openclaw` with the gateway's config, state and token. Sign the gateway in to the ChatGPT subscription with a device code:

```sh
sudo openclaw-ctl models auth login --provider openai --device-code
sudo openclaw-ctl models status
```

The model is `my.openclaw.model` in `machines/pp-nas1/configuration.nix`, because `/etc/openclaw/openclaw.json` is read-only and `openclaw config set` cannot change it. OpenClaw's docs warn that some providers revoke the previous refresh token at each login. Hermes, `hermes-worker`, `openclaw-worker` and this gateway share one ChatGPT account, so if one of them is logged out after another signs in, switch OpenClaw to an API key.

On `pp-wsl1`, authorize the worker's Codex CLI:

```sh
sudo -Hu openclaw-worker /etc/profiles/per-user/openclaw-worker/bin/codex login --device-auth
```

## Verify the worker

From a NAS terminal, ask the worker's Rex server who it is; expect `openclaw-worker` on `pp-wsl1`:

```sh
sudo -Hu openclaw /etc/profiles/per-user/openclaw/bin/rex --autostart=false \
  -S http://openclaw-worker@100.64.0.4:7297 whoami --json
```

`tools.exec.mode` is `ask`, so any command the agent wants to run on the NAS waits for approval in the Control UI. Approve the first `rex` dispatch with "allow always"; the allowlist lives in OpenClaw's state database, not in Nix. The unit also hides `/tank`, `/home` and every other service's `/var/lib` directory from the gateway and its commands.

Workers have no push credentials. They clone over HTTPS into `~/src` and report diffs instead of pushing.

Rex admits any `tag:nas` caller to both worker accounts, so the separation between Hermes's and OpenClaw's workers is by convention: each gateway's workspace `AGENTS.md` names only its own account. The worker isolation on `pp-wsl1` (no `/run/WSL`, no `/mnt`) applies to every account in `lib.my.homelab.rexWorker.users`; [check it](hermes.md#verify-a-worker) with `openclaw-worker` in place of `hermes-worker`.

## State and recovery

State, auth profiles and the workspace live in `/var/lib/openclaw`, covered by the NAS's ZFS snapshots and restic backup. `AGENTS.md` in the workspace is a link into the Nix store, replaced at every gateway start, so change it in `modules/services/openclaw.nix`. The other workspace files (`SOUL.md`, `IDENTITY.md`, `USER.md`) belong to the agent. Logs are in `/var/lib/openclaw/logs/gateway.log`.
