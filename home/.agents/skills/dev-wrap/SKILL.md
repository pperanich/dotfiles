---
name: dev-wrap
description: Review or verify a completed development change against the original user goal, report remaining gaps, and handle a requested handoff or publication.
---

# Wrap

Verify the named change or the implemented work identified in the conversation. Match the plan, repository and checkout. An older saved plan normally reads `Status: Executed`. Reconcile missing or stale status with the actual change before updating the record.

Read the original request and agreed constraints. Reconstruct the user's scenario before reading the checklist. Exercise it through the normal entry point using input that would expose a plausible wrong result. Compare the actual output with what the user needs. A missing requirement in an approved plan is still a finding.

Inspect the integrated candidate, including staged, unstaged and new files when commits were deferred. Check the plan's acceptance conditions and behavior affected by deviations. Run the project's required local checks. Reuse recorded results that cover this exact candidate and environment. Rerun checks after relevant edits or where evidence is missing. Use an independent reviewer when requested or when an unreviewed high-impact change warrants one.

Lead with anything that blocks the user's outcome. For each finding, give a reproducible input or code location, expected and observed behavior, and the practical consequence. Identify any important behavior still unverified. If fixes are in scope, repair the defect and rerun affected checks. A verification-only request ends with the findings.

For a local handoff, report the behavior and checks and mark the saved plan `Status: Complete` when all required evidence is present. For requested publication, look up the branch's existing PR first. Use the project's authorized shipping workflow, reuse the existing PR when present, and record its URL. If publication is pending, retain the verified local result and record the remaining action. Post issue comments or remove worktrees and branches only within the user's authorization.
