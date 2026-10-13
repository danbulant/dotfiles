import type { ExtensionAPI, ExtensionContext } from "@oh-my-pi/pi-coding-agent";
import { diffLines } from "@oh-my-pi/pi-natives";
import { readFile } from "node:fs/promises";
import { homedir } from "node:os";
import { resolve } from "node:path";

const STATE_TYPE = "dan.dotfiles.loc.v1";
const STATUS_KEY = "loc";
type Counts = { added: number; removed: number };
type State = { turn: Counts; session: Counts };

type Receiver = {
	accept: (counts: Counts) => void;
};
// OMP imports once, then rebinds this factory for every child (including restricted
// children). Share only live routing; each session owns/persists its own totals.
const sessions = new Map<string, Receiver>();
const agents = new Map<string, Set<Receiver>>();

function emptyState(): State {
	return { turn: { added: 0, removed: 0 }, session: { added: 0, removed: 0 } };
}

function isCounts(value: unknown): value is Counts {
	if (!value || typeof value !== "object") return false;
	const counts = value as Counts;
	return Number.isSafeInteger(counts.added) && counts.added >= 0
		&& Number.isSafeInteger(counts.removed) && counts.removed >= 0;
}

function isState(value: unknown): value is State {
	if (!value || typeof value !== "object") return false;
	const state = value as State;
	return isCounts(state.turn) && isCounts(state.session);
}

function format(counts: Counts): string {
	const delta = counts.added - counts.removed;
	return `+${counts.added} −${counts.removed} Δ${delta >= 0 ? "+" : "−"}${Math.abs(delta)}`;
}

// Edit metadata uses omp's compact diff (+12|text / -12|text), not a patch header.
function countDiff(diff: string): Counts {
	const counts = { added: 0, removed: 0 };
	for (const line of diff.split("\n")) {
		if (line.startsWith("+")) counts.added++;
		else if (line.startsWith("-")) counts.removed++;
	}
	return counts;
}

async function readText(path: string, missingIsEmpty = false): Promise<string | undefined> {
	try {
		const bytes = await readFile(path);
		if (bytes.includes(0)) return undefined;
		return new TextDecoder("utf-8", { fatal: true }).decode(bytes);
	} catch (error) {
		if (missingIsEmpty && (error as NodeJS.ErrnoException).code === "ENOENT") return "";
		// Unreadable/non-text targets cannot supply an honest line count.
		return undefined;
	}
}

export default function loc(pi: ExtensionAPI) {
	let state = emptyState();
	const writes = new Map<string, { path: string; before: string }>();
	let receiver: Receiver | undefined;
	let receiverKeys: string[] = [];
	let agentId: string | undefined;

	function detach() {
		for (const key of receiverKeys) {
			if (sessions.get(key) === receiver) sessions.delete(key);
		}
		if (agentId && receiver) {
			const peers = agents.get(agentId);
			peers?.delete(receiver);
			if (!peers?.size) agents.delete(agentId);
		}
		receiver = undefined;
		receiverKeys = [];
		agentId = undefined;
	}

	function forward(counts: Counts, ctx: ExtensionContext) {
		if (ctx.agent.kind !== "sub") return;
		const parentSession = ctx.sessionManager.getHeader()?.parentSession;
		let parent = parentSession ? sessions.get(parentSession) : undefined;
		if (!parent && !parentSession && ctx.agent.parentId) {
			// Ephemeral sessions lack parentSession. Never choose arbitrarily between
			// separate SDK trees whose root agents share the same display id.
			const peers = agents.get(ctx.agent.parentId);
			if (peers?.size === 1) parent = peers.values().next().value;
		}
		if (parent && parent !== receiver) parent.accept(counts);
	}

	function add(counts: Counts, ctx: ExtensionContext) {
		if (!counts.added && !counts.removed) return;
		state.turn.added += counts.added;
		state.turn.removed += counts.removed;
		state.session.added += counts.added;
		state.session.removed += counts.removed;
		persist(ctx);
		// Forward deltas, never cumulative child totals or task-result summaries.
		// A descendant therefore reaches every ancestor exactly once.
		forward(counts, ctx);
	}

	function attach(ctx: ExtensionContext) {
		detach();
		receiver = { accept: (counts) => add(counts, ctx) };
		receiverKeys = [ctx.sessionManager.getSessionId()];
		const file = ctx.sessionManager.getSessionFile();
		if (file) receiverKeys.push(file);
		for (const key of receiverKeys) sessions.set(key, receiver);
		agentId = ctx.agent.id;
		let peers = agents.get(agentId);
		if (!peers) agents.set(agentId, peers = new Set());
		peers.add(receiver);
	}

	function publish(ctx: ExtensionContext) {
		ctx.ui.setStatus(STATUS_KEY, `turn ${format(state.turn)} │ session ${format(state.session)}`);
	}

	function persist(ctx: ExtensionContext) {
		// Copy: later mutations must not alter an already-appended entry.
		pi.appendEntry(STATE_TYPE, { turn: { ...state.turn }, session: { ...state.session } });
		publish(ctx);
	}

	function restore(_event: unknown, ctx: ExtensionContext) {
		state = emptyState();
		writes.clear();
		attach(ctx);
		for (const entry of ctx.sessionManager.getBranch()) {
			if (entry.type === "custom" && entry.customType === STATE_TYPE && isState(entry.data)) {
				state = { turn: { ...entry.data.turn }, session: { ...entry.data.session } };
			}
		}
		publish(ctx);
	}

	pi.on("session_start", restore);
	pi.on("session_switch", restore);
	pi.on("session_branch", restore);
	pi.on("session_tree", restore);
	pi.on("session_shutdown", detach);

	pi.on("agent_start", (_event, ctx) => {
		state.turn = { added: 0, removed: 0 };
		writes.clear();
		persist(ctx);
	});

	pi.on("tool_call", async (event, ctx) => {
		if (event.toolName !== "write" || typeof event.input.path !== "string") return;
		const inputPath = event.input.path;
		// Device writes, archives, and database selectors are not plain text files.
		if (inputPath.includes(":")) return;
		const path = resolve(ctx.cwd, inputPath.startsWith("~/") ? resolve(homedir(), inputPath.slice(2)) : inputPath);
		const before = await readText(path, true);
		if (before !== undefined) writes.set(event.toolCallId, { path, before });
	});

	pi.on("tool_result", async (event, ctx) => {
		let counts = { added: 0, removed: 0 };
		if (event.toolName === "edit") {
			const details = event.details as {
				diff?: string;
				perFileResults?: { diff?: string; isError?: boolean }[];
			} | undefined;
			// Multi-file results contain the same diffs as the aggregate: count once.
			if (details?.perFileResults) {
				for (const file of details.perFileResults) {
					if (file.isError || typeof file.diff !== "string") continue;
					const change = countDiff(file.diff);
					counts.added += change.added;
					counts.removed += change.removed;
				}
			} else if (!event.isError && typeof details?.diff === "string") {
				counts = countDiff(details.diff);
			}
		} else if (event.toolName === "write") {
			const write = writes.get(event.toolCallId);
			writes.delete(event.toolCallId);
			if (event.isError || !write) return;
			const after = await readText(write.path);
			if (after === undefined) return;
			for (const change of diffLines(write.before, after)) {
				if (change.added) counts.added += change.count;
				else if (change.removed) counts.removed += change.count;
			}
		} else return;
		add(counts, ctx);
	});

	pi.on("agent_end", (_event, ctx) => publish(ctx));
}
