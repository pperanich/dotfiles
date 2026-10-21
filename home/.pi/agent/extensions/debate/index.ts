/**
 * pi-debate-ledger
 *
 * Holds N persistent agent sessions open and routes typed claims between them.
 * Each seat investigates the codebase with its own tools and can only address
 * the others through emit_claim, so what crosses between agents is a validated
 * claim rather than a transcript.
 *
 *   /debate <question>   convene a debate, pausing after each round for you
 *   /debate models       pick the model and thinking level for each seat
 *   /debate seats        choose which saved seats participate
 *   /debate runs         list runs, including crashed ones
 *   /debate resume [id]  continue a run that never reached a verdict
 *   /debate archive <id> abandon a run without deleting its claims
 *   debate tool          the host agent convenes it when a decision warrants it
 *
 * Either way the ledger comes back to the host agent, which writes the verdict.
 */

import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { getAgentDir } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";
import { type DebateConfig, activeSeats, loadConfig } from "./config.ts";
import { configureSeats, describeRoster, selectSeats } from "./models.ts";
import {
	type DebateResult,
	ResumeError,
	type RunOptions,
	renderForSynthesis,
	resumeDebate,
	runDebate,
} from "./orchestrator.ts";
import { RunStore, lastRound } from "./store.ts";

const EXTENSION_DIR = import.meta.dirname;

