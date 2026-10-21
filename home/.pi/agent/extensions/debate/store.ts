/**
 * Run persistence.
 *
 * The ledger is written after every round, so a debate that dies mid-run leaves
 * a file whose status is still "running". A renewable file lock prevents another
 * process from resuming or archiving that run while it is active.
 *
 * Runs live under the agent dir rather than the project, so a debate never
 * writes into the repo it is arguing about.
 */

import { randomUUID } from "node:crypto";
import * as fs from "node:fs";
import * as path from "node:path";
import lockfile from "proper-lockfile";
import { type SavedDebateConfig, validateConfig } from "./config.ts";
import { type Claim, HUMAN_SEAT } from "./ledger.ts";

export const RUN_FILE_VERSION = 2;

// proper-lockfile caches metadata on fs; pi's import proxy cannot hold that cache.
const lockFs = { ...fs };

export type RunStatus = "running" | "concluded" | "archived";

class CorruptRunError extends Error {}

export interface RunRound {
	round: number;
	silent: string[];
	claimIds: string[];
}

export interface RunFile {
	version: number;
	runId: string;
	topic: string;
	/** Where the debate was held. Claims cite paths relative to it. */
	cwd: string;
	status: RunStatus;
	createdAt: number;
	updatedAt: number;
	/** Selected seat IDs in speaking order. */
	seats: string[];
	/** Resolved settings. Absent only on legacy version 1 runs. */
	config?: SavedDebateConfig;
	rounds: RunRound[];
	stoppedBecause?: string;
	claims: Claim[];
	delivered: Record<string, string[]>;
}

export class RunStore {
	private readonly dir: string;

	constructor(agentDir: string) {
		this.dir = path.join(agentDir, "debate", "runs");
	}

	static runId(topic: string, now = new Date()): string {
		const stamp = [
			now.getFullYear(),
			pad(now.getMonth() + 1),
			pad(now.getDate()),
			"-",
			pad(now.getHours()),
			pad(now.getMinutes()),
			pad(now.getSeconds()),
		].join("");
		return `${stamp}-${slug(topic)}-${randomUUID()}`;
	}

	/** Hold ownership across reading, running, and saving, including human pauses. */
	async withLock<T>(runId: string, work: (ownership: AbortSignal) => T | Promise<T>): Promise<T> {
		fs.mkdirSync(this.dir, { recursive: true });
		const ownership = new AbortController();
		const release = await lockfile.lock(this.pathFor(runId), {
			fs: lockFs,
			realpath: false,
			retries: 0,
			stale: 30_000,
			update: 10_000,
			onCompromised: (err) => ownership.abort(err),
		}).catch((err: NodeJS.ErrnoException) => {
			if (err.code === "ELOCKED") throw new Error(`debate: run "${runId}" is already in use by another operation`);
			throw err;
		});
		try {
			return await work(ownership.signal);
		} finally {
			await release().catch((err: NodeJS.ErrnoException) => {
				if (!ownership.signal.aborted || err.code !== "ERELEASED") throw err;
			});
		}
	}

	/**
	 * Atomic: a crash during the write leaves the previous round's file intact
	 * rather than a truncated one. A half-written ledger would make resume worse
	 * than having no persistence at all.
	 */
	write(run: RunFile): void {
		fs.mkdirSync(this.dir, { recursive: true });
		const target = this.pathFor(run.runId);
		const temp = `${target}.tmp-${process.pid}`;
		fs.writeFileSync(temp, `${JSON.stringify({ ...run, updatedAt: Date.now() }, null, 2)}\n`, "utf8");
		fs.renameSync(temp, target);
	}

	read(runId: string): RunFile {
		const file = this.pathFor(runId);
		let raw: string;
		try {
			raw = fs.readFileSync(file, "utf8");
		} catch (err) {
			throw new Error(`debate: no run "${runId}" at ${file}: ${(err as Error).message}`);
		}
		let parsed: RunFile;
		try {
			parsed = JSON.parse(raw) as RunFile;
		} catch (err) {
			throw new CorruptRunError(
				`debate: run "${runId}" is corrupt (${(err as Error).message}). ` +
					`Archive it with /debate archive ${runId} to get it out of the way.`,
			);
		}
		if (parsed && Number.isInteger(parsed.version) && parsed.version !== 1 && parsed.version !== RUN_FILE_VERSION) {
			throw new Error(
				`debate: run "${runId}" is version ${parsed.version}, this build reads ${RUN_FILE_VERSION}`,
			);
		}
		if (!validRun(parsed, runId)) {
			throw new CorruptRunError(`debate: run "${runId}" is corrupt. Archive it with /debate archive ${runId}.`);
		}
		return parsed;
	}

	list(): RunFile[] {
		let names: string[];
		try {
			names = fs.readdirSync(this.dir);
		} catch (err) {
			if ((err as NodeJS.ErrnoException).code === "ENOENT") return [];
			throw err;
		}
		const runs: RunFile[] = [];
		for (const name of names) {
			if (!name.endsWith(".json")) continue;
			// One unreadable file should not hide every other run from /debate runs.
			try {
				runs.push(this.read(name.slice(0, -".json".length)));
			} catch {
				continue;
			}
		}
		return runs.sort((a, b) => b.createdAt - a.createdAt);
	}

