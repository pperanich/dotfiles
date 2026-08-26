---
description: Verify an executed /dev:plan end-to-end and hand off to the project's PR tooling
argument-hint: '<plan-file path>'
---

# Wrap Up

Plan file: $ARGUMENTS

Final phase of the dev loop: independent verification, then ship through the project's own gate and PR tooling.

## Step 1: Independent verification

Read the plan file (expect `Status: Executed`). Dispatch one verifier subagent (opus, set explicitly; never inherit the session model), fresh context, with the plan file path and this charge:

- Run the full validation suite from the plan's Conventions (lint, typecheck, tests), not just the per-task Validate commands.
- Run every check in the plan's Acceptance section.
- Read the Deviation log and confirm each deviation is reflected coherently in the final code (a deviation that half-landed is a bug).
- Return PASS, or findings with the failing command and output.

Findings go back through a fix subagent (implementer template from `/dev:execute`, finding as the task, committed the same way), then re-verify. The verifier must be a different context from any agent that wrote the code it is judging.

## Step 2: Ship through project tooling

Prefer the project's own pipeline, in its order:

- Aurora: `/aurora:push-safe` (or the `no-mistakes` skill if that is the configured gate), then `/aurora:pr`, which owns the PR body contract. Do not hand-write an Aurora PR body.
- Other projects: whatever gate and PR command their `.claude/` config defines.
- No project tooling: push the branch and open the PR with `gh pr create`. Body: 1-3 plain sentences on what was broken or missing and what this does about it, then a test-plan section built from the plan's Acceptance checks. Write it like a note to a teammate, with real specifics.

## Step 3: Close the loop

- Set `Status: Complete` in the plan file and add the PR URL under Source.
- If execution ran in a dedicated worktree, leave it in place until the PR merges (review fixes land there), then remove it with `git worktree remove` and delete the local branch. Offer to do the cleanup now if the PR is already merged.
- If the work is tracked on a GitHub issue, comment with the PR link.
- Surface anything from the Deviation log or Open questions that deserves a follow-up issue, and offer to file it.

Report the PR URL, what the verifier ran, and any follow-ups. If verification did not fully pass and you shipped anyway at the user's request, say exactly what is still failing.
