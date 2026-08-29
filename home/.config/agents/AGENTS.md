# Agent Guidelines

## Response Shape

- Put the most important information last. That is the part I read first.
- State each fact once. Repeat only when a later turn depends on it.
- Match detail to the task. A one-line question gets a one-line answer.
- When presenting three or more findings, decisions, options, risks, questions, or actions, give each a short code: `F1`, `D1`, `O1`, `R1`, `Q1`, `A1`. Keep the same codes for the rest of the conversation so I can reply "drop R2, expand O3". Invent new prefixes for categories not listed. Skip codes entirely for short answers.

## Aliases

Expand these and act as if the expansion were written out in full. Treat a token as an alias only when it stands alone as the whole message or on its own line. Ignore it inside a sentence.

- `scr`: Simplify, compress, and repeat your last response.
- `eli`: Explain that like I'm 18. Simpler language, shorter response.
- `foc`: What is the true signal here? Boil it down to the single most important thing.
- `ref`: Rewrite your last response using reference codes.

## Git Commits

**Never include AI attribution signatures in commit messages.** This includes but is not limited to:

- `Generated with [Claude Code]` or similar tool attributions
- `Co-Authored-By: Claude` or any AI co-author lines
- Robot emojis or other AI indicators
- Any variation of "AI-generated" or "AI-assisted" messaging

Commit messages should be clean, professional, and focus solely on describing the changes made.
They should follow the patterns specified by Conventional Commits unless otherwise specified,
such as differences in contributor guidelines in repos.

## Writing

- Do not use em dashes (—) when writing. Use commas, parentheses, colons, or separate sentences instead.

## Using Python

When using python, always remember to run via the `uv` tool.

## Tests

- Do not write tests for files in examples/ or scripts/, only for files in packages.

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

**Fingerprints of stitched-together training data**:

- Inconsistent naming within a single scope: `userData` becomes `user_data` becomes `data`.
- Copy-paste Frankenstein: patterns spliced from across open-source into a whole that doesn't match the surrounding codebase's conventions.
- Hallucinated APIs and imports: calls to libraries that don't exist, subtly wrong signatures, methods invented on the spot. Looks authoritative; isn't.

**Comment and completeness smells**:

- Over-commenting: a comment on nearly every line explaining _what_ obvious code does rather than _why_.
- Placeholder logic left in: `// TODO: handle this case` inside otherwise complete-looking code.
- Empty classes, stub methods, and dead code: generated as part of a broader pattern, never populated or cleaned up.
- Logical bloat: redundant variables and unnecessary abstraction. Where human code errs by omission, AI code errs by commission.

The core risk: syntactically correct but logically flawed code creates a false sense of security. It runs, it reads well, and the subtle bug or invented API surfaces later. Review AI-generated code with the same rigor as any other code, arguably more.

## Self-Editing Checklist

**Writing**:

- Cut vocabulary from the spike list unless a plainer word won't do.
- Replace at least one abstract statement per section with a concrete detail (a number, a name, an example).
- Vary sentence and paragraph length on purpose. Read it aloud; listen for the metronome.
- Kill "it's not X, it's Y" and reflexive triads.
- Remove empty affirmations, hedges that dodge the point, and decorative bold/emoji.
- Make sure the conclusion adds something instead of restating the intro.

**Code**:

- Add the error handling and edge cases the happy path skipped; remove redundant guards.
- Verify every imported library and API call actually exists and has that signature.
- Make naming consistent within each scope; match the surrounding codebase's conventions.
- Delete comments that restate obvious code; keep the ones that explain _why_.
- Resolve every `TODO`, stub, and empty method before shipping.
- Check the code against real system constraints (data scale, traffic, config, existing structure).

The deeper point: these patterns are symptoms of output optimized to look correct rather than to be right. Editing out the surface tells without fixing that gap just makes generic work harder to spot. Aim for the concrete detail, the real edge case, and the specific claim.
