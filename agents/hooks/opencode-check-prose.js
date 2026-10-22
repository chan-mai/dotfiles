// check-prose.pyのopencodeアダプタ
// session.idle時に最終応答を検査し、違反があればセッションへ差し戻す
import { spawn } from "node:child_process";
import { homedir } from "node:os";
import { join } from "node:path";

const SCRIPT = join(homedir(), "dotfiles/agents/hooks/check-prose.sh");
// 差し戻し文の先頭, 新しいユーザ発言と区別
const MARKER = "応答文検査で違反を検出";

const check = (payload) =>
  new Promise((resolve) => {
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

const toMessages = (rows) => {
  const messages = [];
  for (const { info, parts } of rows) {
    for (const part of parts) {
      if (part.type === "tool") {
        messages.push({ role: "tool" });
      } else if (part.type === "text" && !part.synthetic && !part.ignored) {
        const role =
          info.role === "user" && part.text.startsWith(MARKER)
            ? "feedback"
            : info.role;
        messages.push({ role, text: part.text });
      }
    }
  }
  return messages;
};

export const CheckProse = async ({ client }) => {
  // 同一セッションの多重実行抑止
  const running = new Set();
  return {
    event: async ({ event }) => {
      if (event.type !== "session.idle") return;
      const sessionID = event.properties.sessionID;
      if (running.has(sessionID)) return;
      running.add(sessionID);
      let result = {};
      try {
        const session = await client.session.get({ path: { id: sessionID } });
        // サブエージェントの子セッションは対象外
        if (session.data?.parentID) return;
        const rows = await client.session.messages({ path: { id: sessionID } });
        result = await check({
          hook_event_name: "Stop",
          session_id: `opencode-${sessionID}`,
          messages: toMessages(rows.data ?? []),
        });
      } finally {
        running.delete(sessionID);
      }
      if (result.systemMessage) {
        await client.tui.showToast({
          body: { message: result.systemMessage, variant: "warning" },
        });
      }
      // 書き直し後のsession.idleも検査, 抑止解除後に送信
      if (result.decision === "block" && result.reason) {
        await client.session.prompt({
          path: { id: sessionID },
          body: { parts: [{ type: "text", text: result.reason }] },
        });
      }
    },
  };
};
