# Pi agent orchestration research and implementation handoff

Date: 2026-09-01

Status: implemented locally, pending independent review and an end-to-end paid
model run

## Purpose

This document records the research and implementation used to add a
conversation-driven feature loop to the Pi coding agent. It is written for a
reviewer deciding whether the current small Pi configuration is the right path,
or whether Oh My Pi, FirstMate, or another approach should replace it.

The requested experience is:

1. Talk to one top-level agent about a feature.
2. Turn the conversation into concrete acceptance criteria and a task plan.
3. Have implementation subagents perform bounded tasks.
4. Have a separate reviewer inspect each result.
5. Repeat implementation and review until the work passes or a real user
   decision is needed.
6. Keep FirstMate available for a later trial without allowing the two systems
   to load each other's global orchestration behavior.

## Local context found

- Pi `0.84.4` is already installed by `agents.pi` from the
  `llm-agents.nix` flake input in `modules/shell/ai-tools.nix`.
- The active Pi profile was `~/.pi/agent` with OpenCode's `kimi-k2.6` as the
  default model and medium thinking.
- Pi authentication, model cache, and sessions already existed under that
  profile. They were kept out of Git.
- `~/.pi/agent/extensions/tma.js` already existed. It is a tmux lifecycle and
  context-telemetry bridge. It registers no agent tool, so it does not overlap
  with the new `subagent` tool.
- This dotfiles repository deploys all paths below `home/` to `~/` with GNU
  Stow during Home Manager activation. The Pi source of truth therefore belongs
  under `home/.pi/`.
- tmux `3.6a` is installed. This satisfies the selected subagent extension's
  runtime requirement.

## Sources evaluated

### O1: Pi itself

