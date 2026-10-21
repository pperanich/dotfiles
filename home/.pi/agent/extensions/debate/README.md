# pi-debate-ledger

N persistent agent sessions that debate a question by exchanging typed claims.

Each seat is a long-lived `AgentSession` created once and prompted every round,
so it keeps its own reasoning history. Seats investigate independently with
`read`, `bash`, `grep`, `find`, and `ls`, and can address each other only
through the `emit_claim` tool. Nothing else they produce crosses between them.

From this directory, run `npm ci --ignore-scripts` before loading the extension.
Local extensions do not have their npm dependencies installed automatically.

## Why a tool and not a prompt convention

`emit_claim` is passed to each seat as its only channel to the group, so the
wire format is a validated schema rather than tagged prose the orchestrator has
to parse back out. A seat cannot broadcast a wall of reasoning even if it tries,
and a `challenge` without an `evidence` field is rejected with a reason the seat
reads as a tool result and can correct in-loop.

## Usage

    /debate Should the local cache use SQLite or Postgres?
    /debate models             pick the model and thinking level per seat
    /debate seats              choose active seats (Space toggles, Enter saves)
    /debate runs               list runs, unconcluded ones flagged
    /debate resume [run-id]    continue a run that never reached a verdict
    /debate archive <run-id>   set a run aside without deleting its claims

The host agent can also call the `debate` tool itself. Either way the ledger
comes back to the host agent, which writes the verdict in its own voice.
In `pi --print` (text or JSON), `/debate <question>` and `/debate resume <id>`
wait for that verdict before exiting. Interactive commands queue the ledger as
a follow-up if the host is already responding.

## Interjecting

Between rounds you get a three-way prompt: another round, conclude, or
interject. Interjecting records your text as an authoritative claim under the
seat id `you`, which routes it to every seat on their next turn. It bypasses the
redundancy filter and sorts ahead of everything else in their queue, including a
challenge aimed at them, because your constraint is the frame they argue inside
rather than one more opinion. You may restate a constraint as often as you like;
seats cannot restate their own points.

Dismissing the prompt concludes the debate. An abandoned dialog is not a vote to
keep spending turns.

At `maxRounds`, the debate concludes automatically. Interjections are offered
only when another round is available to deliver them.

Agent-initiated runs through the `debate` tool never pause, since the host agent
is mid-turn and a dialog would strand the tool call.

## Crash resume

The ledger is written to `<agentDir>/debate/runs/<run-id>.json` after every
round, before you are asked anything, so a crash costs at most the round in
progress. Writes are atomic (temp file plus rename): a crash during the write
leaves the previous round intact rather than a truncated file, because a
half-written ledger would be worse than no persistence.

A run whose status never reached `concluded` was interrupted. Provider failures
and cancellation leave the run resumable rather than counting as silence.
Starting a new debate warns about unconcluded runs in the same directory.
Each active run holds a file lock, including while waiting for human input.
Other processes cannot resume or archive it until the lock is released. A lock
left by a killed process expires after 30 seconds without a heartbeat.
Resume rereads the saved run under the lock and accepts only `running` runs.

`archive` flips the status and keeps the claims. Invalid run files, including
malformed fields or an ID that does not match the filename, are moved aside
without changing their bytes. Run ids include a UUID to avoid naming collisions.

Two things resume gets right that are easy to get wrong:

- **Seats lose their reasoning, not their positions.** Resuming builds fresh
  sessions, so a seat no longer remembers *why* it argued what it argued. Its
  own claims are replayed with its first turn, and it is told to
  re-verify anything it is asked to defend.
- **Delivery is recomputed, not trusted.** A seat that had already read a claim
  before the crash has genuinely not seen it in its new session, so each seat's
  seen-set is reset to its own claims and everything else is re-routed. The
  self-duplicate check stops that re-delivery from looping.

New runs save their selected seats in speaking order, resolved model and thinking
level, tools, and expanded persona/custom prompt. They also save the round limit,
timeout, and ledger settings. Resume uses that snapshot, even if the catalog,
selection, host model, or persona files have changed. The current provider and
credentials must still support the saved models. Pi's built-in system instructions
are supplied by the installed pi version.

Version 1 runs have no snapshot. They require the same selected seat IDs, use the
current settings in the original speaking order, and report that limitation. The
first resumed save upgrades them to version 2 with those settings captured.
Resume must also run from the original working directory so relative evidence
paths keep their meaning.

## Configuration

