/**
 * The claim ledger: the only channel between seats.
 *
 * Seats investigate in their own private context and may emit only typed
 * claims. The ledger stores them, decides what each seat receives, and drops
 * what a seat already knows. Nothing a seat says outside of a claim reaches any
 * other seat, so the routing boundary is enforced by this module rather than by
 * prompt compliance.
 */

export type ClaimKind = "assert" | "challenge" | "concede" | "evidence";

/** Seat id under which the human's interjections are recorded. */
export const HUMAN_SEAT = "you";

export interface Claim {
	id: string;
	round: number;
	seat: string;
	kind: ClaimKind;
	text: string;
	/** Id of the claim this responds to. Required for challenge/concede/evidence. */
	target?: string;
	/** Verifiable support: a file:line reference, a command and its output, a citation. */
	evidence?: string;
	confidence: number;
	createdAt: number;
	/**
	 * Bypasses the redundancy filter on delivery. Set for interjections from the
	 * human, whose steer must reach every seat whether or not it resembles
	 * something already said.
	 */
	authoritative?: boolean;
}

export interface RejectedClaim {
	reason: string;
	/** Set when the claim was dropped as a duplicate rather than as malformed. */
	duplicateOf?: string;
}

export type ClaimResult = { ok: true; claim: Claim } | { ok: false; rejected: RejectedClaim };

export interface LedgerOptions {
	redundancyThreshold: number;
	requireEvidenceOnChallenge: boolean;
}

export class Ledger {
	private readonly claims: Claim[] = [];
	/** Claim ids already sent to a seat, so a seat never reads the same claim twice. */
	private readonly delivered = new Map<string, Set<string>>();
	private counter = 0;

	constructor(
		readonly topic: string,
		private readonly options: LedgerOptions,
	) {}

	get all(): readonly Claim[] {
		return this.claims;
	}

	byId(id: string): Claim | undefined {
		return this.claims.find((c) => c.id === id);
	}

	/**
	 * Validate and store a claim. Rejection is returned rather than thrown so the
	 * emitting seat can read the reason as a tool result and correct itself
	 * in-loop, which is cheaper than failing the whole turn.
	 */
	add(input: {
		seat: string;
		round: number;
		kind: ClaimKind;
		text: string;
		target?: string;
		evidence?: string;
		confidence: number;
		authoritative?: boolean;
	}): ClaimResult {
		const text = input.text.trim();
		if (!text) {
			return { ok: false, rejected: { reason: "text was empty" } };
		}

		if (input.kind !== "assert" && !input.target) {
			return {
				ok: false,
				rejected: { reason: `kind "${input.kind}" requires target, the id of the claim you are responding to` },
			};
		}
		if (input.target !== undefined) {
			const target = this.byId(input.target);
			if (!target) {
				return { ok: false, rejected: { reason: `target "${input.target}" is not a claim in this debate` } };
			}
			if (target.seat === input.seat && input.kind === "challenge") {
				return { ok: false, rejected: { reason: "a seat cannot challenge its own claim; revise it with a new assert instead" } };
			}
		}

		// A challenge without evidence is an assertion wearing a challenge label.
		// Requiring support here is what keeps routed claims falsifiable once the
		// surrounding reasoning has been stripped.
		if (
			this.options.requireEvidenceOnChallenge &&
			input.kind === "challenge" &&
			!input.evidence?.trim()
		) {
			return {
				ok: false,
				rejected: {
					reason:
						"challenge requires evidence: cite a file:line, a command you ran and its output, or a doc reference. " +
						"Investigate with your tools first, then challenge.",
				},
			};
		}

		// The human may restate a constraint as often as they like; seats may not.
		if (!input.authoritative) {
			const duplicate = this.claims.find(
				(c) => c.seat === input.seat && samePoint(c, input, this.options.redundancyThreshold),
			);
			if (duplicate) {
				return { ok: false, rejected: { reason: "you already made this point", duplicateOf: duplicate.id } };
			}
		}

		const claim: Claim = {
			id: `c${++this.counter}`,
			round: input.round,
			seat: input.seat,
			kind: input.kind,
			text,
			target: input.target,
			evidence: input.evidence?.trim() || undefined,
			confidence: clamp(input.confidence),
			createdAt: Date.now(),
			authoritative: input.authoritative || undefined,
		};
		this.claims.push(claim);
		// A seat implicitly knows what it just said.
		this.seen(claim.seat).add(claim.id);
		return { ok: true, claim };
	}

