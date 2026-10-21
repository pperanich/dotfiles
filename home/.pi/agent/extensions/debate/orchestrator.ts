/**
 * The round loop.
 *
 * Seats speak one at a time in roster order, each seeing the claims routed to
 * it since its last turn. That ordering follows ChatEval's finding that
 * one-by-one beat simultaneous talk: a seat that can react to what was just
 * said produces better turns than one answering a stale snapshot.
 *
 * The ledger is persisted after every round, before the human is asked
 * anything, so a crash costs at most the round in progress.
 *
 * Synthesis is deliberately not done here. The ledger goes back to the host
 * agent, which writes the verdict in its own voice with the full claim
 * structure in front of it.
 */

import type { ExtensionContext } from "@earendil-works/pi-coding-agent";
import { activeSeats, type DebateConfig, type SavedDebateConfig } from "./config.ts";
import { HUMAN_SEAT, Ledger } from "./ledger.ts";
import { Seat, resolveSeatConfig } from "./seat.ts";
import { RUN_FILE_VERSION, type RunFile, RunStore, lastRound } from "./store.ts";

export type StopReason = "silence" | "max-rounds" | "concluded-by-user";

export interface RoundSummary {
	round: number;
	/** Seats skipped because nothing non-redundant was routed to them. */
	silent: string[];
	claimIds: string[];
}

export interface DebateResult {
	runId: string;
	topic: string;
	rounds: RoundSummary[];
	stoppedBecause: StopReason;
	ledger: Ledger;
}

export interface ProgressSink {
	(message: string): void;
}

export interface RunOptions {
	config: DebateConfig;
	ctx: ExtensionContext;
	extensionDir: string;
	report: ProgressSink;
	store: RunStore;
	/** Pause between rounds to let the human steer. Requires ctx.hasUI. */
	interactive: boolean;
	signal?: AbortSignal;
}

/** Thrown when a persisted run cannot be resumed safely. */
export class ResumeError extends Error {}

export async function runDebate(topic: string, options: RunOptions): Promise<DebateResult> {
	const ledger = new Ledger(topic, ledgerOptions(options.config));
	const runId = RunStore.runId(topic);
	const config = saveConfig(topic, options);
	return options.store.withLock(runId, (ownership) => drive(
		{ topic, runId, ledger, config, rounds: [], startRound: 1, createdAt: Date.now() },
		options,
		ownership,
	));
}

export async function resumeDebate(run: RunFile, options: RunOptions): Promise<DebateResult> {
	return options.store.withLock(run.runId, (ownership) => {
		// A picker or another process may have changed the file since it was listed.
		run = options.store.read(run.runId);
		if (run.status !== "running") throw new ResumeError(`run "${run.runId}" is ${run.status}, not resumable`);
		return resumeLocked(run, options, ownership);
	});
}

function resumeLocked(run: RunFile, options: RunOptions, ownership: AbortSignal): Promise<DebateResult> {
	let config = run.config;
	if (run.cwd !== options.ctx.cwd) {
		throw new ResumeError(`run "${run.runId}" belongs to ${run.cwd}. Resume it from that directory.`);
	}

	if (!config) {
		const current = activeSeats(options.config).map((seat) => seat.id).sort();
		const original = [...run.seats].sort();
		if (current.join(",") !== original.join(",")) {
			throw new ResumeError(
				`run "${run.runId}" was held with seats [${original.join(", ")}] but the roster is now ` +
					`[${current.join(", ")}]. Restore the roster to resume, or archive the run.`,
			);
		}
		options.report("Legacy run has no saved seat settings; using current settings in the original seat order.");
		config = saveConfig(run.topic, { ...options, config: { ...options.config, activeSeats: run.seats } });
	}

	const ledger = Ledger.restore(run.topic, { claims: run.claims, delivered: run.delivered }, ledgerOptions(config));
	ledger.resetDeliveryForResume();

	const resumeFrom = lastRound(run) + 1;
	options.report(
		`resuming ${run.runId} from round ${resumeFrom} with ${run.claims.length} claim(s) on the record`,
	);
	return drive(
		{
			topic: run.topic,
			runId: run.runId,
			ledger,
			config,
			rounds: run.rounds,
			startRound: resumeFrom,
			createdAt: run.createdAt,
		},
		options,
		ownership,
	);
}

