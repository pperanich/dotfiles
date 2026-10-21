/**
 * Interactive roster configuration.
 *
 * Models are chosen from what this agent dir can actually authenticate, so a
 * seat cannot be pointed at a model that will fail on its first turn. The
 * result is written back to debate.json rather than held in session state, so
 * a roster survives a restart.
 */

import * as path from "node:path";
import type { ExtensionContext } from "@earendil-works/pi-coding-agent";
import { SelectList, Text, matchesKey } from "@earendil-works/pi-tui";
import { type DebateConfig, type SeatConfig, activeSeats, readJsonIfPresent, writeConfig } from "./config.ts";

const THINKING_LEVELS = ["off", "minimal", "low", "medium", "high", "xhigh", "max"] as const;
const SESSION_DEFAULT = "(session default)";

export async function configureSeats(
	ctx: ExtensionContext,
	config: DebateConfig,
	agentDir: string,
): Promise<boolean> {
	const available = ctx.modelRegistry.getAvailable();
	if (available.length === 0) {
		ctx.ui.notify(
			"No authenticated models. Check auth.json and models.json in this agent dir.",
			"error",
		);
		return false;
	}

	const labels = available.map((model) => `${model.provider}/${model.id}`).sort();
	const updated: SeatConfig[] = [];

	for (const seat of config.seats) {
		const current = seat.model ?? SESSION_DEFAULT;
		const modelChoice = await ctx.ui.select(
			`Model for "${seat.id}" (currently ${current})`,
			[SESSION_DEFAULT, ...labels],
		);
		// A dismissed dialog leaves the whole roster untouched rather than saving
		// a half-configured one.
		if (modelChoice === undefined) {
			ctx.ui.notify("Roster unchanged.", "info");
			return false;
		}

		let thinking: SeatConfig["thinking"];
		if (modelChoice !== SESSION_DEFAULT) {
			const model = available.find((m) => `${m.provider}/${m.id}` === modelChoice);
			// Offering a thinking level for a model that does not reason would write
			// a setting the provider ignores.
			if (model?.reasoning) {
				const levelChoice = await ctx.ui.select(`Thinking level for "${seat.id}"`, [
					SESSION_DEFAULT,
					...THINKING_LEVELS,
				]);
				if (levelChoice === undefined) {
					ctx.ui.notify("Roster unchanged.", "info");
					return false;
				}
				if (levelChoice !== SESSION_DEFAULT) thinking = levelChoice as SeatConfig["thinking"];
			}
		}

		updated.push({
			...seat,
			model: modelChoice === SESSION_DEFAULT ? undefined : modelChoice,
			thinking,
		});
	}

	const projectFile = path.join(ctx.cwd, ".pi", "debate.json");
	const file = readJsonIfPresent(projectFile)?.seats === undefined
		? path.join(agentDir, "debate.json")
		: projectFile;
	writeConfig(file, { seats: updated });
	ctx.ui.notify(`Saved ${updated.length} seats to ${file}.`, "info");
	return true;
}

export function describeRoster(config: DebateConfig): string {
	return activeSeats(config)
		.map((seat) => {
			const model = seat.model ?? "session default";
			return `  ${seat.id.padEnd(12)} ${(seat.persona ?? "custom").padEnd(12)} ${model}${seat.thinking ? ` (${seat.thinking})` : ""}`;
		})
		.join("\n");
}

export async function selectSeats(ctx: ExtensionContext, config: DebateConfig, agentDir: string): Promise<void> {
	if (ctx.mode !== "tui") {
		ctx.ui.notify("The seat picker needs TUI mode. Set activeSeats in debate.json for other modes.", "warning");
		return;
	}
	const selected = new Set(activeSeats(config).map((seat) => seat.id));
	const result = await ctx.ui.custom<string[] | undefined>((tui, theme, _kb, done) => {
		const items = config.seats.map((seat) => ({
			value: seat.id,
			label: "",
			description: `${seat.model ?? "session default"}${seat.thinking ? ` (${seat.thinking})` : ""}`,
		}));
		const list = new SelectList(items, Math.min(items.length, 10), {
			selectedPrefix: (s) => theme.fg("accent", s),
			selectedText: (s) => theme.fg("accent", s),
			description: (s) => theme.fg("muted", s),
			scrollInfo: (s) => theme.fg("dim", s),
			noMatch: (s) => theme.fg("warning", s),
		});
		let error = "";
		list.onCancel = () => done(undefined);
		list.onSelect = () => {
			if (selected.size < 2) error = "Choose at least two seats.";
			else done([...selected]);
		};
		return {
			render(width) {
				for (const item of items) item.label = `[${selected.has(item.value) ? "x" : " "}] ${item.value}`;
				return [
					...new Text(theme.fg("accent", `Active debate seats (${selected.size})`), 0, 0).render(width),
					...list.render(width),
					...new Text(error || "Space toggles, Enter saves, Esc cancels. New seats speak last.", 0, 0).render(width),
				];
			},
			invalidate() { list.invalidate(); },
			handleInput(data) {
				if (matchesKey(data, "space")) {
					const id = list.getSelectedItem()!.value;
					if (!selected.delete(id)) selected.add(id);
					error = "";
				} else list.handleInput(data);
				tui.requestRender();
			},
		};
	});
	if (!result) return;
	const projectFile = path.join(ctx.cwd, ".pi", "debate.json");
	const project = readJsonIfPresent(projectFile);
	const file = project?.seats !== undefined || project?.activeSeats !== undefined
		? projectFile : path.join(agentDir, "debate.json");
	writeConfig(file, { activeSeats: result });
	ctx.ui.notify(`Saved active seats: ${result.join(", ")}.`, "info");
}
