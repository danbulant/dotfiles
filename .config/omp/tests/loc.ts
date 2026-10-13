// Run with: omp --no-session --no-extensions --no-tools --no-skills --no-rules
//   --no-lsp --no-title -e .config/omp/tests/loc.ts --mode rpc
// Interactive: load the same file, then run /loc-regression.
// No model requests: real SDK child sessions execute real wrapped write/edit tools.
import type { AgentSession, ExtensionAPI, ExtensionContext, SessionManager } from "@oh-my-pi/pi-coding-agent";
import { strict as assert } from "node:assert";
import { mkdtemp, readFile, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import loc from "../extensions/loc.ts";

export default function regression(pi: ExtensionAPI) {
	async function run(host: ExtensionContext) {
		const dir = await mkdtemp(join(tmpdir(), "omp-loc-regression-"));
		const live: AgentSession[] = [];
		try {
			const prepared = [{ path: "loc-regression", resolvedPath: "loc-regression", factory: loc, error: null }];
			const unexpected = () => { throw new Error("Unexpected regression runtime action"); };
			async function create(id: string, parent?: AgentSession, manager?: SessionManager) {
				const sessionManager = manager ?? (parent
					? await pi.pi.SessionManager.open(join(dir, `${id}.jsonl`), undefined, undefined, {
						initialCwd: dir, parentSession: parent.sessionManager.getSessionFile(),
					})
					: pi.pi.SessionManager.create(dir, join(dir, "sessions")));
				const { session } = await pi.pi.createAgentSession({
					cwd: dir, sessionManager, model: host.model, modelRegistry: host.modelRegistry,
					settings: pi.pi.settings.overlay({
						"memory.backend": "off", "tools.approvalMode": "yolo", "edit.mode": "replace",
					}),
					bindProcessState: false, disableExtensionDiscovery: true, cacheWarming: false,
					preloadedPreparedExtensions: prepared, preloadedCustomToolPaths: [],
					toolNames: ["write", "edit"], restrictToolNames: true,
					enableMCP: false, enableLsp: false, enableIrc: false, skipPythonPreflight: true,
					skills: [], rules: [], contextFiles: [], promptTemplates: [], slashCommands: [],
					agentId: id, parentAgentId: parent?.extensionRunner?.createContext().agent.id,
					parentTaskPrefix: parent ? id : undefined, taskDepth: parent ? 1 : 0,
				});
				live.push(session);
				const runner = session.extensionRunner;
				assert.ok(runner);
				runner.onError((error) => { throw new Error(error.error); });
				runner.initialize({
					sendMessage: unexpected, sendUserMessage: unexpected,
					appendEntry: (customType, data) => sessionManager.appendCustomEntry(customType, data),
					setLabel: unexpected, getActiveTools: () => session.getEnabledToolNames(),
					getAllTools: () => session.getAllToolInfos(), setActiveTools: unexpected,
					getCommands: unexpected, setModel: unexpected, getThinkingLevel: () => session.thinkingLevel,
					setThinkingLevel: unexpected, getSessionName: () => sessionManager.getSessionName(),
					setSessionName: unexpected,
				}, {
					getModel: () => session.model, isIdle: () => !session.isStreaming, abort: unexpected,
					hasPendingMessages: () => false, shutdown: unexpected,
					getContextUsage: () => session.getContextUsage(), compact: unexpected,
					getSystemPrompt: () => session.systemPrompt,
				}, undefined, id === "LocRoot" ? host.ui : undefined);
				await runner.emit({ type: "session_start", reason: "start", previousSessionFile: undefined });
				await runner.emit({ type: "agent_start" });
				return session;
			}
			function expect(session: AgentSession, turn: number[], total: number[]) {
				const entries = session.sessionManager.getBranch();
				const entry = entries.findLast((item) => item.type === "custom" && item.customType === "dan.dotfiles.loc.v1");
				assert.ok(entry?.type === "custom");
				assert.deepEqual(entry.data, {
					turn: { added: turn[0], removed: turn[1] }, session: { added: total[0], removed: total[1] },
				});
			}
			let call = 0;
			async function write(session: AgentSession, path: string, content: string) {
				const tool = session.getToolByName("write");
				assert.ok(tool);
				const result = await tool.execute(`write-${++call}`, { path, content });
				assert.notEqual(result.isError, true);
				assert.equal(await readFile(join(dir, path), "utf8"), content);
			}

			const root = await create("LocRoot");
			const other = await create("LocOther");
			const child = await create("LocChild", root);
			const sibling = await create("LocSibling", root);
			const grandchild = await create("LocGrandchild", child);
			await Promise.all([
				write(child, "child.txt", "first\nsecond\n"),
				write(sibling, "sibling.txt", "sibling\n"),
			]);
			expect(root, [3, 0], [3, 0]);
			expect(other, [0, 0], [0, 0]);
			await write(grandchild, "grandchild.txt", "nested\n");
			expect(root, [4, 0], [4, 0]);
			expect(child, [3, 0], [3, 0]);
			await write(child, "child.txt", "first\nSECOND\n");
			expect(root, [5, 1], [5, 1]);
			expect(child, [4, 1], [4, 1]);
			const edit = grandchild.getToolByName("edit");
			assert.ok(edit);
			const edited = await edit.execute(`edit-${++call}`, { path: "grandchild.txt", old_string: "nested", new_string: "NESTED" });
			assert.notEqual(edited.isError, true);
			assert.equal(await readFile(join(dir, "grandchild.txt"), "utf8"), "NESTED\n");
			expect(root, [6, 2], [6, 2]);
			await root.extensionRunner!.emit({ type: "agent_start" });
			await write(sibling, "sibling.txt", "SIBLING\n");
			expect(root, [1, 1], [7, 3]);
			// Reviving/restoring a child must not replay its old cumulative totals.
			await child.extensionRunner!.emit({ type: "session_start", reason: "start", previousSessionFile: undefined });
			expect(root, [1, 1], [7, 3]);
			await write(child, "child.txt", "first\nSECOND\nthird\n");
			expect(root, [2, 1], [8, 3]);
			await root.extensionRunner!.emit({ type: "session_start", reason: "start", previousSessionFile: undefined });
			expect(root, [2, 1], [8, 3]);
			await write(grandchild, "grandchild.txt", "");
			expect(root, [2, 2], [8, 4]);
			expect(other, [0, 0], [0, 0]);
			// A real close/reopen retains the session totals and reattaches existing children.
			const rootFile = root.sessionManager.getSessionFile();
			assert.ok(rootFile);
			// No model messages were sent, so explicitly materialize this metadata-only session.
			await root.sessionManager.ensureOnDisk();
			await root.dispose();
			const revived = await create("LocRootRevived", undefined, await pi.pi.SessionManager.open(rootFile));
			expect(revived, [0, 0], [8, 4]);
			await write(grandchild, "grandchild.txt", "revived\n");
			expect(revived, [1, 0], [9, 4]);
			// --no-session trees must route via agent identity when no parent file exists.
			const ephemeral = await create("LocEphemeral", undefined, pi.pi.SessionManager.inMemory(dir));
			const ephemeralChild = await create("LocEphemeralChild", ephemeral, pi.pi.SessionManager.inMemory(dir));
			await write(ephemeralChild, "ephemeral.txt", "ephemeral\n");
			expect(ephemeral, [1, 0], [1, 0]);
			await ephemeral.dispose();
			await write(ephemeralChild, "ephemeral.txt", "EPHEMERAL\n");
			expect(ephemeralChild, [2, 1], [2, 1]);
			expect(revived, [1, 0], [9, 4]);
			expect(other, [0, 0], [0, 0]);
			console.log("LOC_SUBAGENT_REGRESSION_OK: actual restricted SDK children, concurrent siblings, nested write/edit, no double counting, turn reset, durable reopen, ephemeral routing, shutdown cleanup, separate-root isolation");
		} finally {
			for (const session of live.reverse()) await session.dispose();
			await rm(dir, { recursive: true, force: true });
		}
	}
	pi.registerCommand("loc-regression", {
		description: "Exercise LoC counters with real SDK child write/edit calls",
		handler: async (_args, ctx) => {
			await run(ctx);
			ctx.ui.notify("LoC subagent regression passed", "info");
		},
	});
	pi.on("session_start", async (_event, host) => {
		if (host.mode !== "rpc") return;
		try {
			await run(host);
			host.shutdown();
		} catch (error) {
			console.error(error);
			process.exit(1);
		}
	});
}