interface DriveState {
	topic: string;
	runId: string;
	ledger: Ledger;
	config: SavedDebateConfig;
	rounds: RoundSummary[];
	startRound: number;
	createdAt: number;
}

async function drive(state: DriveState, options: RunOptions, ownership: AbortSignal): Promise<DebateResult> {
	const { ctx, report, store, interactive } = options;
	const cancellation = options.signal ?? ctx.signal;
	const signal = AbortSignal.any([ownership, ...(cancellation ? [cancellation] : [])]);
	const { topic, runId, ledger, config } = state;
	const rounds = [...state.rounds];

	const seats = config.seats.map((seat) => new Seat(seat, ledger));
	let stoppedBecause: StopReason = "max-rounds";
	let forceRound = true;

	const persist = (status: RunFile["status"], stopped?: StopReason) => {
		// Cancellation still saves progress; losing ownership must never write.
		ownership.throwIfAborted();
		const snapshot = ledger.snapshot();
		store.write({
			version: RUN_FILE_VERSION,
			runId,
			topic,
			cwd: ctx.cwd,
			status,
			createdAt: state.createdAt,
			updatedAt: Date.now(),
			seats: config.seats.map((s) => s.id),
			config,
			rounds,
			stoppedBecause: stopped,
			claims: snapshot.claims,
			delivered: snapshot.delivered,
		});
	};

	try {
		signal?.throwIfAborted();
		persist("running");
		for (const seat of seats) {
			await seat.start(ctx, ledger.claimsBySeat(seat.id));
			signal?.throwIfAborted();
		}
		report(`${seats.length} seats seated: ${seats.map((s) => s.id).join(", ")}`);

		for (let round = state.startRound; round <= config.maxRounds; round++) {
			const summary: RoundSummary = { round, silent: [], claimIds: [] };

			for (const seat of seats) {
				signal?.throwIfAborted();

				const routed = ledger.route(seat.id);

				// Conditional participation, after S2-MAD: a seat with nothing new
				// routed to it is skipped without a model call at all. This is what
				// keeps later rounds cheap and stops seats restating settled points.
				if (!forceRound && routed.length === 0) {
					summary.silent.push(seat.id);
					continue;
				}

				const emitted = await seat.takeTurn(routed, round, config.seatTurnTimeoutMs, signal);
				ledger.markDelivered(seat.id, routed);

				if (emitted.length === 0) {
					summary.silent.push(seat.id);
					report(`round ${round}: ${seat.id} passed`);
				} else {
					summary.claimIds.push(...emitted.map((c) => c.id));
					report(`round ${round}: ${seat.id} emitted ${emitted.map((c) => `${c.id}/${c.kind}`).join(", ")}`);
				}
			}

			rounds.push(summary);
			forceRound = false;
			// Written before the human is asked anything: a crash while they are
			// deciding must not cost the round that just finished.
			persist("running");

			const settled = summary.claimIds.length === 0;

			if (interactive && ctx.hasUI && round < config.maxRounds) {
				const decision = await askHuman(ctx, ledger, round, settled, signal);
				signal?.throwIfAborted();
				if (decision === "conclude") {
					stoppedBecause = "concluded-by-user";
					break;
				}
				if (decision === "interjected") {
					report(`round ${round}: your interjection was recorded and goes to every seat next round`);
					persist("running");
					continue;
				}
				// An explicit request for another round gives even silent seats a turn.
				forceRound = true;
				continue;
			}

			if (settled) {
				stoppedBecause = "silence";
				report(`round ${round}: every seat passed, debate is settled`);
				break;
			}
		}

		signal?.throwIfAborted();
		persist("concluded", stoppedBecause);
	} catch (err) {
		// Leave the run marked "running" so it shows up as a resume candidate.
		// Overwriting it with an error state would discard the round that did land.
		persist("running");
		throw err;
	} finally {
		// Sessions hold model connections, so they are disposed even when a seat
		// throws partway through a round. The ledger survives for the synthesis.
		for (const seat of seats) seat.dispose();
	}

	return { runId, topic, rounds, stoppedBecause, ledger };
}

