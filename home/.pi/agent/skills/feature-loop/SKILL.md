---
name: feature-loop
description: Plan and implement a repository feature through a top-level Pi orchestrator, bounded implementation subagents, independent reviewers, and a persisted task ledger. Use when the user asks to plan and build a feature, execute an implementation plan, or run a feature autonomously with review.
---

# Feature implementation loop

The top-level Pi session owns product decisions, the approved plan, task
routing, and the final report. Subagents receive bounded work. Do not hand the
entire feature to one implementer.

## 1. Frame the feature

Turn the request into a short brief containing:

- desired user-visible outcome;
- acceptance criteria;
- constraints and explicit non-goals;
- the repository root and relevant project instructions;
- any decision that must remain with the user.

Ask only questions whose answers would materially change the result. If the
user explicitly asks for planning only, stop after the approved plan.

## 2. Ground the plan

Call `subagents_list` and confirm that `planner`, `implementer`, and `reviewer`
are available. If the subagent extension is unavailable or reports that tmux
is missing, explain that Pi must be started inside a tmux session. Do not
silently run the multi-agent workflow as one agent.

Spawn `planner` with the complete brief. The planner is read-only and must cite
the repository files it inspected. Resolve its material questions with the
user, then present the proposed task plan for approval. Approval may be
inferred only when the user already said to implement without another pause.

After approval, create `.agents/tasks/<feature-slug>/plan.md` in the target
repository with this shape:

```markdown
# <Feature>

Status: approved

## Outcome

...

## Acceptance criteria

- [ ] ...

## Tasks

- [ ] T1: ...

## Decisions

- YYYY-MM-DD: ...

## Attempts

- YYYY-MM-DD T1 A1: dispatched

## Review

- Pending

## Verification

- Pending
```

This file is the durable handoff between turns and agents. Update it after each
implementation attempt and review. Never put secrets, tokens, or credentials
in it.

## 3. Implement bounded tasks

For each ready task, spawn `implementer` with:

- the exact task and acceptance criteria;
- the plan path;
- relevant files and conventions found during planning;
- explicit scope boundaries;
- required verification commands;
- prior reviewer findings, when this is a correction attempt.

Default to one writer in a working tree at a time. Run implementers in parallel
only when their file sets and generated artifacts cannot overlap. The
top-level session may inspect short summaries and diffs, but should leave
mechanical implementation to the subagent.

Record the result and checks in the task ledger. A subagent summary is a lead,
not proof. Confirm the working tree contains the claimed changes.

## 4. Review independently

After an implementation task or coherent task group, spawn a fresh `reviewer`.
Give it the complete acceptance criteria, plan path, diff scope, and verification
expectations. Do not tell it to validate the implementer's conclusion.

Handle the verdict:

- `APPROVE`: mark the reviewed tasks complete.
- `REQUEST_CHANGES`: record the findings and dispatch a new bounded correction
  attempt to an implementer.
- `BLOCKED`: gather the missing evidence or ask the user for the required
  decision.

Limit a task to three implementation-review attempts. After the third failed
review, stop and give the user the evidence, repeated failure, and smallest
decision needed to proceed.

## 5. Close the loop

Run the repository's required aggregate checks after all tasks pass independent
review. Update the acceptance criteria and verification sections with exact
commands and outcomes. Set the ledger status to `complete` only when every
criterion is checked and no blocking review finding remains.

Report the resulting behavior, important files changed, verification evidence,
and any residual risk. Do not commit, push, merge, or open a pull request unless
the user separately authorized it.
