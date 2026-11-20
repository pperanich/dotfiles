---
name: write-agent-check
description: Use when the user corrects an agent's behavior, or asks for a rule to be enforced, and the fix should become a deterministic check instead of a prose rule. Routes the correction to the repository's own linter or tests, to agent-kit's user-wide rules, or to a project kit, then writes the check, its tests, and proof that it blocks.
---

# Write an agent check

A correction that only lives in prose depends on the next agent reading and obeying it. A check runs every time. Write a prose rule only when the rule needs judgment no code can make, and say in one line why no check fits.

## 1. Decide where the check belongs

First ask what is wrong: the code, or the agent's action.

| The correction is about          | It goes in                                      | Example                                                                       |
| -------------------------------- | ----------------------------------------------- | ----------------------------------------------------------------------------- |
| Code in this repository          | The repository's own linter, types, tests or CI | "No `useEffect` in product code", "no imports from main into the renderer"    |
| An agent action in every project | agent-kit's built-in kit                        | "Never run a bare `python3`", "no AI attribution in commits"                  |
| An agent action in one project   | That project's kit                              | "Never `kubectl` against the prod context here", "never hand-edit `src/gen/`" |

Code rules belong to the repository because its tooling catches people and CI too. agent-kit sees only what an agent does: shell commands, file writes and edits, GitHub tool text, and commit messages. For a code rule, use the repository's tooling and stop here; changing its lint or CI config is a change to that repository, so propose it and wait for the user's answer.

## 2a. A user-wide rule: agent-kit's built-in kit

agent-kit lives at `~/dotfiles/agent-kit` (github.com/pperanich/dotfiles). Read its `README.md` first.

1. Add a function to `src/agent_kit/rules.py` registered with `@kit.check("<rule-name>")`. It takes an `Event` and returns the block message or `None`. Use `event.commands` (parsed shell commands with `argv` and `redirects`) and the helpers in `agent_kit.kit`: `resolve_path`, `write_targets`, `written_paths`, `repo_root`.
2. Write the message as the instruction the agent will read: what is wrong and the exact fix. It is the only guidance the blocked agent gets.
3. Add cases to `tests/test_rules.py`: every form you block in `BLOCKED`, and the near misses that must stay allowed in `ALLOWED`: the pattern inside a quoted string or heredoc, an explicit path, the read-only form.
4. Run `uv run pytest && uv run ruff check .` in `~/dotfiles/agent-kit`.
5. The guard is an editable install, so the rule applies at the next tool call. A change under `claude/` also needs `agent-kit install --only claude`.
6. Add the rule to the table in `README.md`.

## 2b. A project rule: the project's kit

1. Run `agent-kit kits` in the project to see what exists.
2. With no kit, create one:
   - `agent-kit new` makes a user-side kit at `~/.config/agent-kit/projects/<host>/<owner>/<repo>/`. This is the default, and the right choice for a repository the user does not own or has not asked you to change.
   - `agent-kit new --repo` makes `.agent-kit/` inside the repository. Use it only when the user asks for a kit committed with the code.
3. Write the rule in `src/<package>/checks.py`. Its docstring shows the three shapes: `block_command` for a command and its arguments, `block_paths` for files that must not be written, and `@kit.check` for anything Python can decide, such as reading a config file. Commit-message rules use `@kit.commit_check`. Import only from `agent_kit.api`.
4. Add `BLOCKED` and `ALLOWED` cases to `tests/test_checks.py`, then run `uv run pytest` in the kit. Run `uv sync` after changing dependencies; the guard calls the kit's `.venv/bin/agent-kit-run`.
5. A user-side kit runs at once and is its own git repository: commit the change there with a Conventional Commit message. An in-repo kit runs only after the user runs `agent-kit trust` in a terminal. You cannot approve it, so tell the user it is waiting for them.

## 3. Prove it blocks

Show evidence, not a claim: the test output, and one call through the same path the hooks use.

```bash
agent-kit check 'kubectl --context prod get pods'   # from inside the project
```

It prints each rule that blocks the command with its message, or `allowed`, and exits 2 or 0. Run one blocked and one allowed command.

## Never

- Weaken or remove a user-wide rule to get past a block. A block in your way is the check working; tell the user.
- Set `AGENT_KIT_ALLOW` yourself. It is for the user to set when launching an agent.
- Write `~/.config/agent-kit/trusted.json` or run `agent-kit trust` on the user's behalf.
- Add a prose rule to an instruction file when a check fits.