	/**
	 * What `seat` should receive next: undelivered claims from other seats, minus
	 * anything close enough to what this seat already holds to teach it nothing.
	 * Claims aimed directly at this seat sort first so a challenge is never
	 * buried behind unrelated asserts.
	 */
	route(seat: string): Claim[] {
		const seen = this.seen(seat);
		const known = this.claims.filter((c) => seen.has(c.id));

		const fresh = this.claims.filter((c) => c.seat !== seat && !seen.has(c.id));
		const nonRedundant = fresh.filter((candidate) => {
			// A steer from the human outranks the filter entirely.
			if (candidate.authoritative) return true;
			// Anything responding to this seat is always relevant, even if its
			// wording resembles a point the seat has already read.
			if (candidate.target && this.byId(candidate.target)?.seat === seat) return true;
			return !known.some((k) => samePoint(k, candidate, this.options.redundancyThreshold));
		});

		nonRedundant.sort((a, b) => rank(this, a, seat) - rank(this, b, seat) || a.createdAt - b.createdAt);
		const routed: Claim[] = [];
		const included = new Set(seen);
		const include = (claim: Claim): void => {
			if (included.has(claim.id)) return;
			included.add(claim.id);
			const target = claim.target ? this.byId(claim.target) : undefined;
			if (target) include(target);
			routed.push(claim);
		};
		for (const claim of nonRedundant) include(claim);
		// Replayed own claims can also refer to context lost during a resume.
		for (const claim of known) {
			const target = claim.target ? this.byId(claim.target) : undefined;
			if (target) include(target);
		}
		return routed;
	}

	/** Mark routed claims as read. Call only once the seat has actually been given them. */
	markDelivered(seat: string, claims: readonly Claim[]): void {
		const seen = this.seen(seat);
		for (const claim of claims) seen.add(claim.id);
	}

	/**
	 * Challenges nobody has answered. An answer is any concede, evidence, or
	 * counter-challenge from the challenged seat pointing back at the challenge.
	 */
	openChallenges(): Claim[] {
		return this.claims.filter((challenge) => {
			if (challenge.kind !== "challenge") return false;
			const challenged = challenge.target ? this.byId(challenge.target)?.seat : undefined;
			if (!challenged) return false;
			return !this.claims.some((reply) => reply.target === challenge.id && reply.seat === challenged);
		});
	}

	claimsInRound(round: number): Claim[] {
		return this.claims.filter((c) => c.round === round);
	}

	snapshot(): { claims: Claim[]; delivered: Record<string, string[]> } {
		return {
			claims: this.claims.map((c) => ({ ...c })),
			delivered: Object.fromEntries([...this.delivered].map(([seat, ids]) => [seat, [...ids]])),
		};
	}

	/**
	 * Rebuild a ledger from a persisted run. The claim counter is derived from
	 * the stored ids rather than persisted separately, so there is no second
	 * piece of state that can drift out of sync with the claims themselves.
	 */
	static restore(
		topic: string,
		snapshot: { claims: Claim[]; delivered: Record<string, string[]> },
		options: LedgerOptions,
	): Ledger {
		const ledger = new Ledger(topic, options);
		for (const claim of snapshot.claims) {
			ledger.claims.push({ ...claim });
			const n = Number.parseInt(claim.id.slice(1), 10);
			if (Number.isFinite(n) && n > ledger.counter) ledger.counter = n;
		}
		for (const [seat, ids] of Object.entries(snapshot.delivered)) {
			ledger.delivered.set(seat, new Set(ids));
		}
		return ledger;
	}

