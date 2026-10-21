/**
 * The emit_claim tool, built per seat.
 *
 * This is the enforcement point. A seat is handed this tool and no other way to
 * address the group, so the wire format between agents is a validated schema
 * instead of prose the orchestrator has to parse back out. The seat may still
 * read files and run commands freely; that work stays in its own context and
 * only what it chooses to emit becomes visible to anyone else.
 */

import { StringEnum } from "@earendil-works/pi-ai";
import { defineTool } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";
import type { ClaimKind, Ledger } from "./ledger.ts";

export interface ClaimToolHooks {
	/** Current round, read at call time because a seat's session outlives a round. */
	currentRound: () => number;
	/** Notified on every accepted claim so the orchestrator can render progress. */
	onAccepted?: (claimId: string, kind: ClaimKind) => void;
}

const CLAIM_PARAMS = Type.Object({
	kind: StringEnum(["assert", "challenge", "concede", "evidence"] as const, {
		description:
			"assert: a new position. challenge: an objection to another claim, requires evidence. " +
			"concede: accept another claim's point against yours. evidence: add support to an existing claim.",
	}),
	text: Type.String({
		description: "The point itself, stated so it can be argued with. One point, not a summary of several.",
	}),
	target: Type.Optional(
		Type.String({
			description: "Claim id you are responding to, for example c3. Required unless kind is 'assert'.",
		}),
	),
	evidence: Type.Optional(
		Type.String({
			description:
				"What makes this checkable: a file:line reference, a command and the relevant part of its output, " +
				"or a doc citation. Required for 'challenge'.",
		}),
	),
	confidence: Type.Number({
		description: "0 to 1. How much weight you want this to carry if the synthesis has to choose.",
	}),
});

export function createClaimTool(ledger: Ledger, seat: string, hooks: ClaimToolHooks) {
	return defineTool({
		name: "emit_claim",
		label: "Claim",
		description:
			"Record one evidence-backed finding about the engineering question. Use one point per call.",
		promptSnippet: "Emit one typed claim to the other debate participants",
		promptGuidelines: [
			"Use emit_claim for every point you want the other participants to see; nothing else you write reaches them.",
			"Use emit_claim with kind 'challenge' only after verifying the problem with read, grep, or bash, and put what you found in evidence.",
			"Use emit_claim with kind 'concede' when another participant's evidence defeats a point you made. Conceding a losing point is the goal, not a loss.",
			"Call emit_claim once per distinct point rather than bundling several points into one call.",
		],
		parameters: CLAIM_PARAMS,
		async execute(_toolCallId, params, _signal, _onUpdate, _ctx) {
			const result = ledger.add({
				seat,
				round: hooks.currentRound(),
				kind: params.kind as ClaimKind,
				text: params.text,
				target: params.target,
				evidence: params.evidence,
				confidence: params.confidence,
			});

			if (!result.ok) {
				const { reason, duplicateOf } = result.rejected;
				throw new Error(duplicateOf
					? `Not recorded: ${reason} (see ${duplicateOf}). Make a different point or stop here.`
					: `Not recorded: ${reason}`);
			}

			hooks.onAccepted?.(result.claim.id, result.claim.kind);
			return {
				content: [
					{
						type: "text" as const,
						text: `Recorded ${result.claim.id} (${result.claim.kind}). The other participants will see it next round.`,
					},
				],
				details: { accepted: true, claimId: result.claim.id },
			};
		},
	});
}
