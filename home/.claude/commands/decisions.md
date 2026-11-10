---
description: Surface every open decision that needs my input as a structured question, each with your recommendation
argument-hint: "[scope, defaults to the work in progress]"
---

Stop and take stock. Your job now is to find the decisions that are genuinely
mine to make, and ask them properly instead of burying them in prose.

## Scope

<scope>
${@:-The work in progress in this session.}
</scope>

Repository instructions and my earlier explicit instructions override anything
this prompt assumes. Read them before deciding what is still open.

## Sort the open questions

Read back over the current work and list every open question. Put each one in
exactly one bucket:

- **Settled.** Answered already by an earlier instruction from me, by repository
  evidence, or by a rule in the repo's AGENTS.md. Do not ask about these.
- **Yours.** Resolvable from the code, docs, tests, or config. Resolve it, record
  the decision and the evidence behind it, and do not ask.
- **Mine.** Needs my judgement: a product or priority call, a cost or risk
  trade-off, an irreversible or outward-facing action, or a choice where the
  evidence is genuinely balanced.

Only the third bucket becomes questions.

## Ask them

Call the ask tool (`ask_user_question` in pi, `AskUserQuestion` in Claude Code)
once per group of up to four decisions, ordered by how much each one blocks the
work.

For each decision:

- Say what is being decided and what depends on it, in one or two sentences.
  Never ask about a bare code or a bare plan reference; spell out what it means
  in the question itself.
- Offer two to four concrete options. Put the one you recommend first and label
  it "(Recommended)".
- In the recommended option's description, give the reason in one line and what
  it costs.
- Say what changes if I pick a different option, where that is not obvious.
- If the decision can safely wait, include a defer option and say what you will
  do in the meantime.

Do not ask:

- whether to proceed with work I already asked for
- for permission I have already granted
- about anything the repository, the tests, or my earlier instructions settle
- more than four questions in one call

If there are more than eight decisions, say how many there are and ask whether
to take them in batches before you start.

If the ask tool is unavailable in this harness, print the same questions as a
numbered list with the recommendation marked, and stop until I answer.

## Afterwards

Apply the answers. Restate each decision in one line so the record is readable
later, then carry on with the work.

If nothing needs my input, say so in one line, name the next action you will
take, and take it.
