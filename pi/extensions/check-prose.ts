import { spawn } from "node:child_process";
import { homedir } from "node:os";
import { join } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const SCRIPT = join(homedir(), "dotfiles/agents/hooks/check-prose.sh");
// 差し戻し文の先頭, 新しいユーザ発言と区別
const MARKER = "応答文検査で違反を検出";

type Result = { decision?: string; reason?: string; systemMessage?: string };
type Message = {
  role: "user" | "assistant" | "feedback" | "tool";
  text?: string;
};

function check(payload: unknown): Promise<Result> {
  return new Promise((resolve) => {
    const p = spawn(SCRIPT);
    let out = "";
    p.stdout.on("data", (d) => (out += d));
    p.on("error", () => resolve({}));
    p.on("close", () => {
      try {
        resolve(out.trim() ? JSON.parse(out) : {});
      } catch {
        resolve({});
      }
    });
    p.stdin.end(JSON.stringify(payload));
  });
}

function textOf(content: unknown): string {
  if (typeof content === "string") return content;
  if (!Array.isArray(content)) return "";
  return content
    .filter((c) => c?.type === "text")
    .map((c) => c.text)
    .join("\n");
}

export default function (pi: ExtensionAPI) {
  pi.on("agent_end", async (_event, ctx) => {
    const messages: Message[] = [];
    for (const entry of ctx.sessionManager.getBranch()) {
      if (entry.type !== "message") continue;
      const m = entry.message as { role: string; content: unknown };
      if (m.role === "user") {
        const text = textOf(m.content);
        messages.push({
          role: text.startsWith(MARKER) ? "feedback" : "user",
          text,
        });
      } else if (m.role === "assistant" && Array.isArray(m.content)) {
        for (const c of m.content) {
          if (c?.type === "text")
            messages.push({ role: "assistant", text: c.text });
          else if (c?.type === "toolCall") messages.push({ role: "tool" });
        }
      } else if (m.role === "toolResult") {
        messages.push({ role: "tool" });
      }
    }
    const result = await check({
      hook_event_name: "Stop",
      session_id: `pi-${ctx.sessionManager.getSessionId()}`,
      messages,
    });
    if (result.systemMessage && ctx.hasUI)
      ctx.ui.notify(result.systemMessage, "warning");
    if (result.decision === "block" && result.reason)
      pi.sendUserMessage(result.reason);
  });
}
