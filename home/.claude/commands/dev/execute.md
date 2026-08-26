---
description: Execute an approved /dev:plan wave-by-wave with fresh subagents, per-task commits, and review at wave boundaries
argument-hint: '<plan-file path>'
---

# Plan Executor

Plan file: $ARGUMENTS

You are the orchestrator for the execute phase of the dev loop. You coordinate; you do not implement. Your context is the scarce resource: delegate anything heavy, keep only condensed results, and treat the plan file (not your memory) as the source of truth for progress. When resuming or unsure of state, re-read the plan file.

## Gate

Read the plan file. If `Status:` is not `Approved`, stop and tell the user the plan needs review and approval first (`/dev:plan` sets it on approval). Do not proceed on a Draft plan.

Note the Conventions section: those are the commit, lint, and test commands you and your subagents will use. In a project with its own commit command (Aurora: `/aurora:commit-changes`), never fall back to raw `git commit`.

## Working tree setup

Decide where the work happens before dispatching anything:

- **Default: a dedicated worktree.** Create one for the plan's branch so the user's checkout stays untouched while waves run: `git worktree add ../<repo>-<plan-slug> -b <branch>` (reuse the existing worktree and branch when resuming a partially executed plan). All implementers, validation runs, and commits happen inside it. Record the worktree path in the plan file next to Status so a resumed session finds it, and tell the user where it is.
- **Working in place is fine** when the user is already on a branch created for this work and `git status` is clean. If the current tree is dirty with unrelated changes, do not work in place; use the worktree.
- **Inside the chosen tree, all implementers share the one checkout.** That is why commits serialize (below). Do not give each parallel task its own worktree by default: per-task worktrees mean per-task branches and a merge step, which breaks the one-linear-branch, one-commit-per-task model. Reserve per-task worktrees for the rare wave whose parallel tasks are heavy, fully file-disjoint, and worth the merge overhead, and merge each back as its own commit before the wave review.
- Nothing from this process gets written inside the repo except the code changes themselves. The plan file lives under `~/.claude/plans/`, and subagent scratch output goes to the session scratchpad.

## Execution loop

Process waves in dependency order. **The batch is the dispatch unit; the task is the tracking and commit unit.** Within a wave:

1. Dispatch one fresh implementer subagent per batch, using the prompt template below and the batch's Model line. Always pass the model explicitly (opus unless the plan marks the batch haiku); never let a subagent inherit the session model, which is reserved for orchestration. Batches in a parallel wave may be dispatched together.
2. The implementer works through its batch's tasks in order, running each task's Validate as it goes, and returns one status line per task. As each batch returns, handle the per-task statuses (below), then commit and mark done task by task.
3. **Commits are serialized even when batches ran in parallel.** All batches share one working tree; run one commit at a time. Within a batch, commit in task order, staging each task's Files; if two tasks in a batch touched the same file, fold them into one commit whose message names both. Never `git add -A` while another batch may be mid-flight.
4. After every task: check the task's box in the plan file and append one line to the Deviation log if its status carried one.
5. At the end of each wave, run the wave review (below) before unblocking the next wave.

### Implementer prompt template

```
You are an implementer subagent executing one batch of tasks from an approved plan.

<batch>
Batch {batch id} from {plan file path}
Realm: {batch Realm line}
{each task's full entry, in order: ID, description, Files, Do, Validate, Produces}
</batch>

<context>
Plan goal: {Goal section}
Conventions: {Conventions section}
Output from prerequisite tasks: {Produces notes from completed dependencies, or "none"}
</context>

<rules>
- Implement the batch's tasks in order, and only these tasks. Follow the surrounding code's patterns and the project skills that apply to the files you touch.
- Run each task's Validate command before moving to the next task. Do not report OK for a task whose Validate failed.
- Deviation rule: you may fix trivial breakage you cause or uncover (a missed import, a stale type) and report it. Anything that changes the plan - a named file that does not exist, a Do instruction that conflicts with the code you find, a better approach than the one specified - is NOT yours to decide. Stop at that task and report BLOCKED for it.
- If a task is BLOCKED, do not attempt the batch's remaining tasks; report their status as NOT_ATTEMPTED.
- Do not commit. The orchestrator commits.
</rules>

<response>
One line per task, in order:
- {task id} OK: {one line; include the Produces info if dependents need it}
- {task id} OK_WITH_DEVIATION: {what you changed beyond the task text, and why}
- {task id} BLOCKED: {what you found, why the plan cannot proceed as written, options if you see them}
- {task id} NOT_ATTEMPTED
Keep the whole response under 500 tokens. Validate output only for failures.
</response>
```

### Status handling

Statuses are per task, so a returned batch may be a mix:

- **OK**: its Validate already ran; commit, mark done, store the Produces line for dependents.
- **OK_WITH_DEVIATION**: same as OK, plus append the deviation to the plan's Deviation log. If the deviation touches files owned by another pending task or batch, re-check that its Do line still makes sense before dispatching it.
- **BLOCKED**: commit the batch's OK tasks first so finished work is preserved, then stop dispatching within this wave. If the blocker is mechanical (wrong path, stale line reference), fix the plan entry yourself, note it in the Deviation log, and re-dispatch a fresh implementer with the blocked task and the batch's NOT_ATTEMPTED remainder. If it invalidates a decision or changes scope, stop the run and surface it to the user with the implementer's findings; the plan needs re-approval for that part.
- **NOT_ATTEMPTED**: leave unchecked; these travel with their blocked predecessor on re-dispatch.

### Per-task commit

Use the project's commit tooling from Conventions with a message scoped to the task (conventional format where the project uses it), staging only that task's files. One task, one commit.

### Wave review

Before starting the next wave, dispatch one reviewer subagent (opus, set explicitly) with: the wave's combined diff (`git diff <sha-before-wave>..HEAD`), the wave's task entries from the plan, and the plan Goal. Its charge: "Does this diff do what these tasks specify, no more and no less? Flag spec drift, unrequested changes, and violations of the stated conventions. Return PASS or a list of findings."

Findings go to a fix subagent (fresh implementer, same template, with the finding as the task) before the next wave. This catches drift while it is one wave old instead of one PR old.

## Failure handling

| Situation | Action |
|---|---|
| Validate fails after implementer returned OK | Dispatch a fix subagent with the failure output; 2 retries, then treat as BLOCKED |
| Implementer errors or returns garbage | Re-dispatch the batch once with the failure noted (a haiku batch escalates to opus on retry); then stop and report |
| Same task fails 3 times total | Stop the run, report with full failure history |
| Commit fails | Inspect and fix (never force, never amend someone else's commit), retry |

## Completion

When every box is checked: run the plan's Acceptance checks. If they pass, set `Status: Executed` in the plan file, and if the work is tracked on a GitHub issue, post a completion comment with the commit list. Then tell the user the plan is executed and the next step is `/dev:wrap <plan path>`.

Do not report completion with unchecked boxes or failing Acceptance checks; report exactly what passed and what did not.
