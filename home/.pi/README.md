# Pi profiles

`agent/` is the normal Pi profile. `settings.json` pins its npm packages, which
Pi installs into the ignored `agent/npm/` directory:

- `pi-subagents` for the `subagent` tool, with the `planner`, `implementer` and
  `reviewer` agents in `agents/`. They replace the package's builtin
  `reviewer`; its other builtins (`scout`, `worker`, `researcher`, `oracle`, ...)
  stay available.
- `pi-extensible-workflows`, `@piewf/cli` and `@piewf/herdr` for scripted
  workflows, with the package's starter extension filtered out.
- `pi-web-access` (web search and fetch, which the builtin `researcher` needs),
  `pi-memory`, the rpiv `advisor`, `ask_user_question` and `todo` tools, and
  the Catppuccin theme.

`/goal` is maintained in `agent/extensions/goal.ts`, which the normal profile
loads directly from the dotfiles checkout. It stores one objective on the current
Pi session branch. Use `/goal pause` and `/goal resume` on that branch. Older
`pi-goal-x` records stay in each project's `.pi/goals/` directory.
[Original extension at `0865c84`](https://github.com/mitsuhiko/agent-stuff/blob/0865c849befd2021490679f96a8dee58c84ac857/extensions/goal.ts)

`~/dotfiles/agent-kit/pi` is agent-kit's pi package, listed in both this profile and the work
profile. Its extension sends each bash, write and edit call through `agent-guard`, the
same check Claude Code and Codex run as a hook. `agent-kit install` adds the entry; see
`agent-kit/README.md`.

`extensions/debate/` is a local extension, disabled in `agent/settings.json`
with `-extensions/debate/index.ts`. Its source is retained; remove that exclusion
and run `/reload` to re-enable it. If its dependencies are missing, run
`npm ci --ignore-scripts` in it first, since Pi does not install a local
extension's dependencies. It is a copy of the one in the private work profile
and is maintained separately.

In Pi, `/feature-loop <request>` passes the request to the feature skill. A
bounded change can run directly with its existing check. Ask for planning only,
an independent review, or a saved ledger when you need one. With no arguments,
the command uses the agreed task from the conversation. Use
`/skill:feature-loop` for examples with literal quotes or significant newlines.
Pi's prompt-template arguments use shell-style quoting.

`firstmate/` is intentionally plain. `pi-firstmate` selects that profile while
still allowing a checked-out FirstMate repository to load its own project-local
`.pi/extensions`. The wrapper shares only Pi authentication with the normal
profile. It does not load the normal profile's packages, agents, extensions,
skill, or prompt template.

`pi-firstmate` also prepends `~/.local/libexec/pi-firstmate` to `PATH`. That
directory holds a `pi` shim. FirstMate resolves `pi` from the primary's `PATH`
and bakes the absolute path into crew launches, which start in fresh tmux
shells without the primary's environment. The shim exports the firstmate
profile when `FM_PI_HARNESS` is set and `PI_CODING_AGENT_DIR` is not, then
execs the real `pi`. Outside `pi-firstmate` the shim is not on `PATH`.

Upstream references:

- <https://github.com/amosblomqvist/pi-config>
- <https://github.com/nicobailon/pi-subagents>
- <https://github.com/vekexasia/pi-extensible-workflows>
- <https://github.com/AI-Builder-Club/skills>
