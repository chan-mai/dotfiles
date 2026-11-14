import { spawn } from "node:child_process";
import { homedir } from "node:os";
import { join } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const SCRIPT = join(homedir(), "dotfiles/agents/hooks/check-comment.py");

type Edit = { oldText?: string; newText?: string };
type Input = { path?: string; content?: string; edits?: Edit[]; oldText?: string; newText?: string };

function check(payload: unknown): Promise<string> {
  return new Promise((resolve) => {
    const p = spawn("python3", [SCRIPT]);
    let err = "";
    p.stderr.on("data", (d) => (err += d));
    p.on("error", () => resolve(""));
    p.on("close", (code) => resolve(code === 2 ? err.trim() : ""));
    p.stdin.end(JSON.stringify(payload));
  });
}

function toPayload(toolName: string, input: Input): unknown {
  if (toolName === "write")
    return { tool_name: "Write", tool_input: { file_path: input.path, content: input.content ?? "" } };
  if (toolName === "edit") {
    const edits = input.edits ?? [{ oldText: input.oldText, newText: input.newText }];
    return {
      tool_name: "Edit",
      tool_input: {
        file_path: input.path,
        edits: edits.map((e) => ({ old_string: e.oldText ?? "", new_string: e.newText ?? "" })),
      },
    };
  }
  return undefined;
}

export default function (pi: ExtensionAPI) {
  pi.on("tool_result", async (event) => {
    if (event.isError) return undefined;
    const payload = toPayload(event.toolName, (event.input ?? {}) as Input);
    if (!payload) return undefined;
    const findings = await check(payload);
    if (!findings) return undefined;
    return {
      content: [...event.content, { type: "text" as const, text: findings }],
      structuredContent: event.structuredContent,
    };
  });
}
