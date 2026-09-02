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

Upstream references:

- <https://github.com/amosblomqvist/pi-config>
- <https://github.com/amosblomqvist/pi-interactive-subagents>
- <https://github.com/AI-Builder-Club/skills>
