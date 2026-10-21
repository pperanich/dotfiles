/**
 * One seat: a persistent agent session that lives for the whole debate.
 *
 * The session is created once and prompted every round, so each seat keeps its
 * own reasoning history and remembers why it took the position it took. That is
 * the difference between a debate and a relay: nothing re-reads a transcript of
 * the whole discussion, each seat only receives the claims routed to it.
 */

import * as fs from "node:fs";
import * as path from "node:path";
import { InMemoryCredentialStore, clampThinkingLevel, type Api, type Model } from "@earendil-works/pi-ai";
import type { AgentSession, ExtensionContext, ModelRegistry } from "@earendil-works/pi-coding-agent";
import {
	DefaultResourceLoader,
	ModelRuntime,
	SessionManager,
	createAgentSession,
	getAgentDir,
} from "@earendil-works/pi-coding-agent";
import { createClaimTool } from "./claim-tool.ts";
import { DEFAULT_TOOLS, type SavedSeatConfig, type SeatConfig } from "./config.ts";
import type { Claim, ClaimKind, Ledger } from "./ledger.ts";

export class Seat {
	private session?: AgentSession;
	private round = 0;
	private resumePrimer = "";
	private readonly lifetime = new AbortController();

	constructor(
		readonly config: SavedSeatConfig,
		private readonly ledger: Ledger,
	) {}

	get id(): string {
		return this.config.id;
	}

	/**
	 * Build the session. Seats are hermetic on purpose: noExtensions keeps this
	 * extension from loading inside its own children, which would both register a
	 * second emit_claim and let a seat start a nested debate. noContextFiles and
	 * noSkills keep the seat's system prompt to its persona plus pi's default, so
	 * two seats differ only by persona and model.
	 */
	async start(ctx: ExtensionContext, priorClaims: readonly Claim[] = []): Promise<void> {
		const claimTool = createClaimTool(this.ledger, this.id, {
			currentRound: () => this.round,
		});

		const loader = new DefaultResourceLoader({
			cwd: ctx.cwd,
			agentDir: getAgentDir(),
			noExtensions: true,
			noSkills: true,
			noPromptTemplates: true,
			noContextFiles: true,
			appendSystemPrompt: [this.config.resolvedPrompt],
		});
		await loader.reload();

		const model = resolveModel(ctx, this.config.model);

		const { session } = await createAgentSession({
			cwd: ctx.cwd,
			model,
			modelRuntime: await inheritModelRuntime(ctx.modelRegistry, model, this.lifetime.signal),
			thinkingLevel: this.config.thinking,
			// The seat investigates for itself. emit_claim is additive to these, and
			// edit/write are absent so a participant cannot alter the code it is
			// arguing about. bash can still write, so this is a guardrail, not a sandbox.
			tools: [...new Set([...this.config.tools, claimTool.name])],
			customTools: [claimTool],
			resourceLoader: loader,
			sessionManager: SessionManager.inMemory(),
		});

		this.session = session;

		// Replay positions with the first bounded turn, without a separate model call.
		this.resumePrimer = priorClaims.length > 0 ? renderResumePrimer(priorClaims) : "";
	}

	/**
	 * Run one round. Returns the claims this seat emitted, which is empty when it
	 * had nothing non-redundant to add. Silence is a legal outcome and the main
	 * reason a debate converges instead of padding.
	 */
	async takeTurn(routed: readonly Claim[], round: number, timeoutMs: number, signal?: AbortSignal): Promise<Claim[]> {
		const session = this.session;
		if (!session) throw new Error(`debate: seat ${this.id} was not started`);
		signal?.throwIfAborted();

		this.round = round;
		const before = this.ledger.all.filter((c) => c.seat === this.id).length;

		// expandPromptTemplates is off because this text contains another agent's
		// words; a claim mentioning a slash command should not be expanded here.
		const prompt = [this.resumePrimer, renderTurnPrompt(routed, round)].filter(Boolean).join("\n\n");
		await withTimeout(
			session.prompt(prompt, { expandPromptTemplates: false }),
			timeoutMs,
			() => {
				this.lifetime.abort();
				return session.abort();
			},
			`seat ${this.id} exceeded ${Math.round(timeoutMs / 1000)}s in round ${round}`,
			signal,
		);
		signal?.throwIfAborted();
		const last = session.messages.findLast((message) => message.role === "assistant");
		if (last?.stopReason === "error" || last?.stopReason === "aborted") {
			throw new Error(`debate: seat ${this.id} failed in round ${round}: ${last.errorMessage || last.stopReason}`);
		}
		this.resumePrimer = "";

		return this.ledger.all.filter((c) => c.seat === this.id).slice(before);
	}

	dispose(): void {
		this.lifetime.abort();
		this.session?.dispose();
		this.session = undefined;
	}
}

export function resolveSeatConfig(config: SeatConfig, ctx: ExtensionContext, extensionDir: string, topic: string): SavedSeatConfig {
	const model = config.model ? resolveModel(ctx, config.model) : ctx.model;
	if (!model) throw new Error(`debate: no active model for seat "${config.id}"`);
	return {
		...config,
		model: `${model.provider}/${model.id}`,
		thinking: clampThinkingLevel(model, config.thinking ?? ctx.thinkingLevel ?? "medium") as SavedSeatConfig["thinking"],
		tools: [...(config.tools ?? DEFAULT_TOOLS)],
		resolvedPrompt: personaPrompt(config, extensionDir, topic),
	};
}

