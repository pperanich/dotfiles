---
name: feature-loop
description: Implement a feature in Pi from a request or an approved plan. Use for a checked local change or a larger feature needing Pi subagents, independent review, or a resumable task ledger.
---

# Implement a feature in Pi

Use the supplied request, including its checkout, approval and shipping limits. With no new task, use the most recently agreed feature. Trace the affected entry point and identify the check that would demonstrate the requested outcome. A request for planning only ends with the plan.

**Bounded work.** When one change and one existing check cover the request, make the edit and run the check directly. For a CLI help correction, invoke the help entry point or its existing snapshot test. Preserve unrelated working-tree edits. An explicit request for a reviewer, ledger, or approval still applies.

**Work that needs coordination.** The lead owns the outcome and integration. Use a planner when dependencies, compatibility or ownership need investigation. Present consequential choices before implementing them. An explicit go-ahead for this scope or an already-approved plan is sufficient. For a resumable task, reuse a matching ledger. The existing location is `.agents/tasks/<feature-slug>/plan.md` in the target repo when the request permits a project file. Record the source, outcome, task IDs, accepted decisions, checks and unresolved work. Keep a short-lived plan in the conversation.

List available roles with `subagent({ action: "list" })`. If only `subagents_enable` is exposed, call it once and use `subagent` when it appears. While delegation is unavailable, continue work the lead can do. Identify any missing reviewer or other explicitly required role before claiming that part is done.

Give the planner the original request, agreed constraints and entry point. Give an implementer the brief or saved plan path, checkout and base, owned files, interfaces and exact check. If a role's configured model is unavailable, choose an available, permitted model suited to the role. Pass it as the top-level `model` argument and use `options: { context: "fresh" }` for an independent child. A top-tier child requires an explicit request. Use one writer per checkout. Integrate work from isolated checkouts and verify the resulting diff. A child can ask for a decision through `contact_supervisor`. Reply with `subagent_supervisor({ action: "reply", replyTo, message })` when that tool is available.

For an explicit review or a consequential change, send a fresh reviewer the original request and decisions, the integrated diff (including new files), and checks. Ask them to exercise the user's scenario and flag any promised outcome the plan missed. Resolve actionable `REQUEST_CHANGES` findings, rerun affected checks, and report missing evidence for `BLOCKED`. If the same failure recurs without a new lead, leave the task open and say what would unblock it. Reuse an equivalent review of the same candidate.

On resumption, compare ledger checkboxes and past evidence with the current checkout. Update the existing task IDs, Review and Verification entries. Set `Status: complete` when the outcome is verified and any required independent review is satisfied. Report the result, checks and outstanding decisions. Respect the user's scope for commits, pushes and PRs.