	/**
	 * Resuming replaces every seat with a fresh session, so a seat's memory of
	 * claims it merely *read* is gone even though the ledger recorded delivery.
	 * Reset each seat's seen set to its own claims only, which are replayed into
	 * its context on start. Everything else is then re-routed to it, which is
	 * correct: the new session genuinely has not seen it.
	 *
	 * A seat that re-argues a point it already made is caught by the
	 * self-duplicate check in add(), so re-delivery cannot loop.
	 */
	resetDeliveryForResume(): void {
		this.delivered.clear();
		for (const claim of this.claims) {
			this.seen(claim.seat).add(claim.id);
		}
	}

	claimsBySeat(seat: string): Claim[] {
		return this.claims.filter((c) => c.seat === seat);
	}

	private seen(seat: string): Set<string> {
		let set = this.delivered.get(seat);
		if (!set) {
			set = new Set<string>();
			this.delivered.set(seat, set);
		}
		return set;
	}
}

function samePoint(
	a: Pick<Claim, "kind" | "text" | "target" | "evidence">,
	b: Pick<Claim, "kind" | "text" | "target" | "evidence">,
	threshold: number,
): boolean {
	return a.kind === b.kind && a.target === b.target &&
		(a.evidence?.trim() || "") === (b.evidence?.trim() || "") &&
		(a.text.trim() === b.text.trim() || similarity(a.text, b.text) >= threshold);
}

function rank(ledger: Ledger, claim: Claim, seat: string): number {
	if (claim.authoritative) return 0;
	if (claim.target && ledger.byId(claim.target)?.seat === seat) return 1;
	if (claim.kind === "challenge") return 2;
	return 3;
}

/**
 * Token-set Jaccard over normalized words. Deliberately lexical: it needs no
 * embedding endpoint and no network, which keeps the filter deterministic and
 * testable. Swap in cosine similarity over embeddings when a local embedding
 * model is available and paraphrase detection starts to matter.
 */
export function similarity(a: string, b: string): number {
	const sa = tokenize(a);
	const sb = tokenize(b);
	if (sa.size === 0 || sb.size === 0) return 0;
	// A polarity change must survive even when a long claim is otherwise identical.
	for (const word of NEGATIONS) if (sa.has(word) !== sb.has(word)) return 0;
	let shared = 0;
	for (const token of sa) if (sb.has(token)) shared++;
	return shared / (sa.size + sb.size - shared);
}

const NEGATIONS = new Set(["no", "not", "never", "without", "neither", "nor"]);

/**
 * Content words only. Stopwords dilute Jaccard badly on short claims: swapping
 * "because" for "since" in an otherwise identical sentence scored 0.78 with
 * stopwords included, sliding a pure restatement past a 0.82 threshold. Content
 * words make the metric about what the claim says rather than how it is phrased.
 */
const STOPWORDS = new Set([
	"the", "and", "for", "but", "you", "are", "was", "were", "this", "that", "these", "those",
	"with", "from", "have", "has", "had", "its", "our", "their", "them", "they", "will", "would",
	"should", "could", "can", "may", "might", "must", "because", "since", "than", "then", "when",
	"while", "which", "what", "who", "how", "why", "into", "onto", "over", "under", "about", "after",
	"before", "here", "there", "also", "just", "only", "very", "much", "more", "most", "some", "any",
	"all", "both", "each", "other", "such", "even", "still", "yet", "use", "used", "using", "make",
	"makes", "made", "get", "gets", "let", "lets", "does", "did", "done", "been", "being", "one",
	"two", "now", "way", "ways", "thing", "things", "need", "needs", "want", "wants", "like",
]);

function tokenize(text: string): Set<string> {
	return new Set(
		text
			.toLowerCase()
			.replace(/n['’]t\b/g, " not")
			.replace(/\bcannot\b/g, "can not")
			.replace(/[^a-z0-9\s]/g, " ")
			.split(/\s+/)
			.filter((word) => (word.length > 2 || word === "no") && !STOPWORDS.has(word)),
	);
}

function clamp(confidence: number): number {
	if (!Number.isFinite(confidence)) return 0.5;
	return Math.min(1, Math.max(0, confidence));
}
