/**
 * Roster and run configuration.
 *
 * Seats are the configurable agent count: add or remove entries and the
 * orchestrator adapts. Seats inherit the active model unless overridden.
 */

import * as fs from "node:fs";
import * as path from "node:path";
import { HUMAN_SEAT } from "./ledger.ts";

export interface SeatConfig {
	/** Stable id used in the ledger and in routing. Lowercase, no spaces. */
	id: string;
	/** Persona file under personas/, without the .md suffix. */
	persona?: string;
	/** Additional role instructions, after the optional persona. */
	systemPrompt?: string;
	/** provider/model id. Falls back to the session's active model when unset. */
	model?: string;
	thinking?: "off" | "minimal" | "low" | "medium" | "high" | "xhigh" | "max";
	/** Built-in tools this seat may use while investigating. */
	tools?: string[];
}

export interface DebateConfig {
	seats: SeatConfig[];
	/** Selected IDs, in speaking order. Omit to use the whole catalog. */
	activeSeats?: string[];
	/** Hard cap on rounds. The loop also stops early when every seat falls silent. */
	maxRounds: number;
	/**
	 * Jaccard similarity at or above which an incoming claim counts as redundant
	 * for a given seat and is filtered before delivery (S2-MAD redundancy filter).
	 */
	redundancyThreshold: number;
	/** Reject a `challenge` that arrives without an evidence field. */
	requireEvidenceOnChallenge: boolean;
	/** Per-seat wall clock budget for one round, in milliseconds. */
	seatTurnTimeoutMs: number;
}

export interface SavedSeatConfig extends SeatConfig {
	model: string;
	thinking: NonNullable<SeatConfig["thinking"]>;
	tools: string[];
	/** Expanded persona, custom instructions, topic, and debate protocol. */
	resolvedPrompt: string;
}

export interface SavedDebateConfig extends Omit<DebateConfig, "seats" | "activeSeats"> {
	seats: SavedSeatConfig[];
}

export const DEFAULT_TOOLS = ["read", "bash", "grep", "find", "ls"];

export const DEFAULT_CONFIG: DebateConfig = {
	seats: [
		{ id: "proposer", persona: "proposer", tools: DEFAULT_TOOLS },
		{ id: "skeptic", persona: "skeptic", tools: DEFAULT_TOOLS },
		{ id: "pragmatist", persona: "pragmatist", tools: DEFAULT_TOOLS },
	],
	maxRounds: 4,
	redundancyThreshold: 0.82,
	requireEvidenceOnChallenge: true,
	seatTurnTimeoutMs: 8 * 60_000,
};

/**
 * Merge order: defaults, then agentDir/debate.json, then cwd/.pi/debate.json.
 * A config that names `seats` replaces the roster wholesale rather than merging
 * element-wise, so removing a seat does not require a null placeholder.
 */
export function loadConfig(cwd: string, agentDir: string): DebateConfig {
	let merged: DebateConfig = { ...DEFAULT_CONFIG };
	for (const file of [
		path.join(agentDir, "debate.json"),
		path.join(cwd, ".pi", "debate.json"),
	]) {
		const layer = readJsonIfPresent(file);
		if (layer) {
			if (layer.seats !== undefined) merged.activeSeats = undefined;
			merged = { ...merged, ...layer };
		}
	}
	validateConfig(merged);
	return merged;
}

export function activeSeats(config: DebateConfig): SeatConfig[] {
	return config.activeSeats
		? config.activeSeats.map((id) => config.seats.find((seat) => seat.id === id)!)
		: config.seats;
}

export function writeConfig(file: string, update: Partial<DebateConfig>): void {
	const merged = { ...readJsonIfPresent(file), ...update };
	fs.mkdirSync(path.dirname(file), { recursive: true });
	const temp = `${file}.tmp-${process.pid}`;
	fs.writeFileSync(temp, `${JSON.stringify(merged, null, 2)}\n`, "utf8");
	fs.renameSync(temp, file);
}

