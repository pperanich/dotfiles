---
description: Decompose a design or request into a wave-grouped, validated task plan for /dev:execute
argument-hint: '<design-doc path | issue ref | description>'
---

# Plan Writer

Input: $ARGUMENTS

You are running the plan phase of the dev loop (design -> plan -> execute -> wrap). Planning only: do NOT start implementation.

## Project tooling first

Read the project's root `CLAUDE.md` and note which of these the project provides, because the plan's validation and finalization tasks must use them instead of generic commands:

- Lint / typecheck / test commands (Aurora: `/aurora:lint`, plus per-subsystem CLAUDE.md commands)
- Commit conventions or a commit command (Aurora: `/aurora:commit-changes`, conventional commits)
- A pre-push gate (Aurora: `/aurora:push-safe` or the `no-mistakes` skill)
- Domain skills that constrain how code is written (Aurora: the `frontend-*`, `backend-*`, `global-*` skills)

Record the relevant ones in the plan's Conventions section so executors do not have to rediscover them.

## Step 1: Ground the plan in reality

- If the input is a design doc, read it fully. Its Decisions and Constraints bind this plan; do not relitigate them.
- If the input is an issue reference, fetch it and its comments (`gh issue view <n> --json title,body,comments`).
- Search the codebase for every file the work will touch. Never write a path you have not confirmed exists (or explicitly mark it as new).

## Step 2: Write the plan

Write to `~/.claude/plans/<repo-name>/<YYYY-MM-DD>-<slug>.md`, where `<repo-name>` is the basename of `git rev-parse --show-toplevel` (create the directory if needed). Loop artifacts stay outside the repo, always: the plan file, checker output, and any notes must never appear in `git status`. Temporary scratch files go to the session scratchpad. The plan lives at a stable path outside the repo (not the scratchpad) because execution often happens in a later session and the file is the loop's persistent state. Format:

```markdown
# Plan: <title>

Status: Draft
Source: <design doc path, issue URL, or "conversation">
Date: <date>

## Goal
Two or three sentences: the observable end state.

## Conventions
Project commands the executors must use (commit, lint, test, gate), with exact invocations.

## Waves

### Wave 1: <name>
Depends on: none
Parallel: yes|no   (parallel means the wave's batches run concurrently)

#### Batch 1a
Realm: <the subsystem or area these tasks share>
Model: opus

- [ ] **1A** <task description>
  - Files: `path/one.py`, `path/two.py (new)`
  - Do: <specific instructions: what to change, which pattern to follow, referencing a concrete existing example in the codebase where one exists>
  - Validate: <exact command to run and what output counts as pass>
  - Produces: <what dependent tasks need to know: exported names, endpoints, file paths>
- [ ] **1B** <task description>
  - ...

### Wave 2: <name>
Depends on: Wave 1
...

## Acceptance
The end-to-end checks that prove the goal, beyond per-task validation. Runnable commands or concrete manual steps.

## Deviation log
(empty; executors append here)
```

Rules:

- **The no-context bar**: every task must be completable by an engineer who has read nothing but this plan and the files it names. If a task needs conversation context, the context goes into its Do line.
- Every task has a Validate line with a runnable check. "Tests pass" is not a check; `uv run pytest tests/test_x.py -k roster` is.
- **Batching**: the batch is the dispatch unit (one subagent executes a whole batch, tasks in order); the task stays the tracking and commit unit. Batch tasks together when they share a realm (same subsystem, same handful of files, the same pattern applied in several places) or when each is too small to justify its own dispatch: an agent that just made the first edit does the related second one better and cheaper than a fresh agent re-reading the same files. A lone substantial task is its own batch.
- **Batch size cap**: the whole batch (its tasks, the files an implementer must read, its validation runs) should fit comfortably in roughly the first half of a fresh context window, so the agent finishes with room to spare. If you cannot say that confidently, split the batch. One task, one concern, one commit still holds within the batch.
- A wave is parallel only if its batches share no files and need nothing from each other. When in doubt, sequential. Within a batch, tasks may build on each other (they run in order in one context).
- **Model**: set explicitly on every batch, and default to opus for all implementation. haiku is acceptable only for purely mechanical batches (renames, config value bumps, formatting). Never omit it: an unset model makes the subagent inherit the session model, which is reserved for orchestration.

## Step 3: Check the plan before showing it

Spawn one checker subagent (opus, fresh context, read-only) with the plan file path and this charge: verify every named file exists or is marked new, every task has a runnable Validate line, every batch has a Model line and is cohesive and within the size cap, no two batches in a parallel wave touch the same file, wave dependencies are acyclic, and each task passes the no-context bar. It returns a list of violations or "PASS".

Fix violations and re-run the checker until it passes. Do not present a plan that has not passed.

## Step 4: Hand to the human

Present a short summary: goal, wave count, task count, anything risky. The human reviews the plan file itself; reviewing plans is where their attention buys the most (fixing a plan is cheap, fixing 20 commits is not).

When they approve, set `Status: Approved` in the plan file. If the work is tied to a GitHub issue and the project tracks progress there (Aurora does), also post the plan as an issue comment.

`/dev:execute` refuses Draft plans, so approval is not skippable by accident.

Next step: `/dev:execute <plan path>`.