function personaPrompt(config: SeatConfig, extensionDir: string, topic: string): string {
	let persona = "";
	if (config.persona) {
		const file = path.join(extensionDir, "personas", `${config.persona}.md`);
		try {
			persona = fs.readFileSync(file, "utf8");
		} catch (err) {
			throw new Error(`debate: seat "${config.id}" persona not found at ${file}: ${(err as Error).message}`);
		}
	}
	return [
		persona.trim(),
		config.systemPrompt?.trim() ?? "",
		"",
		`## The question under debate`,
		"",
		topic,
		"",
		"## How this works",
		"",
		`You are "${config.id}", one of several participants. You cannot see the others' reasoning, ` +
			"only the claims routed to you. They cannot see yours. Investigate with your tools as much as " +
			"you need, then call emit_claim for each point you want them to have.",
		"",
		"Emit nothing if the claims you received add nothing you disagree with or can improve on. " +
			"Saying nothing is how this ends; restating a settled point is not.",
	].join("\n");
}

function resolveModel(ctx: ExtensionContext, id: string) {
	const slash = id.indexOf("/");
	if (slash <= 0 || slash === id.length - 1) {
		throw new Error(`debate: model "${id}" must be "provider/model"`);
	}
	const model = ctx.modelRegistry.find(id.slice(0, slash), id.slice(slash + 1));
	if (!model) {
		throw new Error(
			`debate: model "${id}" is not in this agent dir's models. ` +
				"Check models.json and the saved seat model.",
		);
	}
	return model;
}

async function inheritModelRuntime(registry: ModelRegistry, model: Model<Api>, signal: AbortSignal) {
	const provider = registry.getProvider(model.provider);
	if (!provider) throw new Error(`debate: unknown provider "${model.provider}"`);
	// Host providers and credentials may exist only in memory. Resolve auth from
	// the host on each request so refreshed tokens and session API keys stay current.
	const runtime = await ModelRuntime.create({
		modelsPath: null,
		credentials: new InMemoryCredentialStore(),
		refreshOnCreate: false,
	});
	runtime.registerNativeProvider({
		id: provider.id,
		name: provider.name,
		getModels: () => [model],
		stream: (model, context, options) => {
			signal.throwIfAborted();
			return provider.stream(model, context, options);
		},
		streamSimple: (model, context, options) => {
			signal.throwIfAborted();
			return provider.streamSimple(model, context, options);
		},
		auth: {
			apiKey: {
				name: provider.name,
				resolve: async () => {
					signal.throwIfAborted();
					const resolved = await registry.getApiKeyAndHeaders(model);
					signal.throwIfAborted();
					if (!resolved.ok) throw new Error(resolved.error);
					const { ok, env, ...auth } = resolved;
					return { auth, env };
				},
			},
		},
	});
	return runtime;
}

function renderResumePrimer(own: readonly Claim[]): string {
	const lines = [
		"This debate is resuming after an interruption. You made these claims before it stopped. " +
			"Treat them as your positions; you do not have the reasoning that led to them, so re-verify " +
			"anything you are asked to defend.",
		"",
	];
	for (const claim of own) lines.push(formatClaim(claim));
	lines.push("", "Do not re-emit these. Respond to the routed claims below.");
	return lines.join("\n");
}

function renderTurnPrompt(routed: readonly Claim[], round: number): string {
	if (round === 1 && routed.length === 0) {
		return "Round 1. Nobody has spoken yet. Investigate the question and emit your opening position.";
	}
	if (routed.length === 0) {
		return `Round ${round}. Nothing new was routed to you, so the others have not raised anything you have not already seen. Emit a claim only if you have a genuinely new point.`;
	}
	const lines = [`Round ${round}. Claims routed to you since your last turn:`, ""];
	for (const claim of routed) {
		lines.push(formatClaim(claim));
	}
	lines.push(
		"",
		"Verify what you can before responding. Challenge what the evidence does not support, concede what it does, " +
			"and add anything the others have missed.",
	);
	return lines.join("\n");
}

function formatClaim(claim: Claim): string {
	const head = `[${claim.id}] ${claim.kind} by ${claim.seat}` +
		(claim.target ? ` re ${claim.target}` : "") +
		` (confidence ${claim.confidence.toFixed(2)})`;
	const body = [`  ${claim.text}`];
	if (claim.evidence) body.push(`  evidence: ${claim.evidence}`);
	return [head, ...body].join("\n");
}

async function withTimeout(
	work: Promise<void>,
	ms: number,
	abort: () => Promise<void>,
	message: string,
	signal?: AbortSignal,
): Promise<void> {
	let timer: NodeJS.Timeout | undefined;
	let onAbort: (() => void) | undefined;
	const expiry = new Promise<never>((_resolve, reject) => {
		timer = setTimeout(() => reject(new Error(message)), ms);
		onAbort = () => reject(signal?.reason ?? new Error("debate: aborted"));
		signal?.addEventListener("abort", onAbort, { once: true });
	});
	try {
		await Promise.race([work, expiry]);
	} catch (err) {
		await abort().catch(() => {});
		throw err;
	} finally {
		if (timer) clearTimeout(timer);
		if (onAbort) signal?.removeEventListener("abort", onAbort);
	}
}

export type { ClaimKind };
