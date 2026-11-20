---
name: dev-design
description: Resolve a product or architecture decision before implementation when user needs, compatibility, or tradeoffs could change the approach.
---

# Design

Use the supplied problem, issue, or open design question. Identify who is trying to do what, what gets in their way today, and what a successful outcome would let them do. Cite a concrete example from the request or project. Mark an inferred need as an assumption.

Read the relevant project instructions and trace the behavior involved. Carry forward the user's latest constraints and decisions. Use the project's design workflow when it already addresses this question. Ask the user for information the project cannot supply, such as who needs the outcome or which compatibility promise matters.

Start with the decision that could change the design. For example, whether old clients must read newly saved files changes the persistence format. Choosing a helper name can wait for implementation. When there is a real choice, describe the viable alternatives, what each costs the user, and your recommendation. If the evidence already settles it, state the rationale and move on.

Return the decision and its rationale, a scenario that would demonstrate success, and any unresolved choice that would change the work. Distinguish a recommendation from an agreement. A brief decision can stay in the conversation. For a saved handoff, use the requested location or the project's convention. For a permitted personal file use `~/.agents/plans/<repo-name>/<date>-<slug>-design.md`. Record the source and repository identity. When planning is requested, pass the decision to `dev-plan` (`/dev:plan` in Claude Code).
