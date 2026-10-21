import assert from "node:assert/strict";
import * as fs from "node:fs";
import * as os from "node:os";
import * as path from "node:path";
import { test } from "node:test";
import { type Claim, Ledger } from "./ledger.ts";
import { RUN_FILE_VERSION, RunStore, type RunFile, lastRound } from "./store.ts";

const tmp = () => fs.mkdtempSync(path.join(os.tmpdir(), "debate-store-"));

const claim = (over: Partial<Claim> = {}): Claim => ({
	id: "c1", round: 1, seat: "proposer", kind: "assert", text: "sqlite is enough",
	confidence: 0.7, createdAt: 1000, ...over,
});

const runFile = (over: Partial<RunFile> = {}): RunFile => ({
	version: RUN_FILE_VERSION,
	runId: "20260916-120000-cache-choice",
	topic: "sqlite or postgres",
	cwd: "/repo",
	status: "running",
	createdAt: 1000,
	updatedAt: 1000,
	seats: ["proposer", "skeptic"],
	config: {
		seats: ["proposer", "skeptic"].map((id) => ({
			id, model: "test/model", thinking: "off", tools: [], resolvedPrompt: `Role: ${id}`,
		})),
		maxRounds: 4, redundancyThreshold: 0.82, requireEvidenceOnChallenge: true, seatTurnTimeoutMs: 1000,
	},
	rounds: [{ round: 1, silent: [], claimIds: ["c1"] }],
	claims: [claim()],
	delivered: { proposer: ["c1"] },
	...over,
});

test("a run survives a write/read round trip", () => {
	const store = new RunStore(tmp());
	const run = runFile();
	store.write(run);
	const read = store.read(run.runId);
	assert.equal(read.topic, run.topic);
	assert.equal(read.claims.length, 1);
	assert.deepEqual(read.delivered, { proposer: ["c1"] });
	assert.ok(read.updatedAt >= run.createdAt, "updatedAt is stamped on write");
});

test("writing leaves no temp file behind", () => {
	const dir = tmp();
	const store = new RunStore(dir);
	store.write(runFile());
	const files = fs.readdirSync(path.join(dir, "debate", "runs"));
	assert.deepEqual(files.filter((f) => f.includes(".tmp-")), [], "temp file was renamed, not left");
	assert.equal(files.length, 1);
});

test("rewriting a run replaces it rather than accumulating files", () => {
	const dir = tmp();
	const store = new RunStore(dir);
	const run = runFile();
	store.write(run);
	store.write({ ...run, rounds: [...run.rounds, { round: 2, silent: ["skeptic"], claimIds: [] }] });
	assert.equal(fs.readdirSync(path.join(dir, "debate", "runs")).length, 1);
	assert.equal(lastRound(store.read(run.runId)), 2);
});

test("a corrupt run reports which id to archive instead of throwing raw JSON noise", () => {
	const dir = tmp();
	const store = new RunStore(dir);
	fs.mkdirSync(path.join(dir, "debate", "runs"), { recursive: true });
	fs.writeFileSync(store.pathFor("broken"), "{ not json", "utf8");
	assert.throws(() => store.read("broken"), /corrupt.*archive broken/s);
});

test("one corrupt run does not hide the others from list()", () => {
	const dir = tmp();
	const store = new RunStore(dir);
	store.write(runFile({ runId: "good-run" }));
	fs.writeFileSync(store.pathFor("broken"), "{ not json", "utf8");
	assert.deepEqual(store.list().map((r) => r.runId), ["good-run"]);
});

test("a future run version is refused rather than misread", () => {
	const store = new RunStore(tmp());
	store.write(runFile({ version: RUN_FILE_VERSION + 1 }));
	assert.throws(() => store.read(runFile().runId), /version/);
});

test("unconcluded() finds only running runs from this directory", () => {
	const store = new RunStore(tmp());
	store.write(runFile({ runId: "a-running-here", status: "running", cwd: "/repo" }));
	store.write(runFile({ runId: "b-done-here", status: "concluded", cwd: "/repo" }));
	store.write(runFile({ runId: "c-running-elsewhere", status: "running", cwd: "/other" }));
	assert.deepEqual(store.unconcluded("/repo").map((r) => r.runId), ["a-running-here"]);
});

test("archiving keeps the claims and only changes status", async () => {
	const store = new RunStore(tmp());
	store.write(runFile());
	const archived = await store.archive(runFile().runId);
	assert.ok("status" in archived);
	assert.equal(archived.status, "archived");
	assert.equal(archived.claims.length, 1, "claims are the record; archiving must not drop them");
	assert.equal(store.read(runFile().runId).status, "archived");
	assert.deepEqual(store.unconcluded("/repo"), [], "an archived run is no longer a resume candidate");
});

test("lastRound is 0 for a run that crashed before finishing a round", () => {
	assert.equal(lastRound(runFile({ rounds: [] })), 0);
	assert.equal(lastRound(runFile({ rounds: [{ round: 3, silent: [], claimIds: [] }] })), 3);
});

