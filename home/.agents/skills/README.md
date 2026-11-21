# Skills tracked here

The development skills live here. Use `dev-design` to resolve a decision,
`dev-plan` to specify an outcome and its checks, `dev-execute` to work from an
approved plan, `dev-wrap` to verify or hand off a change, and `dev-queue` to
handle GitHub issues. You can use any phase on its own.

For example, invoke `$dev-plan` in Codex, `/skill:dev-plan` in Pi, or
`/dev:plan` in Claude Code. The five Claude commands link to these same files.
Stow links individual files. The `~/.codex/skills/dotfiles` directory link lets
Codex discover the original skill folders. Pi reads `~/.agents/skills` natively.
Antigravity reads it through `~/.gemini/config/skills.json`. Claude Code does
not read it: link each new non-`dev-*` skill from `home/.claude/skills/`.
New personal handoffs use `~/.agents/plans/`. Existing handoffs in
`~/.claude/plans/` can be resumed in place.

The [planning examples](dev-plan/evals/evals.json) and [review examples](dev-wrap/evals/evals.json)
are replayable. Give a fresh agent the `prompt` and compare its answer with
`expected_output` afterward.

Only skills that exist nowhere else belong in this directory. Everything else
is installed per user into `~/.agents/skills/` on the machines that need it,
from whatever owns it:

| Skill                   | Install                                                                             |
| ----------------------- | ----------------------------------------------------------------------------------- |
| `docshare`              | copy `skills/docshare` from the internal skills repo                                |
| `no-mistakes`           | `make skill` in kunchenguid/no-mistakes, then copy `skills/no-mistakes`             |
| `rex`                   | `rex skill setup`                                                                   |
| `write-agent-check`     | `agent-kit install` links it from `agent-kit/skills/`                               |
| `web-artifacts-builder` | `npx skills add https://github.com/anthropics/skills --skill web-artifacts-builder` |
| `synced/*`              | claude.ai organisation sync, not installed by hand                                  |

Tracking a copy of any of those here creates a second source of truth that
drifts silently. If a skill gains an upstream, remove it from this directory
and install it instead.