export function readJsonIfPresent(file: string): Partial<DebateConfig> | undefined {
	let raw: string;
	try {
		raw = fs.readFileSync(file, "utf8");
	} catch (err) {
		// A missing layer is the normal case; anything else is worth surfacing.
		if ((err as NodeJS.ErrnoException).code === "ENOENT") return undefined;
		throw new Error(`debate: cannot read ${file}: ${(err as Error).message}`);
	}
	try {
		const parsed = JSON.parse(raw);
		if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
			throw new Error("expected an object");
		}
		return parsed as Partial<DebateConfig>;
	} catch (err) {
		throw new Error(`debate: ${file} is not valid JSON: ${(err as Error).message}`);
	}
}

export function validateConfig(cfg: DebateConfig): void {
	if (!Array.isArray(cfg.seats) || cfg.seats.length < 2) {
		throw new Error("debate: seats must be an array with at least 2 entries in debate.json");
	}
	const seen = new Set<string>();
	for (const seat of cfg.seats) {
		if (!seat || typeof seat.id !== "string") {
			throw new Error("debate: each seat needs an id");
		}
		if (seat.persona !== undefined && (typeof seat.persona !== "string" || !seat.persona.trim())) {
			throw new Error(`debate: seat "${seat.id}" persona must be a nonempty name`);
		}
		if (seat.systemPrompt !== undefined && typeof seat.systemPrompt !== "string") {
			throw new Error(`debate: seat "${seat.id}" systemPrompt must be a string`);
		}
		if (seat.id === HUMAN_SEAT) throw new Error(`debate: seat id "${HUMAN_SEAT}" is reserved for the human`);
		if (!/^[a-z0-9][a-z0-9-]*$/.test(seat.id)) {
			throw new Error(`debate: seat id "${seat.id}" must be lowercase alphanumeric with dashes`);
		}
		if (seen.has(seat.id)) throw new Error(`debate: duplicate seat id "${seat.id}"`);
		seen.add(seat.id);
		if (seat.model !== undefined && (typeof seat.model !== "string" || !/^[^/]+\/.+$/.test(seat.model))) {
			throw new Error(`debate: seat "${seat.id}" model must be "provider/model"`);
		}
		if (seat.thinking !== undefined && !["off", "minimal", "low", "medium", "high", "xhigh", "max"].includes(seat.thinking)) {
			throw new Error(`debate: invalid thinking level for seat "${seat.id}"`);
		}
		if (seat.tools !== undefined && (!Array.isArray(seat.tools) || seat.tools.some((tool) =>
			!["read", "bash", "grep", "find", "ls", "edit", "write"].includes(tool)))) {
			throw new Error(`debate: seat "${seat.id}" tools must be an array of built-in tool names`);
		}
	}
	if (cfg.activeSeats !== undefined && (!Array.isArray(cfg.activeSeats) || cfg.activeSeats.length < 2 ||
		new Set(cfg.activeSeats).size !== cfg.activeSeats.length ||
		cfg.activeSeats.some((id) => typeof id !== "string" || !seen.has(id)))) {
		throw new Error("debate: activeSeats must contain at least 2 distinct IDs from seats");
	}
	if (!Number.isFinite(cfg.redundancyThreshold) || cfg.redundancyThreshold <= 0 || cfg.redundancyThreshold > 1) {
		throw new Error(`debate: redundancyThreshold must be in (0, 1], got ${cfg.redundancyThreshold}`);
	}
	if (!Number.isSafeInteger(cfg.maxRounds) || cfg.maxRounds < 1) {
		throw new Error(`debate: maxRounds must be a positive integer, got ${cfg.maxRounds}`);
	}
	if (!Number.isInteger(cfg.seatTurnTimeoutMs) || cfg.seatTurnTimeoutMs < 1 || cfg.seatTurnTimeoutMs > 2 ** 31 - 1) {
		throw new Error("debate: seatTurnTimeoutMs must be an integer between 1 and 2147483647");
	}
	if (typeof cfg.requireEvidenceOnChallenge !== "boolean") {
		throw new Error("debate: requireEvidenceOnChallenge must be a boolean");
	}
}
