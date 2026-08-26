---
description: Structured design conversation that produces a decision record for /dev:plan
argument-hint: '<topic or problem statement>'
---

# Design Conversation

Topic: $ARGUMENTS

You are running the design phase of the dev loop (design -> plan -> execute -> wrap). The output is a decision record, not code and not a task list. Do NOT write implementation code in this phase.

## Project tooling first

Before anything else, skim the project's agent config: root `CLAUDE.md`, `.claude/commands/`, `.claude/skills/`. If the project has its own design or spec workflow that the user is already invested in (in Aurora: `/aurora:define-issue` and `/aurora:scope-issue`, or the agent-os spec commands), say so and ask whether to use that instead. Otherwise proceed here, but apply the project's conventions to everything you produce.

## How to run the conversation

Work like Socratic brainstorming, one question at a time:

1. Restate the problem in your own words and get confirmation you have it right.
2. Read the relevant code before asking questions the codebase can answer. Ask the user only what the code cannot tell you: intent, priorities, constraints, appetite.
3. Ask ONE question per turn. Prefer questions that eliminate whole branches of the design space.
4. When an approach decision comes up, present 2-3 options with concrete tradeoffs and a recommendation. Let the user pick or push back.
5. Keep going until the remaining unknowns are implementation details a planner could resolve alone.

## Output: the decision record

When the design has converged, write it to `~/.claude/plans/<repo-name>/<YYYY-MM-DD>-<slug>-design.md`, where `<repo-name>` is the basename of `git rev-parse --show-toplevel` (create the directory if needed). Loop artifacts never live inside the repo: no decision records, plan files, or notes from this process should ever show up in `git status`. Truly temporary scratch files belong in the session scratchpad directory. Structure:

```markdown
# Design: <title>

Date: <date>
Status: Agreed

## Problem
What is broken or missing, who is affected, and the concrete symptom.

## Decisions
One entry per decision made in the conversation:
- **<decision>** because <rationale>. Rejected: <alternative> (<why>).

## Constraints
Hard requirements the plan must respect (compatibility, performance, conventions, scope limits).

## Out of scope
What we explicitly decided not to do, so the planner does not reinvent it.

## Open questions
Anything unresolved, with who or what resolves it.
```

The rationale lines matter most: the plan and the executors will read this file with no memory of the conversation, so every decision must carry its why.

Finish by telling the user the file path and that the next step is `/dev:plan <path-to-design-doc>`.
