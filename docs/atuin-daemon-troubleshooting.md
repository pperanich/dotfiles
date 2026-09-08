# Atuin Daemon Not Logging Commands

Darwin only. The daemon is a home-manager launchd job (`org.nix-community.home.atuin-daemon`),
enabled via `programs.atuin.daemon.enable` in `modules/system/base.nix`.

## Symptoms

- New commands do not appear in `atuin history list` or search.
- `launchctl list | grep atuin` shows no PID and last exit status `1`.
- `~/.local/share/atuin/atuin-daemon.pid` has a fresh mtime but the PID is dead.

## Root Cause

The daemon crashed and left `~/.local/share/atuin/daemon.sock` behind. Atuin will not bind over an
existing socket, so every launchd restart dies immediately:

```
Error: Address already in use (os error 48)
    crates/atuin-daemon/src/server.rs:69:10
```

The plist has no `StandardErrorPath`, so this fails silently. Confirm with:

```bash
/nix/store/*-atuin-*/bin/atuin daemon start   # prints the error above
lsof ~/.local/share/atuin/daemon.sock         # should return nothing
```

## Fix

```bash
rm -f ~/.local/share/atuin/daemon.sock ~/.local/share/atuin/atuin-daemon.pid
launchctl kickstart -k "gui/$(id -u)/org.nix-community.home.atuin-daemon"
pgrep -fl "atuin daemon"                      # should show a PID
```

Verify a write goes through:

```bash
id=$(atuin history start -- "echo test") && atuin history end --exit 0 "$id"
atuin history list --reverse --cmd-only | tail -1
```

Commands run while the daemon was down are lost.

## Possible Hardening

- Add a log path to the launchd job so crashes are visible.
- Clear the stale socket in a pre-start step.
