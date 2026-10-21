import assert from "node:assert/strict";
import { test } from "node:test";
import { Ledger, similarity } from "./ledger.ts";

const opts = { redundancyThreshold: 0.82, requireEvidenceOnChallenge: true };
const make = () => new Ledger("cache in sqlite or postgres", opts);

const assertClaim = (l: Ledger, seat: string, text: string, round = 1) =>
	l.add({ seat, round, kind: "assert" as const, text, confidence: 0.7 });

test("challenge without evidence is rejected", () => {
	const l = make();
	const base = assertClaim(l, "proposer", "sqlite is enough for one host");
	assert.ok(base.ok);
	const bad = l.add({
		seat: "skeptic", round: 1, kind: "challenge", text: "that will not scale", confidence: 0.8,
		target: base.claim.id,
	});
	assert.equal(bad.ok, false);
	assert.match((bad as any).rejected.reason, /requires evidence/);
});

test("challenge with evidence is accepted", () => {
	const l = make();
	const base = assertClaim(l, "proposer", "sqlite is enough for one host");
	assert.ok(base.ok);
	const good = l.add({
		seat: "skeptic", round: 1, kind: "challenge", target: base.claim.id, confidence: 0.8,
		text: "writers will contend", evidence: "db/pool.ts:41 opens 16 connections",
	});
	assert.ok(good.ok);
});

test("a seat cannot restate its own point", () => {
	const l = make();
	assertClaim(l, "proposer", "we should use sqlite because the service is single node");
	const dup = assertClaim(l, "proposer", "we should use sqlite since the service is single node");
	assert.equal(dup.ok, false);
	assert.ok((dup as any).rejected.duplicateOf);
});

test("routing hides a seat's own claims and delivers others once", () => {
	const l = make();
	assertClaim(l, "proposer", "sqlite is enough for one host");
	assertClaim(l, "pragmatist", "deferring this costs nothing this quarter");

	const toSkeptic = l.route("skeptic");
	assert.equal(toSkeptic.length, 2);
	assert.equal(l.route("proposer").length, 1, "proposer sees only the pragmatist");

	l.markDelivered("skeptic", toSkeptic);
	assert.equal(l.route("skeptic").length, 0, "delivered claims are not resent");
});

test("routing filters claims redundant with what a seat already read", () => {
	const l = make();
	assertClaim(l, "proposer", "postgres is the right call for multi region later");
	const first = l.route("skeptic");
	l.markDelivered("skeptic", first);

	assertClaim(l, "pragmatist", "postgres is the right call for multi region later");
	assert.equal(l.route("skeptic").length, 0, "a near-identical restatement is filtered");
});

test("a claim aimed at a seat is delivered even when it looks redundant", () => {
	const l = make();
	const mine = assertClaim(l, "proposer", "sqlite handles our write volume fine");
	assert.ok(mine.ok);
	l.markDelivered("proposer", l.route("proposer"));

	l.add({
		seat: "skeptic", round: 2, kind: "challenge", target: mine.claim.id, confidence: 0.9,
		text: "sqlite handles our write volume fine is wrong", evidence: "bench: 4200 w/s vs 900 ceiling",
	});
	assert.equal(l.route("proposer").length, 1, "a challenge to me always reaches me");
});

test("claims targeting a seat sort ahead of unrelated ones", () => {
	const l = make();
	const mine = assertClaim(l, "proposer", "sqlite is enough");
	assert.ok(mine.ok);
	l.markDelivered("proposer", l.route("proposer"));

	assertClaim(l, "pragmatist", "an entirely separate point about retention windows", 2);
	l.add({
		seat: "skeptic", round: 2, kind: "challenge", target: mine.claim.id, confidence: 0.9,
		text: "contention under concurrent writers", evidence: "db/pool.ts:41",
	});

	const routed = l.route("proposer");
	assert.equal(routed[0].kind, "challenge", "the challenge to my claim comes first");
});

test("an unanswered challenge stays open until the challenged seat replies", () => {
	const l = make();
	const base = assertClaim(l, "proposer", "sqlite is enough");
	assert.ok(base.ok);
	const ch = l.add({
		seat: "skeptic", round: 1, kind: "challenge", target: base.claim.id, confidence: 0.9,
		text: "contention under concurrent writers", evidence: "db/pool.ts:41",
	});
	assert.ok(ch.ok);
	assert.equal(l.openChallenges().length, 1);

	l.add({ seat: "proposer", round: 2, kind: "concede", target: ch.claim.id, text: "fair, pool is 16", confidence: 0.8 });
	assert.equal(l.openChallenges().length, 0, "a concede from the challenged seat closes it");
});

test("a third party cannot close a challenge on someone else's behalf", () => {
	const l = make();
	const base = assertClaim(l, "proposer", "sqlite is enough");
	assert.ok(base.ok);
	const ch = l.add({
		seat: "skeptic", round: 1, kind: "challenge", target: base.claim.id, confidence: 0.9,
		text: "contention", evidence: "db/pool.ts:41",
	});
	assert.ok(ch.ok);
	l.add({ seat: "pragmatist", round: 2, kind: "concede", target: ch.claim.id, text: "agreed", confidence: 0.5 });
	assert.equal(l.openChallenges().length, 1);
});

test("a challenge must name a real target and cannot hit your own claim", () => {
	const l = make();
	const mine = assertClaim(l, "proposer", "sqlite is enough");
	assert.ok(mine.ok);
	assert.equal(l.add({ seat: "skeptic", round: 1, kind: "challenge", text: "x", evidence: "y", confidence: 0.5, target: "c99" }).ok, false);
	assert.equal(l.add({ seat: "proposer", round: 1, kind: "challenge", text: "x", evidence: "y", confidence: 0.5, target: mine.claim.id }).ok, false);
	assert.equal(l.add({ seat: "skeptic", round: 1, kind: "concede", text: "x", confidence: 0.5 }).ok, false);
});

test("similarity is symmetric, bounded, and ignores punctuation", () => {
	assert.equal(similarity("", "anything"), 0);
	assert.equal(similarity("the cache layer", "the cache layer"), 1);
	assert.equal(similarity("cache layer!", "cache, layer"), 1);
	assert.equal(similarity("alpha beta", "beta alpha"), similarity("beta alpha", "alpha beta"));
	assert.ok(similarity("postgres scales out", "sqlite is a file") < 0.2);
});