function saveConfig(topic: string, options: RunOptions): SavedDebateConfig {
	const { activeSeats: _selected, ...config } = options.config;
	return {
		...config,
		seats: activeSeats(options.config).map((seat) => resolveSeatConfig(seat, options.ctx, options.extensionDir, topic)),
	};
}

type Decision = "continue" | "conclude" | "interjected";

/**
 * The three-way pause. Interjecting is the buried option, so it is named in the
 * prompt body rather than left to be discovered.
 */
async function askHuman(
	ctx: ExtensionContext,
	ledger: Ledger,
	round: number,
	settled: boolean,
	signal?: AbortSignal,
): Promise<Decision> {
	const open = ledger.openChallenges().length;
	const title =
		`Round ${round} done. ${ledger.all.length} claim(s), ${open} unanswered challenge(s).` +
		(settled ? " Every seat passed." : "");

	const CONTINUE = "Another round";
	const CONCLUDE = "Conclude and write the verdict";
	const INTERJECT = "Interject: add a constraint or question of your own";

	const choice = await ctx.ui.select(
		title,
		[settled ? CONCLUDE : CONTINUE, settled ? CONTINUE : CONCLUDE, INTERJECT],
		{ signal },
	);
	signal?.throwIfAborted();

	// A dismissed dialog is not a vote to keep spending turns.
	if (choice === undefined || choice === CONCLUDE) return "conclude";
	if (choice === CONTINUE) return "continue";

	const text = await ctx.ui.input("Your point", "Goes to every seat as an authoritative claim", { signal });
	signal?.throwIfAborted();
	if (!text?.trim()) return "continue";

	const result = ledger.add({
		seat: HUMAN_SEAT,
		round,
		kind: "assert",
		text: text.trim(),
		// Your steer is not one opinion among several; it is the frame the seats
		// now argue inside.
		confidence: 1,
		authoritative: true,
	});
	if (!result.ok) {
		ctx.ui.notify(`Interjection not recorded: ${result.rejected.reason}`, "warning");
		return "continue";
	}
	return "interjected";
}

function ledgerOptions(config: DebateConfig) {
	return {
		redundancyThreshold: config.redundancyThreshold,
		requireEvidenceOnChallenge: config.requireEvidenceOnChallenge,
	};
}

/** The ledger as the host agent should read it: claim structure, not a transcript. */
export function renderForSynthesis(result: DebateResult): string {
	const { ledger } = result;
	const lines = [
		`# Debate ledger: ${result.topic}`,
		"",
		`${ledger.all.length} claims across ${result.rounds.length} round(s). Stopped because: ${result.stoppedBecause}.`,
		`Run id: ${result.runId}`,
		"",
	];

	for (const seat of [...new Set(ledger.all.map((c) => c.seat))]) {
		const claims = ledger.claimsBySeat(seat);
		lines.push(seat === HUMAN_SEAT ? `## ${seat} (your interjections)` : `## ${seat}`, "");
		for (const claim of claims) {
			lines.push(
				`- **${claim.id}** (${claim.kind}${claim.target ? ` re ${claim.target}` : ""}, confidence ${claim.confidence.toFixed(2)}): ${claim.text}`,
			);
			if (claim.evidence) lines.push(`  - evidence: ${claim.evidence}`);
		}
		lines.push("");
	}

	const open = ledger.openChallenges();
	if (open.length > 0) {
		lines.push("## Unanswered challenges", "");
		for (const claim of open) {
			lines.push(`- **${claim.id}** against ${claim.target}: ${claim.text}`);
		}
		lines.push("");
	}

	lines.push(
		"## Your task",
		"",
		"Write the verdict. Say what the participants agreed on, where they genuinely split and on what evidence, " +
			"and what you recommend. Do not average a real disagreement into a middle position: if a challenge went " +
			"unanswered, say so and let it count against the claim it targeted. Cite claim ids. " +
			`Any claim from "${HUMAN_SEAT}" is a constraint from the user, not one opinion among several.`,
	);
	return lines.join("\n");
}
