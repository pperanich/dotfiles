---
name: ai-tells
description: Catalog of the patterns that mark generic AI prose and code. Use for a last pass over a document, README, PR description or large diff before handing it over, or when asked why text or code reads as machine written.
---

# AI tells

The always-on rules live in the global AGENTS.md under "Writing and code". This is the longer catalog behind them. Read the draft against it and fix what clusters.

The "linter's dream surface" entry describes how generated code looks. It is not a goal: never add formatting drift, and let the repository's formatter decide.

## Writing Tells to Avoid

Heuristics for spotting generic, hollow AI output. A single tell means nothing; what flags AI output is the _density_ and _clustering_ of these patterns. Treat as a self-editing guide, not a detection algorithm.

**Vocabulary that spikes in AI text** (ask whether a plainer word does the job): `delve`, `underscore`, `pivotal`, `realm`, `tapestry`, `boast`, `showcase`, `harness`, `leverage`, `foster`, `navigate` (metaphorically), `intricate`, `multifaceted`, `meticulous`, `commendable`, `paramount`, `nuanced`, `robust`, `seamless`, `testament`, `landscape` (metaphorically), `beacon`.

**Stock phrases**: "it's important to note," "it's worth noting," "in today's fast-paced world," "when it comes to," "plays a crucial role," "a rich tapestry of," "stands as a testament to," "left an indelible mark," "a stark reminder," "navigate the complexities of."

**Abstraction trap**: AI reaches for the conceptual word over the concrete one. Name specifics (the brand, the number, the exact error message). Prose that never touches a concrete detail is a tell.

**Structural tics**:

- Negative parallelism: "It's not just X, it's Y." Sounds like insight, usually delivers none.
- Rule of three on autopilot: triads whether or not the content calls for three. Human writers vary.
- Rigid paragraph shape: every paragraph the same length and structure, like bricks. Real writing has ragged edges.
- Frictionless transitions: "Furthermore," "Moreover," "Additionally," "In conclusion." Human writing jumps and doubles back.
- The summary that summarizes nothing new: a closing paragraph restating the opening.

**Tone and rhythm**:

- Uniform, metronome-like sentence rhythm. Human prose has burst and lull: a short punch after a long winding sentence.
- Compulsive hedging: every claim softened, every position given its counterpoint, so nothing is actually said.
- Sycophancy and filler warmth: "Great question!" "That's a fascinating topic." Empty affirmations.
- Over-formatting: bold across half the sentences, emoji in headers, bullets where a sentence would do.

## Code Tells to Avoid

AI code is usually syntactically perfect. The tells live in structure, judgment, and how the code relates to the real project around it.

**Linter's dream surface**: flawless, hyper-consistent formatting with none of the minor drift a human leaves behind. Textbook-perfect boilerplate that ticks every box yet feels generic, like it came straight from documentation.

**Judgment gaps**:

- Happy-path bias: a beautiful function that "forgets" the null checks, input sanitization, and edge cases a working developer adds by reflex.
- Redundant over-defense (the opposite failure): the same guard repeated needlessly where it can't fail. Signals the model isn't confident about the control flow.
- No awareness of the real system: correct in isolation but ignores that the table has 50 million rows, or that the endpoint gets hit thousands of times a second.
- Copying the weeds: reusing the nearest pattern in the codebase without checking that it isn't deprecated, a workaround, or something a linter or type already forbids elsewhere. When the nearest example is an anti-pattern, follow the sanctioned pattern and mention the bad one in one line. Do not clean it up unless asked.

**Fingerprints of stitched-together training data**:

- Inconsistent naming within a single scope: `userData` becomes `user_data` becomes `data`.
- Copy-paste Frankenstein: patterns spliced from across open-source into a whole that doesn't match the surrounding codebase's conventions.
- Hallucinated APIs and imports: calls to libraries that don't exist, subtly wrong signatures, methods invented on the spot. Looks authoritative; isn't.

**Comment and completeness smells**:

- Over-commenting: a comment on nearly every line explaining _what_ obvious code does rather than _why_.
- Placeholder logic left in: `// TODO: handle this case` inside otherwise complete-looking code.
- Empty classes, stub methods, and dead code: generated as part of a broader pattern, never populated or cleaned up.
- Logical bloat: redundant variables and unnecessary abstraction. Where human code errs by omission, AI code errs by commission.
- Justification comments: a comment explaining why a workaround is acceptable (a timer, a sleep, a retry loop, a broad catch, a cast, a `# type: ignore`, an `eslint-disable`). It excuses the patch, nothing enforces it, and the next agent copies the patch as the pattern. Fix the root cause, or stop and tell me what's in the way. A suppression directive needs the specific reason on the same line and my OK in the session.

The core risk: syntactically correct but logically flawed code creates a false sense of security. It runs, it reads well, and the subtle bug or invented API surfaces later. Review AI-generated code with the same rigor as any other code, arguably more.
