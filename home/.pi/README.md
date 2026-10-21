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
  `pi-lens`, `pi-memory`, the rpiv `advisor`, `ask_user_question` and `todo`
  tools, and the Catppuccin theme.

`extensions/debate/` is a local extension: run `npm ci --ignore-scripts` in it
once, since Pi does not install a local extension's dependencies. It is a copy
of the one in the private work profile and is maintained separately.

In Pi, `/feature-loop` expands the starter prompt. You can also ask Pi to plan
and implement a feature with subagents and it can load the skill from the
request.

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
