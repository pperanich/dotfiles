# agent-kit

Checks that enforce the user-wide agent rules in `home/.config/agents/AGENTS.md` for Claude Code, Codex and pi. The rules a regex can decide become blocks, and each block message tells the agent the fix.

agent-kit is a Python package (`src/agent_kit`, standard library only) with two console scripts, `agent-guard` and `agent-kit`. The other folders are the thin adapters each harness needs to call `agent-guard`:

| Path             | What it is                                                                                                          |
| ---------------- | ------------------------------------------------------------------------------------------------------------------- |
| `src/agent_kit/` | The guard, the commit-message check, the installer                                                                  |
| `claude/`        | The Claude Code plugin: a manifest and a `PreToolUse` hook. `.claude-plugin/marketplace.json` at the root serves it |
| `pi/`            | The pi package: `package.json` is pi's manifest, and `agent-kit.ts` forwards each tool call to `agent-guard`        |
| `git-hooks/`     | The global hooks path: `_dispatch` and a link per hook name                                                         |
| `tests/`         | pytest suite, with real payloads captured from each harness in `tests/fixtures/`                                    |

## What it checks

`agent-guard pre-tool` runs before every shell, write and edit call. It exits 2 to block the call:

| Rule                | Blocks                                                                                                                                                    | Allows                                                  |
| ------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------- |
| `gnu-tools`         | `sed -i ''`, `stat -f '%…'`, `date -v` / `date -j`                                                                                                        | the GNU spellings, and `/usr/bin/sed` called by path    |
| `uv-python`         | `python3 …`, `.venv/bin/python …`, `pip install`                                                                                                          | `uv run python …`, `python3 --version`                  |
| `machine-config`    | writes to `~/.gitconfig`, `~/.config/git`, `~/.ssh`, `~/.aws`, shell rc files, `~/.netrc`, `~/.npmrc`, `~/.pypirc`; `git config --global/--system` writes | reads, and edits to the dotfiles sources of those files |
| `forge-attribution` | AI attribution in `git commit`, `gh pr/issue/api/release` text (including `--body-file` and heredocs) and GitHub MCP tools                                | human `Co-authored-by` lines, prose about AI features   |
| `sleep-loop`        | `while`/`until` loops that `sleep`                                                                                                                        | the same poll bounded by `timeout … bash -c '…'`        |

`agent-guard commit-msg` runs from the global `commit-msg` hook. It rejects AI attribution trailers and em dashes, and warns when the subject is not a Conventional Commit.

To let one session through a rule the user approved, launch the agent with `AGENT_KIT_ALLOW=machine-config` (comma-separated rule names). The hook reads it from the harness's own environment, so an agent's shell command cannot set it.

## Install

```bash
uv run --project ~/dotfiles/agent-kit agent-kit install   # first time on a machine
agent-kit doctor                                          # afterwards, from PATH
agent-kit uninstall
```

`--only tool,claude,codex,pi,git`, `--claude-dir` and `--pi-dir` narrow it; `--dry-run` prints what it would do.

| Step        | Mechanism                                                                             | Notes                                                                                                                                                                                                                                    |
| ----------- | ------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| tool        | `uv tool install --editable` of this directory                                        | Puts `agent-guard` and `agent-kit` in `uv tool dir --bin` (`~/.local/bin`). Editable, so edits here take effect at the next call with no reinstall. Every adapter calls `$HOME/.local/bin/agent-guard`; `AGENT_GUARD` overrides the path |
| Claude Code | plugin `agent-kit@agent-kit` from `claude/`                                           | Claude caches the plugin, which is only the two manifests; rerun `install` after editing them. Profiles that share a plugins directory install once                                                                                      |
| Codex       | a `PreToolUse` entry merged into `$CODEX_HOME/hooks.json` (backup beside it)          | Codex runs a new or changed hook only after you approve it in `/hooks`                                                                                                                                                                   |
| pi          | `pi install` of `pi/` into each profile (`~/.pi/agent`, `$PI_CODING_AGENT_DIR`)       | Loaded in place                                                                                                                                                                                                                          |
| git         | `core.hooksPath` in the global config file, written to the file the symlink points at | `_dispatch` runs the repo's own `.git/hooks/<name>` after agent-kit's check. A repo that sets its own `core.hooksPath` skips these hooks                                                                                                 |

If `agent-guard` is missing or crashes, every adapter lets the call through, so a broken guard never stops work; `doctor` is how you find out.

## Fixtures and tests

Set `AGENT_KIT_LOG_DIR` when launching an agent and the guard appends each payload to `<dir>/<harness>.jsonl`. `agent-kit fixtures <dir>/*.jsonl` turns a log into redacted fixtures under `tests/fixtures/`, each with the guard's current verdict, so a harness upgrade that changes its payload shape fails a test.

```bash
cd ~/dotfiles/agent-kit && uv run pytest && uv run ruff check .
```