[Pi](https://github.com/earendil-works/pi) is the small extensible base already
installed here. Its user configuration supports packages, TypeScript
extensions, skills, prompt templates, themes, project-local resources, and an
alternate config root through `PI_CODING_AGENT_DIR`.

The [Pi package documentation](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/packages.md)
confirms that a Git package can be pinned to a tag or commit in
`settings.json`, is cloned below the active profile's `git/` directory, and can
declare extensions in its `package.json`. Project-local packages take
precedence only when Pi identifies them as the same package. That does not
prevent two unrelated extensions from registering overlapping behavior.

The [extension documentation](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/extensions.md)
describes the extension API and project/global discovery. The
[skill documentation](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/skills.md)
describes `SKILL.md` discovery and on-demand loading.

Security boundary: Pi's own README says it has no built-in filesystem, process,
network, or credential permission system. Extension and shell access therefore
run with the launching user's permissions. Tool allowlists reduce what a child
model sees, but they are not an operating-system sandbox.

### O2: Amos Blomqvist's pi-config

[pi-config](https://github.com/amosblomqvist/pi-config) is a personal collection
of Pi extensions and skills, not a package intended to be installed wholesale.
Its README explicitly recommends copying only the desired pieces.

Current pieces examined:

- `ask-user-question.ts` for an interactive question popup.
- `bash-guard/` for blocking dangerous shell commands.
- `browser/` and `web-debug/` for Playwright-based browser work.
- `prompt-snippets/`, including an orchestrator-mode snippet.
- `web-fetch/` and `web-search/`.
- `analyze-sessions/`, `pdf-reader/`, and `youtube-transcript/` skills.
- A deprecated orchestrator skill that routes discovery, research, and
  implementation to subagents.

The useful design idea is selective composition. The deprecated orchestrator
prompt was not copied because it contains overly absolute rules, assumes its
own tool names and agent lineup, and does not define the independent review
loop requested here. Browser, web, PDF, memory, and voice pieces were also left
out because they do not serve the first feature-loop test.

### O3: Amos Blomqvist's interactive subagents

[pi-interactive-subagents](https://github.com/amosblomqvist/pi-interactive-subagents)
is the selected runtime extension. It provides asynchronous subagents in tmux
panes and registers `subagent`, `subagent_message`, `subagents_list`, and a
child-only `ask_question` tool.

Reasons it fits the requested loop:

- The top-level conversation remains responsive while children run.
- Child results are steered back into the parent session.
- Agent definitions can live in project `.pi/agents/` or global
  `~/.pi/agent/agents/`; project definitions override global or packaged ones.
- Each definition has a strict tool allowlist, model, reasoning level, session
  mode, spawn allowlist, and autonomous exit setting.
- A child's resolved loadout is snapshotted for a restricted resume.
- The user can watch or steer the actual tmux panes.

The repository's commit
`c3e8b53c0754ae5ccc19fdab5a7481ec039bc2f7` was inspected and pinned. Pinning
makes deployments repeatable, but it also means updates and security fixes must
be reviewed and advanced manually.

We also looked at Amos's newer minimal
[pi-subagents](https://github.com/amosblomqvist/pi-subagents) implementation. It
runs isolated Pi processes and returns text results, but the interactive package
better matches the desired visible, steerable execution loop and supports local
agent definitions without modifying the extension.

### O4: Oh My Pi

[Oh My Pi](https://github.com/can1357/oh-my-pi) is a fork of Pi, not a Pi config
layer. It has a separate `omp` executable, packages, release path, and
`~/.omp/agent` configuration.

It already has much of the requested behavior:

- First-class subagents with isolated worktrees and schema-validated results.
- Agent Hub for live transcripts, steering, revival, and cancellation.
- An `advisor` model that reviews turns independently.
- `/review`, which launches reviewer subagents and returns prioritized findings
  and a verdict.
- The `orchestrate` and `workflowz` keywords for parallel, verified work.
- Dedicated model roles such as `plan`, `task`, `advisor`, and `smol`.

Oh My Pi is the strongest batteries-included alternative. It was not installed
because adopting it means choosing and maintaining the fork as the primary
runtime rather than owning a thin layer on stock Pi. Its broader surface also
adds far more behavior than the requested first experiment. A reviewer should
reconsider it if worktree isolation, typed child results, built-in review, and
Agent Hub matter more than keeping the local implementation small.

### O5: FirstMate

[FirstMate](https://github.com/kunchenguid/firstmate) is not based on Pi. Its
README describes it as an agent distro: a repository of `AGENTS.md`, skills,
scripts, policies, and durable state that can run on Pi, Claude Code, Codex,
Grok, OpenCode, or other supported agent CLIs.

It provides a larger operating model than the local feature loop:

- One conversational first mate that dispatches a crew.
- A tmux-oriented backend with other backend options.
- One clean worktree per crew task.
- Durable fleet supervision and restart recovery.
- Project intake, PR or local-only delivery modes, merge authority, and optional
  persistent second mates.
- Project-local Pi watcher and turn-end extensions under FirstMate's `.pi/`.

FirstMate is a good trial when the goal is a durable multi-project crew that
ships PRs. It is heavier than a same-repository plan, implement, review loop.
The current setup keeps it isolated so the two approaches can be compared
without uninstalling either.

### O6: AI Builder Club skills

[AI Builder Club's skills repository](https://github.com/AI-Builder-Club/skills)
is a Claude Code plugin focused on codebase setup and recurring agent loops.
Specific material examined:

- [`new-loop`](https://github.com/AI-Builder-Club/skills/blob/main/skills/new-loop/SKILL.md)
  uses a file-backed knowledge base, a live domain README, and an append-only
  log so recurring work survives context loss.
- [`setup-codebase-harness`](https://github.com/AI-Builder-Club/skills/blob/main/skills/setup-codebase-harness/SKILL.md)
  routes repository setup through local development, end-to-end testing, cloud
  isolation, and verification skills.
- [`verifier-setup`](https://github.com/AI-Builder-Club/skills/blob/main/skills/verifier-setup/SKILL.md)
  builds a separate verification pass with concrete evidence.
- [`open-agent-teams`](https://github.com/AI-Builder-Club/skills/blob/main/skills/open-agent-teams/SKILL.md)
  runs arbitrary CLI agents through a detached tmux controller and a file
  sentinel protocol.

We took two ideas: durable file-backed state and a fresh verifier. The plugin
itself was not installed because its instructions assume Claude Code, and
`open-agent-teams` would add a second tmux delegation layer on top of the Pi
subagent extension. The recurring business/domain loop in `new-loop` is also a
different scope from one feature implementation.

## Findings

- F1: Stock Pi has enough extension and skill surfaces to build the requested
  first version without forking the runtime.
- F2: Amos's `pi-config` is most useful as a menu of patterns. The separate
  interactive-subagents package is the reusable runtime component.
- F3: A reviewer must have an isolated context and no edit tools. Asking the
  implementing child to review itself does not meet the requested separation.
- F4: Durable task state is needed because async child results, session restarts,
  and review corrections can span multiple turns.
- F5: Parallel writers in one working tree are unsafe unless their file and
  generated-output sets cannot overlap. The initial implementation therefore
  defaults to one writer at a time.
- F6: FirstMate and the local Pi loop solve overlapping user experiences at
  different scales. They should be separate profiles rather than one combined
  prompt stack.
- F7: Oh My Pi already solves several gaps in this first version, especially
  isolated worktrees and structured results. It remains the main alternative,
  not merely a source of snippets.

## Decisions implemented

- D1: Keep stock Pi as the executable and manage its profile from
  `home/.pi/agent`.
- D2: Install only `pi-interactive-subagents`, pinned to the inspected commit.
- D3: Define local `planner`, `implementer`, and `reviewer` roles, all using the
  already configured `opencode/kimi-k2.6` model.
- D3a: Override the package's bundled `scout`, `worker`, and `researcher`
  definitions with hidden compatibility aliases. This prevents accidental use
  of their OpenRouter defaults and of web tools that are not installed.
- D4: Put orchestration policy in an on-demand `feature-loop` skill instead of
  an always-loaded global system prompt.
- D5: Persist approved work in
  `.agents/tasks/<feature-slug>/plan.md` inside the target repository.
- D6: Require a fresh reviewer verdict after implementation and allow at most
  three implementation-review attempts before returning a repeated blocker to
  the user.
- D7: Default to sequential writers. Worktree creation and merging are not part
  of this first version.
- D7a: Do not ship a tmux wrapper launcher. The user's shell already runs
  inside tmux, and the extension returns a clear error otherwise. An earlier
  `pi-loop` script was removed because it coupled starting Pi to one workflow.
- D8: Add a separate `~/.pi/firstmate` profile with no global packages. It
  shares only `auth.json`, allowing FirstMate's project-local Pi extensions to
  load without the normal profile's subagent tool and feature skill.

## Files added

Normal Pi profile:

- `home/.pi/agent/settings.json`: existing model preferences plus the pinned Git
  package.
- `home/.pi/agent/agents/planner.md`: read-only repository inspection and task
  planning.
- `home/.pi/agent/agents/implementer.md`: bounded editing and verification.
- `home/.pi/agent/agents/reviewer.md`: no edit/write tools, independent findings
  and an `APPROVE`, `REQUEST_CHANGES`, or `BLOCKED` verdict.
- `home/.pi/agent/agents/scout.md`, `worker.md`, and `researcher.md`: hidden
  overrides for names hard-coded as examples by the upstream extension. Scout
  and worker map to local behavior; researcher reports that web research is not
  configured.
- `home/.pi/agent/skills/feature-loop/SKILL.md`: top-level workflow and retry
  policy.
- `home/.pi/agent/prompts/feature-loop.md`: `/feature-loop` starter text.
- `home/.pi/agent/.gitignore`: excludes credentials, sessions, installed
  packages, artifacts, model state, and the existing generated tma hook.

Profile separation and launcher:

- `home/.pi/firstmate/settings.json`: same model preferences, no packages.
- `home/.pi/firstmate/.gitignore`: excludes runtime and credential state.
- `home/.local/bin/pi-firstmate`: selects `PI_CODING_AGENT_DIR=~/.pi/firstmate`,
  creates a relative link to the normal profile's auth file if needed, and
  prepends the shim directory below to `PATH`.
- `home/.local/libexec/pi-firstmate/pi`: shim that exports the firstmate
  profile when `FM_PI_HARNESS` is set and `PI_CODING_AGENT_DIR` is not, then
  execs the next `pi` on `PATH`. See R7.
- `home/.pi/README.md`: operator notes and upstream references.

The prior live settings file is recoverable at
`~/.pi/agent/settings.before-dotfiles-20260901.json`. It contains only the five
pre-existing Pi settings. The active settings path is now a Stow symlink into
this repository.

## Intended runtime flow

1. Run `pi` inside tmux in a target repository. The subagent tool refuses
   to spawn outside tmux and says so; no wrapper launcher is used.
2. Invoke `/feature-loop` or ask Pi to plan and implement a feature with
   subagents and independent review.
3. The parent talks through the outcome and acceptance criteria.
4. The parent sends the full brief to the read-only planner.
5. After approval, the parent creates the durable plan ledger.
6. The parent dispatches one bounded implementer task.
7. The parent confirms that the claimed diff exists, then dispatches a fresh
   reviewer.
8. Blocking findings become the next bounded implementation attempt. Approved
   tasks are marked complete.
9. Aggregate checks run after all task reviews pass, and their exact outcomes
   are written to the ledger.

For a FirstMate trial, clone FirstMate and launch `pi-firstmate` from its root.
That profile has no user packages, so FirstMate supplies the orchestration from
its own `AGENTS.md`, skills, scripts, and `.pi/extensions`.

## Validation performed

- V1: Both JSON settings files passed `jq empty`.
- V2: The `pi-firstmate` launcher passed `bash -n` and is executable.
- V3: `git diff --check` passed.
- V4: A Stow dry run identified only the expected existing settings conflict.
  The old file was backed up and `stow home` then deployed all new links.
- V5: `pi install` cloned the pinned interactive-subagents commit below the
  ignored `~/.pi/agent/git/` directory and completed its dependency audit with
  zero reported vulnerabilities.
- V6: `pi list` shows the pinned package in the normal profile.
- V7: `pi-firstmate list` reports no installed packages.
- V8: The FirstMate profile's `auth.json` link points to
  `../agent/auth.json`, and its settings file points into this repository.
- V9: Pi's model catalog confirmed `opencode/kimi-k2.6` exists and supports
  thinking.
- V10: A detached tmux startup with `pi --verbose` loaded the tracked
  `feature-loop` skill, `/feature-loop` prompt, existing tma hook, and pinned
  interactive-subagents extension without a startup error. The session was
  then closed without making a model request.

The package install printed an existing npm configuration warning about an
unknown `npm` user key, but completed successfully. Pi startup also reported an
unrelated pre-existing `react-components` skill-name conflict below
`~/.agents/skills/`; this work did not change that skill.

No paid end-to-end model turn has been run yet. The final smoke test must prove
that a real parent started inside tmux sees all three local agents,
spawns each one, receives steered completion results, and handles a reviewer
correction cycle.

## Risks and unresolved questions

- R1: Pi has no OS sandbox. The implementer receives unrestricted `bash`, and
  the reviewer's read-only policy is partly prompt-enforced because its `bash`
  tool can still mutate state. A container or a stricter command extension is
  needed for a hard boundary.
- R2: All roles use the same Kimi model. Context separation is real, but model
  diversity is not. A different reviewer model may catch different failures.
- R2a: The package also ships a `safe_bash` tool that blocks `sudo`,
  `rm -rf /`, `mkfs`, and `curl | sh` patterns. The reviewer uses plain `bash`
  because `safe_bash` still allows `git checkout .`, `git stash`, and ordinary
  file deletion, so it does not deliver the read-only guarantee asked for in
  Q3. Switching the reviewer to `safe_bash` costs nothing and removes the
  worst commands; it is not a substitute for a container.
- R3: The initial loop has no automatic worktree isolation. Sequential writers
  prevent most collisions but do not isolate a failed attempt from the user's
  working tree.
- R4: The task ledger is created inside each target repository. Teams may want
  it committed, ignored, or stored outside the project; the policy is currently
  unspecified.
- R5: A package commit pin will not receive upstream fixes automatically. An
  update procedure should inspect upstream changes, advance the hash, reinstall,
  and repeat the smoke test.
- R6: The profile split shares `auth.json`. It separates behavior and runtime
  state, not credentials.
- R7: Confirmed on 2026-09-01 by reading FirstMate's `bin/fm-spawn.sh` and
  `bin/backends/tmux.sh`: crew workers are launched by resolving `pi` from
  `PATH` and sending the command with `tmux send-keys` into a new window of
  a `firstmate` tmux session. That shell inherits the tmux server
  environment, not the primary's, and FirstMate prefixes only
  `FM_PI_HARNESS=pi` onto the launch. So `pi-firstmate` isolates the primary
  only; every Pi crew worker runs with the normal `~/.pi/agent` profile,
  including the subagent package, `tma.js`, and the feature-loop skill.
  Workers also get no `--no-extensions`, so the two dispatch systems would
  coexist in one worker. Fixes, best first: an upstream change that carries
  `PI_CODING_AGENT_DIR` onto the launch line the way `FM_PI_HARNESS` already
  is; or a local `pi` shim ahead of the real binary that exports the
  firstmate profile when `FM_PI_HARNESS` is set and `PI_CODING_AGENT_DIR` is
  not. Setting the variable in the tmux server environment is not an option
  because it would redirect every Pi launch.

  The shim was implemented on 2026-09-01 at
  `home/.local/libexec/pi-firstmate/pi`. A global `~/.local/bin/pi` would
  not work because the per-user Nix profile precedes `~/.local/bin` on
  `PATH`, so `pi-firstmate` prepends the shim directory instead; FirstMate
  then resolves the shim's absolute path in the primary and every crew
  launch goes through it. Verified with two detached starts of the shim
  itself: with `FM_PI_HARNESS=pi` and no `PI_CODING_AGENT_DIR` Pi loaded no
  extensions (firstmate profile); without `FM_PI_HARNESS` it loaded `tma.js`
  and the subagent package (normal profile). `pi-firstmate --version` still
  passes through. The upstream change remains the cleaner fix.
- R8: The three-attempt reviewer limit is policy in a skill, not an enforced
  state machine. A misbehaving top-level model could ignore it.
- R9: The selected extension is tmux-only. Oh My Pi and FirstMate offer broader
  runtime choices if tmux becomes a constraint.
- R10: The unrelated global `react-components` skill conflict means Pi is
  currently skipping that skill. It does not block this loop, but a separate
  cleanup should fix its declared name.
- R11: On a machine where `~/.pi` does not yet exist, GNU Stow folds the whole
  directory into one symlink pointing at `home/.pi/` in this repository. Pi
  then writes `auth.json`, `sessions/`, `git/`, and `models-store.json` inside
  the repository. The per-profile `.gitignore` files cover the state Pi writes
  today, and Stow's default ignore list keeps those `.gitignore` files out of
  `~/`. Any new Pi state directory, or a manual backup such as
  `settings.before-*.json`, would show up as untracked until the ignore list is
  extended. The V4 Stow test only covered the existing-directory case.
- R12: Pi rewrites `settings.json` itself. Its changelog documents writing
  `lastChangelogVersion` on every interactive startup after a version bump, and
  `/model` or `/theme` changes persist there too. Because the live file is a
  symlink into this repository, each `llm-agents` bump or in-app preference
  change dirties the working tree. Either commit those writes as they appear or
  accept the noise; no mechanism keeps the tracked file read-only.

## Independent reviewer checklist

- Q1: Does a real tmux-hosted `pi` session discover the three local agent definitions
  and the `/feature-loop` prompt without startup errors?
- Q2: Does the tool allowlist remain intact in child and resumed sessions?
- Q3: Can the reviewer run the required tests without gaining an unacceptable
  mutation path through `bash`? See R2a for why `safe_bash` does not close this
  gap on its own.
- Q4: Should task attempts run in disposable Git worktrees before this is used
  on repositories with valuable uncommitted work?
- Q5: Should the reviewer use a different provider or model from the
  implementer?
- Q6: Is `.agents/tasks/` the right durable location and should it be committed?
- Q7: Does a real FirstMate run through `pi-firstmate` load its project-local
  watcher extensions and avoid the normal profile's `subagent` tools?
- Q8: Does Oh My Pi's built-in worktree, typed-result, and `/review` stack remove
  enough local code and policy to justify switching runtimes?
- Q9: Is FirstMate's larger fleet and PR delivery model closer to the actual
  long-term goal than either the local Pi loop or Oh My Pi?

## tma integration

[tma](https://github.com/pperanich/tmux-agents) `0.5.7` is already installed
and its Pi bridge, `~/.pi/agent/extensions/tma.js`, already loads in the
normal profile. It fits as an observability and scripting layer beside the
subagent extension, not as a replacement for it. The extension owns spawning,
steering, and result routing; tma owns pane state, freshness, the fleet view,
`tma wait`, and notifications. Spawning should stay out of tma.

What works today with no code:

- `tma ls --json` lists the orchestrator, its children, and every other agent
  pane with repo, branch, state, and freshness.
- `tma wait --repo <name> --all --until idle` is a barrier for a headless run
  driven by a shell script or by FirstMate.
- `[notify] on = ["blocked", "done"]` in `~/.config/tma/config.toml` fires
  when any tracked pane finishes.

Gaps found by reading `pi.toml`, the pane-option contract, and the spawn path
in `pi-extension/subagents/index.ts`, least to most important:

- G6: No `tma act` actions exist for Pi. Only `interrupt` (an Escape key
  sequence) makes sense. Answering a child's `ask_question` belongs to the
  parent through `subagent_message`, not to tma.
- G5: Two freshness truths. The extension polls its own
  `PI_SUBAGENT_ACTIVITY_FILE` and marks a child stalled after 60 seconds; tma
  keeps `@agent_stamped_at`. Not a blocker. The extension could read tma pane
  options later, but that is an upstream decision.
- G4: Parent and children are indistinguishable. All show the title
  `π - <repo>`, the same cwd, and the same process name. The child environment
  carries `PI_SUBAGENT_AGENT`, `PI_SUBAGENT_NAME`, and `PI_SUBAGENT_ID`, so tma
  could read the child process environment for a role label, or the extension
  could set the pane title. This only affects picker legibility.
- G3: No lineage for Pi. tma already tracks `@agent_subagents`, but only from
  Claude Code's `SubagentStart` and `SubagentStop` hooks. A child-side
  `session_start` could emit its parent pane and subagent id. That would allow
  a tree in the fleet view and a `tma wait --all` scoped to one orchestrator's
  children instead of a whole tmux session.
- G2: `ask_question` is a real blocked state tma cannot see. The manifest
  correctly says Pi has no blocked state, but a child parks in phase `waiting`
  on `ask_question` until the parent answers. `tma-core` already reserves the
  detail token `question`. Mapping `tool_execution_start` with
  `toolName == "ask_question"` to `blocked/question`, and `tool_execution_end`
  back to `working`, covers it. Pi `0.84` also fires `ui_prompt_start` and
  `ui_prompt_end` around every `ctx.ui.confirm`, `select`, `input`, `editor`,
  and `custom` prompt, with a `kind` field. Those two events are the cleaner
  source: they cover `ask_question`, a future command-guard extension's
  confirm, and any other extension prompt with one mapping. This is the state
  that most deserves a notification.
- G1: Children never load `tma.js`. Every child spawns with `--no-extensions`
  and only `subagent-done.ts` is forced in with `-e`. Children therefore fall
  to the capture tier: no session id, no lifecycle, no context telemetry, and
  G2 and G3 are impossible. The fix is upstream and small: an environment
  variable such as `PI_SUBAGENT_EXTRA_EXTENSIONS`, or a settings key, that the
  spawner appends as extra `-e` arguments. A local workaround exists through
  the extension's `registerToolExtension` hook, but it requires listing a tool
  name that `tma.js` does not register, so it is a hack and not recommended.

Order: G1 first, as one pull request to the subagent extension. Then G2 and G3
in `tma.js` and `pi.toml`, both under local control. Together they make the
feature loop supervisable from a shell script or FirstMate with `tma wait` and
`tma ls --json`, without the extension's widget. Nothing in this repository
changes until G1 lands.

## Project-local Pi configuration

Pi discovers per-project resources after a one-time `/trust` decision:
`.pi/extensions/*.ts` (hot-reloadable with `/reload`), `.pi/skills/` and
`.agents/skills/`, `.pi/prompts/`, `.pi/settings.json` merged over the global
file, and `.pi/agents/` read by the subagent extension with project-over-global
precedence. Extensions can import from the project's `node_modules`. Project
configuration belongs in the project's own repository, not here; this section
records what was learned about the pattern.

### How other projects commit `.pi/`

Hand-verified against GitHub trees on 2026-09-01. GitHub code search is
login-gated, so this is a sample, not a census. Most `.pi/` usage in the wild
is in personal config repositories; these are real projects.

- E1: [earendil-works/pi](https://github.com/earendil-works/pi), Pi itself.
  Four extensions (`/ir` imports a CI repro session, a widget that detects
  PR/issue URLs in the prompt and renames the session, tokens-per-second stats,
  a TUI redraw counter), five prompts (`/pr` review, `/is` issue analysis,
  security advisory drafting, changelog audit, wrap-up commit and push), one
  skill for adding an LLM provider. `.pi/git/` and `.pi/npm/` are gitignored.
  `AGENTS.md` is about 2000 words and does not mention `.pi/`.
- E2: [kunchenguid/firstmate](https://github.com/kunchenguid/firstmate). The
  heaviest user. Four extensions: a `tool_call` guard that blocks bash commands
  violating its cd and watcher constraints, a watcher process manager tool, a
  supervision-branch tool, and `/calm` quiet renderers. About twenty skills in
  `.agents/skills/`. Its README tells Pi users to accept the trust prompt once.
- E3: [earendil-works/absurd](https://github.com/earendil-works/absurd).
  Prompts only: `make-migration` diffs the SQL schema since the last release,
  `make-release`, `update-changelog`.
- E4: [mitsuhiko/minijinja](https://github.com/mitsuhiko/minijinja). Prompts
  only: `make-release` and `update-cabi-header`, which syncs a C header with
  Rust FFI exports.
- E5: [imankulov/news-reader](https://github.com/imankulov/news-reader).
  `.pi/SYSTEM.md` replaces the system prompt; one extension registers an
  allowlisted `web_fetch` and a save tool, importing project dependencies.

Checked and found no `.pi/`: openclaw, pi-web, oh-my-pi, gondolin, insta.
openclaw and pi-web keep skills in `.agents/skills/` only.

Advice from Ronacher, Imankulov, Zechner, Hooks, and Pi discussion #3373 that
held up against the repositories above:

- Prompts are the dominant committed artifact: release, changelog, migration,
  review. Extensions appear only when the project has its own runtime to
  drive.
- `tool_call` guards are the standard safety layer and are usually global. Only
  FirstMate ships one project-locally, because its rules are project-specific.
- `AGENTS.md` is routing; procedures live in skills. Enforce allowlists in
  code, not in prompt text.
- Prefer file-backed state and CLI wrappers with READMEs over built-in
  features. Wrap project infrastructure as tools, not raw APIs.

### Pattern for a new project

Applied once so far, in order of payoff:

- P2: One task-runner target that is the whole agent gate, mirroring the
  project's CI order exactly. Implementer and reviewer both cite it. Do not
  add a task that launches Pi; that repeats the `pi-loop` mistake.
- P1: `.pi/prompts/` for the release, changelog, and migration chores the
  project already scripts, adapted from E3 and E4.
- P5: `.pi/extensions/guard.ts`, a `tool_call` handler returning
  `{ block: true, reason }`. Pi has no hook system, so this is the only
  pre-write gate. Keep only project-specific rules there and give each an
  escape hatch that matches the later gate it mirrors. Generic rules
  (`git commit --no-verify`, `git push --force`) belong in a global guard
  under `home/.pi/agent/extensions/`. Until G1 lands a project guard covers
  the parent session only; children spawn with `--no-extensions`.
- P3: `.pi/agents/reviewer.md` and `implementer.md` overriding the global
  roles with the project's checklist. The feature loop picks them up with no
  other change. Wait for the feature-loop smoke test first.
- P4: Move procedure-shaped `AGENTS.md` sections into on-demand skills under
  `.agents/skills/`, symlinked from `.claude/skills/<name>` so Claude Code
  reads the same files.

Gitignore `.pi/git/` and `.pi/npm/` as E1 does.

Gotchas found on the first application: a prompt template whose
`description` contains an unquoted colon fails YAML parsing and is silently
skipped; a guard that bans a character must not contain that character in its
own source if a commit hook scans it; a verification target that byte-compares
generated trees fails in a fresh worktree when those trees are untracked, so
order the steps as CI does and run any generate step before the compare.

## Reference index

Core Pi:

- [Pi source repository](https://github.com/earendil-works/pi)
- [Pi website and documentation](https://pi.dev/)
- [Pi packages](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/packages.md)
- [Pi extensions](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/extensions.md)
- [Pi skills](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/skills.md)

Amos Blomqvist's Pi work:

- [pi-config](https://github.com/amosblomqvist/pi-config)
- [pi-interactive-subagents](https://github.com/amosblomqvist/pi-interactive-subagents)
- [pi-subagents](https://github.com/amosblomqvist/pi-subagents)
- [pi-observational-memory](https://github.com/amosblomqvist/pi-observational-memory)
- [pi-dictate](https://github.com/amosblomqvist/pi-dictate)
- [learn](https://github.com/amosblomqvist/learn)
- [Pi Coding Agent Setup After 2 Months](https://www.youtube.com/watch?v=DWWrLlM3gwQ)
- [Eero Alvar's YouTube channel](https://www.youtube.com/@EeroAlvar)

Alternatives and borrowed patterns:

- [Oh My Pi](https://github.com/can1357/oh-my-pi)
- [Oh My Pi documentation](https://omp.sh/docs/)
- [FirstMate](https://github.com/kunchenguid/firstmate)
- [FirstMate architecture](https://github.com/kunchenguid/firstmate/blob/main/docs/architecture.md)
- [AI Builder Club skills](https://github.com/AI-Builder-Club/skills)
- [AI Builder Club new-loop skill](https://github.com/AI-Builder-Club/skills/blob/main/skills/new-loop/SKILL.md)
- [AI Builder Club setup-codebase-harness skill](https://github.com/AI-Builder-Club/skills/blob/main/skills/setup-codebase-harness/SKILL.md)
- [AI Builder Club verifier-setup skill](https://github.com/AI-Builder-Club/skills/blob/main/skills/verifier-setup/SKILL.md)
- [AI Builder Club open-agent-teams skill](https://github.com/AI-Builder-Club/skills/blob/main/skills/open-agent-teams/SKILL.md)
- [Open agent skills catalog](https://skills.sh/)

Project-local Pi usage and advice:

- [Armin Ronacher, Pi: The Minimal Agent Within OpenClaw](https://lucumr.pocoo.org/2026/1/31/pi/)
- [Roman Imankulov, Agent engineering: Pi](https://roman.pt/posts/pi-dev-version/)
- [Mario Zechner, Pi coding agent announcement](https://mariozechner.at/posts/2025-11-30-pi-coding-agent/)
- [Joel Hooks, Extending Pi with custom tools](https://joelclaw.com/extending-pi-with-custom-tools)
- [Pi discussion #3373 on permission gates](https://github.com/earendil-works/pi/discussions/3373)

## Recommendation for the reviewer

Run one medium-sized feature through this setup before adding more extensions.
The test should require at least two implementation tasks and one deliberately
seeded reviewer correction. If that run proves agent discovery, durable state,
and correction routing, keep this stock-Pi path and add worktree isolation next.

If the run exposes substantial work around isolation, structured child output,
review UI, or retry enforcement, compare the same feature in Oh My Pi before
building those systems locally. Use FirstMate as the comparison when the real
target is a persistent crew shipping across multiple repositories. For the
current goal of owning a small talk-plan-implement-review loop, the implemented
stock Pi profile is the lowest-commitment path that can produce useful evidence.
