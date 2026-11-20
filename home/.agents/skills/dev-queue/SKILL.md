---
name: dev-queue
description: Triage a queue of GitHub issues, match each to existing work, and run the development phases requested for each issue.
---

# Issue queue

Resolve the requested issue numbers, URLs or selection in the named repository. Respect the requested phases, including planning only or local execution. Read the applicable project instructions and use the project's issue tooling when available.

## Select work

For explicit numbers or URLs, inspect those issues directly. With no selection, list open issues assigned to the current user and ask which to handle and in what order. Page through the full result when the user selects all. Exclude blocked, triage, or discussion items from the default selection. Explain those labels or an assignee mismatch when an issue is explicitly selected. Skip closed issues and explain why.

Check for existing work per candidate. On GitHub, `gh issue view <issue-url> --json url,state,assignees,labels,closedByPullRequestsReferences` returns linked PR URLs. Inspect a candidate with `gh pr view <pr-url> --json url,state,closingIssuesReferences` to check its state and relationships. For a text-search hit, verify that the PR actually implements the same repository's issue. A bare number such as “42 rows” is insufficient. A merged or closed PR is history. An open PR for this issue is work to surface or resume on request. If the relevant relationship cannot be checked, report the uncertainty before starting duplicate work.

## Resume at the right phase

Use the shared phase names below. Claude Code exposes them as `/dev:plan`, `/dev:execute` and `/dev:wrap`.

Match the full issue URL and repository identity at the supplied path or in the project's plan location. For personal handoffs, check `~/.agents/plans/<repo-name>/` and the older `~/.claude/plans/<repo-name>/`. For legacy plans, use Source and the recorded checkout or Git remote to disambiguate forks. Before resuming, verify the branch or worktree still contains the claimed changes.

| Existing state                         | Next action                                                                                                                                                              |
| -------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| No matching plan                       | Use `dev-plan` for the issue. Save it for queue resumption when permitted. If the goal cannot be grounded, record the missing decision and continue with the next issue. |
| Draft                                  | Surface the current plan. Record approval when the user has approved this identifiable version. Partial checkboxes alone do not grant approval.                          |
| Approved, including partially executed | Reconcile checked tasks with the working tree, then use `dev-execute` for the remaining authorized work.                                                                 |
| Executed                               | Use `dev-wrap` for final verification or the outstanding authorized handoff.                                                                                             |
| Complete                               | Report the recorded local outcome or PR. Reopen only when there is evidence of outstanding work in scope.                                                                |

For a planning-only run, return each plan or its current state and stop there. For execution, retain the per-issue plan approval point and honor an approval already supplied for that plan. Carry checkout, commit and publishing limits into execute and wrap. Process issues in the requested order. Record a skipped or blocked issue with the reason and how to resume, then continue the independent items. Finish with one outcome per issue.
