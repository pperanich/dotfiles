---
name: dev-execute
description: Implement or resume an approved development plan in the chosen checkout and verify the integrated change against the original request.
---

# Execute

Use the supplied plan or the one the user just approved. Match the source, repository, checkout and scope before resuming. “Yes, execute that plan here” approves the identified plan and selects the current checkout. Record approval on a saved draft. A checked box records progress. Approval applies to the plan the user saw, including later commits that implement it. Ask about a material change to that agreement or an ambiguous plan identity.

Inspect the branch, staged and unstaged changes, and any new files relevant to the task. On resumption, check completed items against the actual code and checks. An older plan may use Waves, Batch, Model and Produces fields. Preserve its task IDs and dependencies, and apply current user instructions to model, checkout, and commit choices.

**Choose the amount of coordination.** Implement a bounded change directly. Preserve unrelated edits, including work in a dirty checkout. For a larger plan, settle shared interfaces first, then delegate independent investigations or bounded implementation tasks. Give each child the task, checkout and base, owned files, prerequisites, acceptance check, and what to return. Use fresh contexts and available models suited to the work. A top-tier child requires an explicit request.

Use one writer per checkout. Serialize writers that need the same tree. Separate worktrees can support genuinely independent writers when permitted. Verify the starting state includes any prerequisite uncommitted changes, and integrate each result before claiming it. If delegation is unavailable, continue feasible work locally and identify any explicitly required independent check that remains outstanding.

**Execute and verify.** Run the task's check. Inspect the actual changes and exercise the normal entry point. Fix a stale path or other mechanical mismatch from repository evidence. Pause the affected task if resolving it would change an agreed outcome, compatibility promise, or scope. Keep independent work moving. Retry a failure when there is new evidence or a concrete fix.

Mark a task complete only after its changes are integrated and its check passes. In a saved plan, record meaningful deviations, evidence and remaining blockers. Make scoped commits when authorized, following the project's commit workflow. With commits deferred, review the relevant staged, unstaged and untracked files against the starting state. Keep user edits out of any commit.

For a risky change, material handoff or requested review, give a fresh reviewer the original request and decisions as well as the plan, integrated diff, new files and checks. Ask them to trace the user's scenario independently, report the observed result and flag any requirement the plan omitted. Fix substantiated findings, rerun affected checks and renew required review of changed behavior.

Run the plan's authorized acceptance checks. For a gate that also publishes, run its local checks separately when possible. Set a saved plan to `Status: Executed` once all tasks are integrated, acceptance passes and required review is satisfied. Otherwise record the outstanding work. For requested final verification or shipping, continue with `dev-wrap` (`/dev:wrap` in Claude Code).
