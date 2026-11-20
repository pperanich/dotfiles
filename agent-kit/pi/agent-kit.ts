// agent-kit for pi: send each bash, write and edit call through agent-guard,
// the same check Claude Code and Codex run as a PreToolUse hook. Exit 2 blocks
// with the guard's message; any other outcome, including a missing uv, lets the call run.
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { spawn } from "node:child_process";
import { homedir } from "node:os";
import { join } from "node:path";

// agent-guard is installed with `uv tool install --editable` of agent-kit; AGENT_GUARD overrides it.
const GUARD =
  process.env.AGENT_GUARD || join(homedir(), ".local", "bin", "agent-guard");
const TOOLS = new Set(["bash", "write", "edit"]);
const TIMEOUT_MS = 10_000;

function runGuard(
  payload: string,
  cwd: string,
): Promise<{ code: number | null; stderr: string }> {
  return new Promise((resolve) => {
    const child = spawn(GUARD, ["pre-tool", "--harness", "pi"], {
      cwd,
      stdio: ["pipe", "ignore", "pipe"],
    });
    let stderr = "";
    const timer = setTimeout(() => child.kill(), TIMEOUT_MS);
    const done = (code: number | null) => {
      clearTimeout(timer);
      resolve({ code, stderr });
    };
    child.stderr.on("data", (chunk) => (stderr += chunk));
    child.stdin.on("error", () => {});
    child.on("error", () => done(null));
    child.on("close", done);
    child.stdin.end(payload);
  });
}

export default function (pi: ExtensionAPI) {
  pi.on("tool_call", async (event, ctx) => {
    if (!TOOLS.has(event.toolName)) return;
    const payload = JSON.stringify({
      hook_event_name: "PreToolUse",
      tool_name: event.toolName,
      tool_input: event.input,
      cwd: ctx.cwd,
    });
    const { code, stderr } = await runGuard(payload, ctx.cwd);
    if (code === 2) return { block: true, reason: stderr.trim() };
  });
}
