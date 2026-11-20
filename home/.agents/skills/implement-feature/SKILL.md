---
name: implement-feature
description: Implement an agreed feature in an existing codebase from a request, spec, or conversation. Integrate the change and verify the user-visible result.
argument-hint: "[feature, spec path, or agreed plan]"
disable-model-invocation: true
---

# Implement a feature

Read any named spec. Claude Code fills in the request block below. In Pi, use the request appended after these instructions. In Codex, use the user message that invoked `$implement-feature`.

<feature_request>
$ARGUMENTS
</feature_request>

With no argument, recover the most recently agreed actionable feature from the conversation. Carry forward earlier constraints and corrections. If several candidates remain and the choice would change the work, ask which one the user means. A request confined to planning or review ends at that deliverable.

**Start at the entry point.** Read the applicable `AGENTS.md` or `CLAUDE.md` at the repository root and in the directories you will touch. Inspect the current branch and diff. Follow the affected path to the code that owns the behavior and the closest existing check. Identify the outcome a user or caller can observe. For a bounded change, implement it in the chosen checkout and run that check. An unrelated staged or unstaged edit can stay where it is.

**Coordinate when the work splits.** For a change spanning independent components, settle the shared contract and relevant compatibility requirements before dispatch. Use Claude Code's `Agent` tool, Pi's `subagent` tool, or Codex's native subagents. In Pi, use the `planner`, `implementer` and `reviewer` roles for their matching tasks when available.

Give each worker a fresh brief with its outcome, checkout and base, owned files, dependencies, and a concrete check. Use available models appropriate to the role, with a top-tier child only on explicit request. Keep one writer per checkout. Use separate permitted worktrees for concurrent writers and verify their starting state includes the changes they need. If delegation is unavailable, proceed with the feasible work and identify any explicitly required independent review still outstanding.

**Accept the integrated result.** Inspect changes and new files in the target checkout. Exercise the original scenario and relevant failure or compatibility cases. For example, when a setting must persist, read it back through a new session. A passing setter test alone leaves that requirement open. For a substantial or risky change, or an explicit review request, give an independent reviewer the original request, decisions and actual candidate, including uncommitted changes. Ask them to compare the observed outcome with that request and flag any promise the plan or tests omitted. Fix supported findings, rerun affected checks and reuse evidence that still applies.

Report what now works, the checks run, and any remaining gap or consequential assumption. Keep commits, publishing and deployment within the user's instructions.