export default function (pi: ExtensionAPI) {
	// Guards against a second debate starting while one is mid-flight. Each seat
	// holds a live model connection, so two concurrent debates on a shared
	// provider is how you get rate-limited into a half-finished ledger.
	let inFlight = false;
	const shutdown = new AbortController();

	const options = (
		ctx: ExtensionContext,
		config: DebateConfig,
		interactive: boolean,
		signal = ctx.signal,
	): RunOptions => ({
		config,
		ctx,
		extensionDir: EXTENSION_DIR,
		report: (message) => ctx.ui.notify(message, "info"),
		store: new RunStore(getAgentDir()),
		interactive,
		signal: AbortSignal.any([shutdown.signal, ...(signal ? [signal] : [])]),
	});

	const command = {
		description: "Convene N agents to debate a question through a routed claim ledger",
		handler: async (args: string, ctx: ExtensionContext): Promise<DebateResult | undefined> => {
			const [verb, ...rest] = args.trim().split(/\s+/);
			const remainder = rest.join(" ");
			const store = new RunStore(getAgentDir());

			try {
				switch (verb) {
					case "":
						ctx.ui.notify(
							"Usage: /debate <question> | seats | models | runs | resume [id] | archive <id>",
							"warning",
						);
						return;

					case "seats":
						await selectSeats(ctx, loadConfig(ctx.cwd, getAgentDir()), getAgentDir());
						return;

					case "models": {
						const config = loadConfig(ctx.cwd, getAgentDir());
						if (!ctx.hasUI) {
							ctx.ui.notify("Model selection needs an interactive session.", "warning");
							return;
						}
						await configureSeats(ctx, config, getAgentDir());
						return;
					}

					case "runs": {
						const runs = store.list();
						if (runs.length === 0) {
							ctx.ui.notify("No debate runs yet.", "info");
							return;
						}
						const lines = runs.map((run) => {
							const marker = run.status === "running" ? "UNCONCLUDED" : run.status;
							return `  ${run.runId}  [${marker}]  ${run.claims.length} claims, ${lastRound(run)} round(s)  ${run.topic}`;
						});
						ctx.ui.notify(`Debate runs:\n${lines.join("\n")}`, "info");
						return;
					}

					case "archive": {
						if (inFlight) {
							ctx.ui.notify("Wait for the current debate to stop before archiving runs.", "warning");
							return;
						}
						if (!remainder) {
							ctx.ui.notify("Usage: /debate archive <run-id>", "warning");
							return;
						}
						const archived = await store.archive(remainder);
						ctx.ui.notify(
							"quarantinedPath" in archived
								? `Kept the corrupt run at ${archived.quarantinedPath}.`
								: `Archived ${archived.runId}. Its ${archived.claims.length} claims are kept.`,
							"info",
						);
						return;
					}

					case "resume": {
						if (inFlight) {
							ctx.ui.notify("A debate is already running.", "warning");
							return;
						}
						inFlight = true;
						try {
							const candidates = store.unconcluded(ctx.cwd);
							const target = remainder
								? store.read(remainder)
								: await chooseCandidate(ctx, candidates, store);
							if (!target) return;
							const config = target.config ?? loadConfig(ctx.cwd, getAgentDir());
							return await resumeDebate(target, options(ctx, config, ctx.hasUI));
						} finally {
							inFlight = false;
						}
					}

					default: {
						if (inFlight) {
							ctx.ui.notify("A debate is already running.", "warning");
							return;
						}
						const topic = args.trim();
						const config = loadConfig(ctx.cwd, getAgentDir());

						// Surface a crashed run before starting a new one, so a debate
						// that died is noticed rather than quietly superseded.
						const stale = store.unconcluded(ctx.cwd);
						if (stale.length > 0) {
							ctx.ui.notify(
								`${stale.length} unconcluded run(s) here. /debate resume to continue one, ` +
									`/debate archive <id> to set it aside.`,
								"warning",
							);
						}

						inFlight = true;
						try {
							ctx.ui.notify(
								`Convening ${activeSeats(config).length} seats on: ${topic}\n${describeRoster(config)}`,
								"info",
							);
							return await runDebate(topic, options(ctx, config, ctx.hasUI));
						} finally {
							inFlight = false;
						}
					}
				}
			} catch (err) {
				if (shutdown.signal.aborted) return;
				const message = err instanceof ResumeError ? err.message : `Debate failed: ${(err as Error).message}`;
				if (ctx.hasUI) ctx.ui.notify(message, "error");
				else console.error(message);
			}
		},
	};

	pi.on("session_start", (_event, ctx) => {
		if (ctx.mode === "print" || ctx.mode === "json") return;
		pi.registerCommand("debate", {
			...command,
			handler: async (args, ctx) => {
				const result = await command.handler(args, ctx);
				if (result) pi.sendUserMessage(renderForSynthesis(result), { deliverAs: "followUp" });
			},
		});
	});

	// sendUserMessage is fire-and-forget. Transform headless input instead so
	// pi's original prompt owns synthesis and print mode waits for its completion.
	pi.on("input", async (event, ctx) => {
		if ((ctx.mode !== "print" && ctx.mode !== "json") || event.source === "extension" ||
			!/^\/debate(?:\s|$)/.test(event.text)) return { action: "continue" };
		const result = await command.handler(event.text.slice("/debate".length).trim(), ctx);
		return result
			? { action: "transform", text: renderForSynthesis(result) }
			: { action: "handled" };
	});

	pi.registerTool({
		name: "debate",
		label: "Debate",
		description:
			"Put a question to several independent agents who investigate the codebase separately and exchange " +
			"typed claims. Returns their claim ledger for you to synthesize. Slow and expensive: use it for " +
			"decisions that are costly to reverse, not for routine work.",
		promptSnippet: "Convene independent agents to debate a hard decision and return their claim ledger",
		promptGuidelines: [
			"Use debate for architecture choices, migrations, and decisions where being wrong is expensive to undo.",
			"Do not use debate for routine edits, naming, or questions with one defensible answer.",
			"After debate returns, write the verdict yourself and cite the claim ids it gives you.",
		],
		parameters: Type.Object({
			question: Type.String({
				description:
					"The decision to debate, stated so it can be argued both ways. Include the constraints that matter.",
			}),
		}),
		async execute(_toolCallId, params, signal, onUpdate, ctx) {
			if (inFlight) {
				throw new Error("A debate is already running; only one at a time.");
			}

			inFlight = true;
			try {
				const config = loadConfig(ctx.cwd, getAgentDir());
				// Agent-initiated runs never pause for a human: the host agent is
				// mid-turn and blocking it on a dialog would strand the tool call.
				const result = await runDebate(params.question, {
					...options(ctx, config, false, signal),
					report: (message) => onUpdate?.({ content: [{ type: "text", text: message }], details: {} }),
				});
				return {
					content: [{ type: "text" as const, text: renderForSynthesis(result) }],
					details: {
						runId: result.runId,
						stoppedBecause: result.stoppedBecause,
						rounds: result.rounds,
						claims: result.ledger.all,
					},
				};
			} finally {
				inFlight = false;
			}
		},
	});

	pi.on("session_shutdown", async () => {
		// Seats are disposed in drive()'s finally block and the run file is left
		// marked "running", so an interrupted debate stays resumable.
		shutdown.abort(new Error("debate: session shut down"));
	});
}

async function chooseCandidate(
	ctx: ExtensionContext,
	candidates: Awaited<ReturnType<RunStore["unconcluded"]>>,
	store: RunStore,
) {
	if (candidates.length === 0) {
		ctx.ui.notify("No unconcluded runs for this directory.", "info");
		return undefined;
	}
	if (candidates.length === 1) return candidates[0];
	if (!ctx.hasUI) {
		ctx.ui.notify(
			`${candidates.length} unconcluded runs. Name one: ${candidates.map((r) => r.runId).join(", ")}`,
			"warning",
		);
		return undefined;
	}
	const choice = await ctx.ui.select(
		"Resume which run?",
		candidates.map((run) => `${run.runId} (${run.claims.length} claims) ${run.topic}`),
	);
	if (choice === undefined) return undefined;
	return store.read(choice.split(" ")[0] as string);
}

export { loadConfig } from "./config.ts";
export { HUMAN_SEAT, Ledger, similarity } from "./ledger.ts";
export { renderForSynthesis, resumeDebate, runDebate } from "./orchestrator.ts";
export { RunStore, lastRound } from "./store.ts";
