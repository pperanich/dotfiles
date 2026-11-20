---
name: dev-plan
description: Plan a development request, issue, or agreed design before implementation. Ground acceptance checks in the user's workflow and prepare a saved handoff when needed.
---

# Plan

Plan the supplied request or most recently agreed task. A request for a plan ends with the plan. Read the original request or issue, relevant comments and decisions, project instructions, affected entry point and existing tests. Resolve paths from the checkout and label proposed files as new.

Start with a concrete before-and-after. At the point where the user or caller encounters the problem, what do they do, what happens today, and what must they see or be able to do afterward? Carry explicit constraints into that example. If two plausible interpretations would produce different behavior, use the source to settle it or surface the choice before committing to one.

**One bounded change.** Give the outcome, affected files, and the check that proves it in the conversation. A menu-label fix can be one line of work plus the existing menu test and expected label. A plan checker, saved file, or separate implementation team adds value only if the user requested it or there is something consequential to check.

**A handoff or dependent work.** Save a plan when requested, when work will resume in another session, or when multiple contributors need a common record. Use the requested location or project convention. For a permitted personal file use `~/.agents/plans/<repo-name>/<date>-<slug>.md`. Existing handoffs can also live under `~/.claude/plans/<repo-name>/`. Match the source and credential-free forge URL or shared Git directory before reusing a plan. Choose a distinct name if an unrelated plan occupies the path.

A saved plan needs enough context for a fresh implementer:

- Record `Status: Draft`, the source (full issue URL, design path, or conversation), repository, checkout and starting revision. Carry forward agreed scope, local-only requirements, and any commit or shipping instructions.
- Pair each promised outcome with the action, input and expected result that would prove it at the normal entry point. Where a plausible partial fix would pass existing checks, give one case that distinguishes it. Include a compatibility or failure case when it affects a promise. For each task, give a stable ID and checkbox, files, the change, and the check it supplies.
- Group tasks that share files or contracts. Use batches and waves only where dependencies affect execution. Identify a safe order or independent checkouts for concurrent writers. Record the relevant project commands and any open decision.

Before handoff, check dependencies and look for any part of the original request with no acceptance evidence. For a consequential design or coordination question, give a fresh read-only checker the original request and proposed plan. Ask whether a user outcome could still fail if every planned check passed. Correct supported gaps. If delegation is unavailable, cross-check locally and identify any explicitly required independent review still pending.

An explicit go-ahead for this plan is approval. Record `Status: Approved` on a saved plan when that happens. Keep a draft pending when the user requested review first. Local planning does not imply posting a copy to the issue.