	/** Runs that never reached a verdict. These are the resume candidates. */
	unconcluded(cwd: string): RunFile[] {
		return this.list().filter((run) => run.status === "running" && run.cwd === cwd);
	}

	/**
	 * Mark a run as abandoned without deleting it. The claims are the only record
	 * that the work happened, and a resume that turns out to be unwanted should
	 * not destroy them.
	 */
	archive(runId: string): Promise<RunFile | { runId: string; quarantinedPath: string }> {
		return this.withLock(runId, () => {
			let run: RunFile;
			try {
				run = this.read(runId);
			} catch (err) {
				if (!(err instanceof CorruptRunError)) throw err;
				const file = this.pathFor(runId);
				const quarantinedPath = `${file}.corrupt-${randomUUID()}`;
				fs.renameSync(file, quarantinedPath);
				return { runId, quarantinedPath };
			}
			const archived: RunFile = { ...run, status: "archived" };
			this.write(archived);
			return archived;
		});
	}

	pathFor(runId: string): string {
		if (!/^[a-zA-Z0-9][a-zA-Z0-9_-]*$/.test(runId)) throw new Error(`debate: invalid run id "${runId}"`);
		return path.join(this.dir, `${runId}.json`);
	}
}

function validRun(run: RunFile, runId: string): boolean {
	const strings = (value: unknown): value is string[] =>
		Array.isArray(value) && value.every((item) => typeof item === "string");
	if (!run || ![1, RUN_FILE_VERSION].includes(run.version) || run.runId !== runId ||
		typeof run.topic !== "string" || typeof run.cwd !== "string" ||
		!["running", "concluded", "archived"].includes(run.status) ||
		!Number.isFinite(run.createdAt) || !Number.isFinite(run.updatedAt) ||
		!strings(run.seats) || run.seats.length < 2 || new Set(run.seats).size !== run.seats.length ||
		run.seats.some((seat) => seat === HUMAN_SEAT || !/^[a-z0-9][a-z0-9-]*$/.test(seat)) ||
		!Array.isArray(run.claims) || !Array.isArray(run.rounds) ||
		!run.delivered || typeof run.delivered !== "object" || Array.isArray(run.delivered) ||
		(run.stoppedBecause !== undefined && typeof run.stoppedBecause !== "string")) return false;
	if (run.version === RUN_FILE_VERSION && !run.config) return false;
	if (run.config !== undefined) {
		try { validateConfig(run.config); } catch { return false; }
		if (JSON.stringify(run.config.seats.map((seat) => seat.id)) !== JSON.stringify(run.seats) ||
			run.config.seats.some((seat) => !seat.model || !seat.thinking || !Array.isArray(seat.tools) ||
				typeof seat.resolvedPrompt !== "string" || !seat.resolvedPrompt.trim())) return false;
	}

	const seats = new Set([...run.seats, HUMAN_SEAT]);
	const claims = new Set<string>();
	for (const claim of run.claims) {
		if (!claim || typeof claim.id !== "string" || !/^c[1-9]\d*$/.test(claim.id) ||
			!Number.isSafeInteger(Number(claim.id.slice(1)) + 1) || claims.has(claim.id) ||
			!seats.has(claim.seat) || !["assert", "challenge", "concede", "evidence"].includes(claim.kind) ||
			typeof claim.text !== "string" || !claim.text.trim() ||
			!Number.isSafeInteger(claim.round) || claim.round < 0 || !Number.isFinite(claim.createdAt) ||
			!Number.isFinite(claim.confidence) || claim.confidence < 0 || claim.confidence > 1 ||
			(claim.evidence !== undefined && typeof claim.evidence !== "string") ||
			(claim.authoritative !== undefined && typeof claim.authoritative !== "boolean") ||
			(claim.kind !== "assert" && !claim.target) ||
			(claim.target !== undefined && !claims.has(claim.target))) return false;
		claims.add(claim.id);
	}
	let previousRound = 0;
	for (const round of run.rounds) {
		if (!round || !Number.isSafeInteger(round.round) || round.round <= previousRound ||
			!strings(round.silent) || round.silent.some((seat) => !run.seats.includes(seat)) ||
			!strings(round.claimIds) || round.claimIds.some((id) => !claims.has(id))) return false;
		previousRound = round.round;
	}
	return Object.entries(run.delivered).every(([seat, ids]) =>
		seats.has(seat) && strings(ids) && ids.every((id) => claims.has(id)));
}

/** Highest round number this run completed. 0 when it crashed before finishing one. */
export function lastRound(run: RunFile): number {
	return run.rounds.reduce((max, r) => (r.round > max ? r.round : max), 0);
}

function pad(n: number): string {
	return String(n).padStart(2, "0");
}

function slug(topic: string): string {
	const base = topic
		.toLowerCase()
		.replace(/[^a-z0-9]+/g, "-")
		.replace(/^-+|-+$/g, "")
		.slice(0, 48)
		.replace(/-+$/, "");
	return base || "untitled";
}
