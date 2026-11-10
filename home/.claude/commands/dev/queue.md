---
description: Pull issues assigned to you in this repo and run the dev loop per issue, pausing only for plan approval
argument-hint: '[issue numbers... | blank to pick from the list]'
---

# Issue Queue Runner

Arguments: $ARGUMENTS

Drive the dev loop (plan -> approve -> execute -> wrap) over GitHub issues assigned to the current user. One human pause per issue: plan review. Everything after approval runs without questions unless something genuinely blocks.

## Project tooling first

Read the project's root `CLAUDE.md` and `.claude/` config. If the project has its own issue automation, mention it before starting so the user can choose (label-triggered CI automation runs fully non-interactively, with no plan-approval pause; this command is the interactive alternative that keeps the human review point). Project conventions apply to everything downstream: the plan's Conventions section, commits, and the PR handoff in `/dev:wrap`.

## Step 1: Build the queue

Fetch open issues assigned to the current user in this repo:

```bash
gh issue list --assignee @me --state open --search "-linked:pr" --json number,title,labels,updatedAt --limit 50
```

The `-linked:pr` qualifier excludes issues that already have a linked PR: an issue with an open PR is past this loop (its next step is review, not re-implementation, and re-running would mint a duplicate branch and PR). Linking only catches PRs connected via closing keywords or the Development sidebar, so also run a safety net per candidate and drop any with a hit:

```bash
gh pr list --state open --search "<n> in:title,body" --json number,url
```

- If `$ARGUMENTS` names issue numbers, verify each exists, is open, and passes both PR checks (an issue with an open PR is refused even when explicitly requested: report the PR URL instead). Warn if one is not assigned to the user but proceed.
- Otherwise present a compact numbered table (number, title, labels) of eligible issues and ask the user which to run and in what order. "All" is a valid answer. Note how many were filtered out for open PRs, with URLs. This is the only free-form question this command asks.
- Skip issues whose labels indicate they are not ready to implement (blocked, needs-triage, discussion) unless the user explicitly picks them, and say which were skipped and why.
- If nothing is assigned, say so and stop.

## Step 2: Run the loop per issue, sequentially

Process one issue at a time, in queue order. Do not interleave two issues; each gets its own plan, branch, worktree, and PR. For each issue:

### 2a. Check for existing state

Look in `~/.claude/plans/<repo-name>/` for a plan whose Source references this issue.

- Found with `Status: Approved` or partially executed boxes: resume with `/dev:execute` (it re-reads the plan and worktree location). Say you are resuming.
- Found with `Status: Draft`: go to the approval pause (2c) with the existing plan instead of re-planning.
- Found with `Status: Complete`: report it as already done (with the PR URL from the plan file) and move on.

### 2b. Plan

Run `/dev:plan <issue number>`. It grounds itself in the issue body and comments, writes the plan, and loops its checker until PASS.

If the issue is too underspecified to plan (the planner would be inventing requirements rather than decomposing them), do not fabricate a plan. Stop on this issue, summarize what is missing, recommend a design pass (`/dev:design`, or the project's own scoping command), and continue to the next issue in the queue.

### 2c. The pause: human plan review

This is the mandatory stop. Present:

- The plan file path and a summary: goal, wave and batch count, files touched, anything risky, open questions.
- The issue link.

Then wait. Acceptable outcomes: the user approves (set `Status: Approved` and continue), requests changes (revise the plan, re-run the checker, present again), or skips the issue (leave the plan as Draft, move to the next issue). Do not proceed past this point without an explicit approval; `/dev:execute` enforces it anyway.

### 2d. Execute and wrap, autonomously

On approval, run `/dev:execute <plan path>` then `/dev:wrap <plan path>` without further questions. The exceptions that stop this issue and surface to the user, per those commands' own rules: a BLOCKED status that invalidates a plan decision or changes scope, three failures on one task, or wrap verification that cannot be brought to PASS. When one of these stops an issue, record where it stopped (the plan file already holds the state), report it, and continue to the next issue in the queue rather than stalling the whole run.

### 2e. Per-issue report

One short block: issue, outcome (PR URL / blocked at <task> / skipped), and any deviations worth a human's eyes.

## Step 3: Queue summary

After the last issue, report the whole run in one table: issue, title, outcome, PR URL or blocker. List any Draft plans awaiting approval and any blocked issues with their resumption command (`/dev:execute <plan path>`), so nothing silently drops.
