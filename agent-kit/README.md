# agent-kit

Checks that enforce the user-wide agent rules in `home/.config/agents/AGENTS.md` for Claude Code, Codex and pi, plus project kits for rules that apply to one project. The rules a program can decide become blocks, and each block message tells the agent the fix.

agent-kit is a Python package (`src/agent_kit`, standard library only) with three console scripts: `agent-guard` (the hook), `agent-kit` (install and kit commands) and `agent-kit-run` (runs a project kit inside that kit's environment). The other folders are what each harness or kit needs:

| Path                        | What it is                                                                                                                                       |
| --------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------ |
| `src/agent_kit/`            | The guard, the built-in rules (`rules.py`), the public API for kits (`api.py`, `testing.py`), kit discovery and trust (`kits.py`), the installer |
| `claude/`                   | The Claude Code plugin: a manifest and a `PreToolUse` hook. `.claude-plugin/marketplace.json` at the root serves it                              |
| `pi/`                       | The pi package: `package.json` is pi's manifest, and `agent-kit.ts` forwards each tool call to `agent-guard`                                     |
| `skills/write-agent-check/` | The skill that teaches an agent to turn a correction into a check. `install` links it into `~/.agents/skills`                                    |
| `template/`                 | The Copier template for project kits. `copier.yml` sits at the dotfiles root, because Copier versions a template only from a repository root     |
| `git-hooks/`                | The global hooks path: `_dispatch` and a link per hook name                                                                                      |
| `tests/`                    | pytest suite, with real payloads captured from each harness in `tests/fixtures/`                                                                 |

## Built-in rules

`agent-guard pre-tool` runs before every shell, write and edit call. It exits 2 to block the call:

| Rule                | Blocks                                                                                                                                                                                                                      | Allows                                                                                                                                                |
| ------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------- |
| `gnu-tools`         | `sed -i ''`, `stat -f '%…'`, `date -v` / `date -j`                                                                                                                                                                          | the GNU spellings, and `/usr/bin/sed` called by path                                                                                                  |
| `uv-python`         | `python3 …`, `.venv/bin/python …`, `pip install`                                                                                                                                                                            | `uv run python …`, `python3 --version`                                                                                                                |
| `machine-config`    | writes to `~/.gitconfig`, `~/.config/git`, `~/.ssh`, `~/.aws`, shell rc files, `~/.netrc`, `~/.npmrc`, `~/.pypirc`, agent-kit's `trusted.json`; `git config --global/--system` writes                                       | reads, and edits to the dotfiles sources of those files                                                                                               |
| `forge-attribution` | AI attribution in `git commit`, `gh pr/issue/api/release` text (including `--body-file` and heredocs) and GitHub MCP tools                                                                                                  | human `Co-authored-by` lines, prose about AI features                                                                                                 |
| `sleep-loop`        | `while`/`until` loops that `sleep`                                                                                                                                                                                          | the same poll bounded by `timeout … bash -c '…'`                                                                                                      |
| `source-text-test`  | test files (by name or under `tests/`, `__tests__/`, `spec/`) that gain a line reading code as text: `inspect.getsource`, or a read of a source file by path (`readFileSync(...'app.ts')`, `(ROOT / 'app.py').read_text()`) | the same in production code, comments, reads under `tmp`/`fixtures`/`golden`/`expected`/`snapshot`/`testdata`, and lines a rewritten file already had |

`agent-guard commit-msg` runs from the global `commit-msg` hook. It rejects AI attribution trailers and em dashes, and warns when the subject is not a Conventional Commit.

To let one session through a rule the user approved, launch the agent with `AGENT_KIT_ALLOW=machine-config` (comma-separated rule names, built-in or kit). The hook reads it from the harness's own environment, so an agent's shell command cannot set it.

## Project kits

A project kit holds rules for one project, as Python checks on the same `Kit` API the built-in rules use. After its own rules, the guard runs every kit it finds from the working directory:

- **User-side** (the default): `~/.config/agent-kit/projects/<host>/<owner>/<repo>/`, keyed by the origin remote, so it follows clones and worktrees and never touches the repository. It runs as soon as it exists. Each is its own git repository, so `copier update` can merge template changes.
- **In-repo**: `.agent-kit/` in the repository, committed with it. It runs only after `agent-kit trust` records a hash of its files, and any change needs trust again. Trust needs a terminal, so an agent cannot approve a kit.

```bash
agent-kit new                 # user-side kit for the current repository (agent-kit as an editable dependency)
agent-kit new --repo          # in-repo kit (agent-kit from GitHub; push dotfiles first)
agent-kit kits                # what runs here, trusted or not, and each kit's rules
agent-kit check 'kubectl --context prod get pods'   # the guard's verdict, without running it
agent-kit trust [path]        # approve an in-repo kit
agent-kit update-kits         # copier update every kit; user-side kits are committed, conflicts reported
```

`agent-kit new` runs Copier on the template, then `uv sync` and the new kit's tests, so a kit starts green. Rules go in `src/<package>/checks.py`, whose docstring shows the three shapes: `block_command`, `block_paths`, and `@kit.check` for anything Python can decide. The guard calls the kit's `.venv/bin/agent-kit-run`, so a kit's dependencies stay out of agent-kit's environment. A kit that is missing its `.venv`, untrusted or crashing is skipped, never blocking.

Kits import only from `agent_kit.api`. `API_VERSION` there changes when a kit written against the old API would break.

## The write-agent-check skill

The skill sends a correction where it belongs: the repository's own linter or tests for rules about code, agent-kit's `rules.py` for agent behavior everywhere, or the project's kit for agent behavior in one project. Then it writes the check with blocked and allowed cases and proves it with `agent-kit check`. `install` links it into `~/.agents/skills`, which dotfiles' `home/.agents/skills/README.md` names as the place an owner installs its skills. Claude Code reads that directory through the `~/.claude/skills` link, and pi and Codex read it natively, so one link covers all three.

## Install

```bash
uv run --project ~/dotfiles/agent-kit agent-kit install   # first time on a machine
agent-kit doctor                                          # afterwards, from PATH
agent-kit uninstall
```

`--only tool,skill,claude,codex,pi,git`, `--claude-dir` and `--pi-dir` narrow it; `--dry-run` prints what it would do.

| Step        | Mechanism                                                                                                                     | Notes                                                                                                                                                                                                      |
| ----------- | ----------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| tool        | `uv tool install --editable` of this directory                                                                                | Puts the three scripts in `uv tool dir --bin` (`~/.local/bin`). Editable, so edits here take effect at the next call. Every adapter calls `$HOME/.local/bin/agent-guard`; `AGENT_GUARD` overrides the path |
| skill       | a link from `~/.agents/skills/write-agent-check` to `skills/write-agent-check`                                                | Refuses when `~/.agents/skills` is itself a link, since a folded stow directory would put the link inside the checkout                                                                                     |
| Claude Code | plugin `agent-kit@agent-kit` from `claude/`                                                                                   | Claude caches the plugin's two manifests; rerun `install` after editing them. Profiles that share a plugins directory install once                                                                         |
| Codex       | a `PreToolUse` entry merged into `$CODEX_HOME/hooks.json` (backup beside it)                                                  | Codex runs a new or changed hook only after you approve it in `/hooks`                                                                                                                                     |
| pi          | `pi install` of `pi/` into each profile (`~/.pi/agent`, `$PI_CODING_AGENT_DIR`), entry rewritten as `~/dotfiles/agent-kit/pi` | Loaded in place                                                                                                                                                                                            |
| git         | `core.hooksPath` in the global config file, written to the file the symlink points at                                         | `_dispatch` runs agent-kit's check and the project kits' commit checks, then the repo's own `.git/hooks/<name>`. A repo that sets its own `core.hooksPath` skips these hooks                               |

If `agent-guard` is missing or crashes, every adapter lets the call through, so a broken guard never stops work; `doctor` is how you find out.

## Fixtures and tests

Set `AGENT_KIT_LOG_DIR` when launching an agent and the guard appends each payload to `<dir>/<harness>.jsonl`. `agent-kit fixtures <log>` turns a log into redacted fixtures for the built-in rules; inside a kit, `uv run agent-kit-run fixtures <log> --out tests/fixtures` does the same for that kit's rules. Each fixture records the current verdict, so a harness upgrade that changes its payload shape fails a test.

```bash
cd ~/dotfiles/agent-kit && uv run pytest && uv run ruff check .
```

`tests/test_template.py` runs Copier and uv for real: it creates a kit, adds a rule, and checks that the guard enforces it.
