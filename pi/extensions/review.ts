import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const SNAPSHOT = "/Users/mq1/dotfiles/agents/hooks/review-snapshot.sh";
// index変更系gitサブコマンド
const INDEX_WRITE =
  /\bgit\s+(?:-C\s+\S+\s+)?(?:add|commit|restore|stash|reset|checkout|switch|rm|mv|apply|update-index|read-tree|merge|rebase|cherry-pick|revert|pull)\b/;

export default function (pi: ExtensionAPI) {
  pi.on("before_agent_start", async (_event, ctx) => {
    await pi.exec("bash", [SNAPSHOT, ctx.cwd]);
  });

  pi.on("tool_call", async (event, ctx) => {
    if (event.toolName !== "bash") return undefined;
    const command = String(event.input.command ?? "");
    if (!INDEX_WRITE.test(command)) return undefined;
    if (ctx.hasUI && (await ctx.ui.confirm("Allow git index change?", command)))
      return undefined;
    return { block: true, reason: "git index is reserved for human review" };
  });
}
