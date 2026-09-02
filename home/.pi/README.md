# Pi profiles

`agent/` is the normal Pi profile. It includes the feature implementation loop
and Amos Blomqvist's interactive subagents package, pinned in `settings.json`.
Pi installs the pinned package into the ignored `agent/git/` directory.

The subagent extension requires Pi to run inside tmux; outside tmux the
`subagent` tool returns an error explaining that. In Pi, `/feature-loop`
expands the starter prompt. You can also ask Pi to plan and implement a feature
with subagents and it can load the skill from the request.

`firstmate/` is intentionally plain. `pi-firstmate` selects that profile while
still allowing a checked-out FirstMate repository to load its own project-local
`.pi/extensions`. The wrapper shares only Pi authentication with the normal
profile. It does not load the normal profile's subagent package, agents, skill,
or prompt template.

`pi-firstmate` also prepends `~/.local/libexec/pi-firstmate` to `PATH`. That
directory holds a `pi` shim. FirstMate resolves `pi` from the primary's `PATH`
and bakes the absolute path into crew launches, which start in fresh tmux
shells without the primary's environment. The shim exports the firstmate
profile when `FM_PI_HARNESS` is set and `PI_CODING_AGENT_DIR` is not, then
execs the real `pi`. Outside `pi-firstmate` the shim is not on `PATH`.

Upstream references:

- <https://github.com/amosblomqvist/pi-config>
- <https://github.com/amosblomqvist/pi-interactive-subagents>
- <https://github.com/AI-Builder-Club/skills>