`debate.json` in the agent dir, or `.pi/debate.json` in the project:

    {
      "seats": [
        { "id": "proposer",   "persona": "proposer",   "model": "opencode/kimi-k3", "thinking": "high" },
        { "id": "skeptic",    "persona": "skeptic",    "model": "opencode/kimi-k3", "thinking": "high", "systemPrompt": "Check cost estimates against the implementation." },
        { "id": "pragmatist", "persona": "pragmatist", "model": "opencode/kimi-k2.6" }
      ],
      "activeSeats": ["proposer", "skeptic"],
      "maxRounds": 4,
      "redundancyThreshold": 0.82,
      "requireEvidenceOnChallenge": true
    }

`seats` is the catalog. `activeSeats` selects at least two distinct IDs in speaking
order; omit it to run every seat in catalog order. Inactive seats do not create
sessions or resolve their models/persona files. This selection also applies to
headless runs and the host's `debate` tool.

Naming `seats` replaces the catalog wholesale and clears an inherited selection
unless the same file also supplies `activeSeats`. Other settings merge from
defaults, then the agent file, then the project file.

Both `persona` and `systemPrompt` are optional. A persona names a file under
`personas/`; `systemPrompt` adds inline instructions after that persona. Without
either, the seat gets the shared debate instructions. Custom instructions do not
remove the topic, claim tool, or debate protocol. Omit `model` to use the session's
active model, and `thinking` to inherit its thinking level (medium if unavailable).
Seats use the host's provider implementations and current credentials, including
providers registered by extensions and API keys supplied for the session.
The seat id `you` is reserved for human interjections.

`/debate models` writes this file for you: it walks each seat, offers only the
models this agent dir can actually authenticate, and offers a thinking level
only for models that report `reasoning`. Dismissing any dialog leaves the whole
roster untouched rather than saving a half-configured one.
It updates the project file when that file defines `seats`, otherwise the agent
file. Changes apply to the next debate without a reload.

`/debate seats` opens a checkbox picker in TUI mode. Space toggles the highlighted
seat, Enter saves, and Escape cancels without writing. The existing speaking order
is retained; newly selected seats go last. At least two must remain selected.
It updates the project file when that file defines `seats` or `activeSeats`,
otherwise the agent file. In RPC or print mode, edit `activeSeats` directly.

## Round loop

Seats speak one at a time in roster order, each receiving the claims routed to
it since its last turn. One-by-one rather than simultaneous, following
ChatEval's finding that a seat reacting to what was just said produces better
turns than one answering a stale snapshot.

Routing applies two filters from S2-MAD:

- **Redundancy.** A claim close enough to something the seat already holds is
  dropped before delivery only when its kind, target, and evidence also match.
  Similarity is token-set Jaccard over content words;
  a change in negation words prevents filtering. This remains a lexical filter,
  not a semantic equivalence check.
- **Conditional participation.** A seat with nothing new routed to it is skipped
  without a model call. Silence is a legal outcome and is how the debate
  converges instead of padding. The loop stops early when every seat passes.

A claim targeting a seat is always delivered to it, redundant or not, so a
challenge is never filtered away from the participant who has to answer it.
Replies include any unseen target claims so a seat can read what they address.

## Personas

Defined by what a seat looks for, not by what conclusion it argues toward.
*Should we be going MAD?* found that a deliberately contrarian agent **reduced**
accuracy by contradicting correct first answers, so the skeptic persona is told
explicitly to stop when a proposal holds up rather than manufacture objections.

## Deliberately not included

- No live TUI panel. Progress goes through `ctx.ui.notify` and tool-result
  updates. A panel is where comparable extensions spend the most code and it is
  orthogonal to whether the debate works.
- No context engine. Claim routing keeps per-seat growth linear, so a
  long-context model has nothing to fit yet.
- No cost guardrails. Every seat runs a full session each round, so on a
  metered provider a debate costs roughly seats × rounds sessions.

## Tests

    npm test

26 tests over the ledger and the run store: evidence enforcement,
self-restatement rejection, delivery tracking, redundancy filtering, target
priority, open-challenge detection, atomic writes, corrupt-file handling,
version refusal, archive semantics, id-counter continuation across a restore,
resume re-routing, and interjection precedence.

## Known gaps

- `bash` is granted so seats can verify claims, which means a seat is not
  mechanically read-only. `edit` and `write` are withheld, so this is a
  guardrail rather than a sandbox. Run it on a clean tree.
- Resume replays a seat's claims but cannot restore its reasoning. A long debate
  resumed late will argue slightly differently than one that never crashed.
- Only the human interjects out of turn. Seats still speak strictly in roster
  order, so a seat cannot interrupt another mid-round.