test("run ids are filesystem safe and carry the topic", () => {
	const id = RunStore.runId("Should we use SQLite or Postgres?!", new Date(2026, 8, 16, 14, 5, 9));
	assert.match(id, /^20260916-140509-should-we-use-sqlite-or-postgres-[0-9a-f-]{36}$/);
	assert.notEqual(id, RunStore.runId("Should we use SQLite or Postgres?!", new Date(2026, 8, 16, 14, 5, 9)));
	assert.match(RunStore.runId("///"), /-untitled-[0-9a-f-]{36}$/, "an unusable topic still yields a valid id");
});

test("restore rebuilds claims and continues ids past the highest stored one", () => {
	const opts = { redundancyThreshold: 0.82, requireEvidenceOnChallenge: true };
	const restored = Ledger.restore(
		"topic",
		{ claims: [claim({ id: "c1" }), claim({ id: "c7", seat: "skeptic", text: "postgres scales out" })], delivered: {} },
		opts,
	);
	assert.equal(restored.all.length, 2);
	const next = restored.add({ seat: "pragmatist", round: 2, kind: "assert", text: "defer the whole thing", confidence: 0.6 });
	assert.ok(next.ok);
	assert.equal(next.claim.id, "c8", "the counter resumes past c7 so ids never collide");
});

test("resume re-routes others' claims because the new session never saw them", () => {
	const opts = { redundancyThreshold: 0.82, requireEvidenceOnChallenge: true };
	const ledger = Ledger.restore(
		"topic",
		{
			claims: [
				claim({ id: "c1", seat: "proposer", text: "sqlite is enough" }),
				claim({ id: "c2", seat: "skeptic", text: "postgres scales out" }),
			],
			// Before the crash, skeptic had already consumed c1.
			delivered: { proposer: ["c1", "c2"], skeptic: ["c1", "c2"] },
		},
		opts,
	);
	assert.equal(ledger.route("skeptic").length, 0, "delivery was recorded before the crash");

	ledger.resetDeliveryForResume();
	assert.deepEqual(ledger.route("skeptic").map((c) => c.id), ["c1"], "c1 is re-sent; c2 is skeptic's own");
	assert.deepEqual(ledger.route("proposer").map((c) => c.id), ["c2"]);
});

test("an interjection reaches every seat and outranks the redundancy filter", () => {
	const opts = { redundancyThreshold: 0.82, requireEvidenceOnChallenge: true };
	const ledger = new Ledger("topic", opts);
	ledger.add({ seat: "proposer", round: 1, kind: "assert", text: "sqlite is enough for one host", confidence: 0.7 });
	ledger.markDelivered("skeptic", ledger.route("skeptic"));
	assert.equal(ledger.route("skeptic").length, 0);

	// Same words the seat already read, but from the human.
	const steer = ledger.add({
		seat: "you", round: 1, kind: "assert", text: "sqlite is enough for one host",
		confidence: 1, authoritative: true,
	});
	assert.ok(steer.ok);
	const routed = ledger.route("skeptic");
	assert.equal(routed.length, 1, "an authoritative claim is never filtered as redundant");
	assert.equal(routed[0]?.seat, "you");
});

test("an interjection sorts ahead of a challenge aimed at the seat", () => {
	const opts = { redundancyThreshold: 0.82, requireEvidenceOnChallenge: true };
	const ledger = new Ledger("topic", opts);
	const mine = ledger.add({ seat: "proposer", round: 1, kind: "assert", text: "sqlite is enough", confidence: 0.7 });
	assert.ok(mine.ok);
	ledger.markDelivered("proposer", ledger.route("proposer"));
	ledger.add({
		seat: "skeptic", round: 2, kind: "challenge", target: mine.claim.id,
		text: "write contention", evidence: "db/pool.ts:41", confidence: 0.9,
	});
	ledger.add({
		seat: "you", round: 2, kind: "assert", text: "assume we move multi region next year",
		confidence: 1, authoritative: true,
	});
	assert.equal(ledger.route("proposer")[0]?.seat, "you", "your constraint is read before the challenge");
});

test("the human may restate a constraint; a seat may not", () => {
	const opts = { redundancyThreshold: 0.82, requireEvidenceOnChallenge: true };
	const ledger = new Ledger("topic", opts);
	const text = "keep the blast radius to one service";
	assert.ok(ledger.add({ seat: "you", round: 1, kind: "assert", text, confidence: 1, authoritative: true }).ok);
	assert.ok(ledger.add({ seat: "you", round: 2, kind: "assert", text, confidence: 1, authoritative: true }).ok);
	assert.ok(ledger.add({ seat: "proposer", round: 2, kind: "assert", text, confidence: 0.7 }).ok);
	assert.equal(ledger.add({ seat: "proposer", round: 3, kind: "assert", text, confidence: 0.7 }).ok, false);
});
