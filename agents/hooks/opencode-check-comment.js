// check-comment.pyのopencodeアダプタ
// ファイル編集ツール実行後に検査, 指摘をツール結果へ追記
import { spawn } from "node:child_process";
import { homedir } from "node:os";
import { join } from "node:path";

const SCRIPT = join(homedir(), "dotfiles/agents/hooks/check-comment.py");

const check = (payload) =>
  new Promise((resolve) => {
    const p = spawn("python3", [SCRIPT]);
    let err = "";
    p.stderr.on("data", (d) => (err += d));
    p.on("error", () => resolve(""));
    p.on("close", (code) => resolve(code === 2 ? err.trim() : ""));
    p.stdin.end(JSON.stringify(payload));
  });

const toPayload = (tool, args) => {
  if (tool === "apply_patch")
    return { tool_name: "apply_patch", tool_input: { command: args.patchText ?? "" } };
  if (tool === "write")
    return { tool_name: "Write", tool_input: { file_path: args.filePath, content: args.content ?? "" } };
  if (tool === "edit")
    return {
      tool_name: "Edit",
      tool_input: { file_path: args.filePath, old_string: args.oldString ?? "", new_string: args.newString ?? "" },
    };
  if (tool === "multiedit")
    return {
      tool_name: "MultiEdit",
      tool_input: {
        file_path: args.filePath,
        edits: (args.edits ?? []).map((e) => ({ old_string: e.oldString ?? "", new_string: e.newString ?? "" })),
      },
    };
  return null;
};

export const CheckComment = async () => ({
  "tool.execute.after": async (input, output) => {
    const payload = toPayload(input.tool, input.args ?? {});
    if (!payload) return;
    const findings = await check(payload);
    if (findings) output.output = `${output.output}\n\n${findings}`;
  },
});
