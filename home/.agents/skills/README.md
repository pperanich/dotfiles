# Skills tracked here

The development skills live here. Use `dev-design` to resolve a decision,
`dev-plan` to specify an outcome and its checks, `dev-execute` to work from an
approved plan, `dev-wrap` to verify or hand off a change, and `dev-queue` to
handle GitHub issues. You can use any phase on its own.

For example, invoke `$dev-plan` in Codex, `/skill:dev-plan` in Pi, or
`/dev:plan` in Claude Code. The five Claude commands link to these same files.
Stow links individual files. The `~/.codex/skills/dotfiles` directory link lets
Codex discover the original skill folders. Pi reads `~/.agents/skills` natively.
Claude Code and Antigravity do not read it. Link each new skill from
`home/.gemini/config/skills/` and each new non-`dev-*` skill from
`home/.claude/skills/` (a flake check fails until you do). Installed skills
need a link in `~/.claude/skills` and `~/.gemini/config/skills` by hand or from
their installer. Antigravity's `skills.json` cannot point at the hub, because
agy 1.5.13 rejects `~/` paths, and a directory link would put skills written
for Antigravity into the hub.
New personal handoffs use `~/.agents/plans/`. Existing handoffs in
`~/.claude/plans/` can be resumed in place.

`ai-tells` is the catalog of generic AI prose and code patterns that the global
`AGENTS.md` points to for a last pass over a document or diff.

The [planning examples](dev-plan/evals/evals.json) and [review examples](dev-wrap/evals/evals.json)
are replayable. Give a fresh agent the `prompt` and compare its answer with
`expected_output` afterward.

Only skills that exist nowhere else belong in this directory. Everything else
is installed per user into `~/.agents/skills/` on the machines that need it,
from whatever owns it:

| Skill               | Install                                               |
| ------------------- | ----------------------------------------------------- |
| `docshare`          | copy `skills/docshare` from the internal skills repo  |
| `rex`               | `rex skill setup`                                     |
| `write-agent-check` | `agent-kit install` links it from `agent-kit/skills/` |

Tracking a copy of any of those here creates a second source of truth that
drifts silently. If a skill gains an upstream, remove it from this directory
and install it instead.
