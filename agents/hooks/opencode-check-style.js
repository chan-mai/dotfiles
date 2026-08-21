// check-style.pyのopencodeアダプタ
// session.idle時に検査し、違反があればセッションへ差し戻す
const SCRIPT = "/Users/mq1/dotfiles/agents/hooks/check-style.py"

export const CheckStyle = async ({ $, directory, client }) => {
  // 同一指摘の再送抑止
  const reported = new Map()
  return {
    event: async ({ event }) => {
      if (event.type !== "session.idle") return
      const sessionID = event.properties.sessionID
      const r = await $`python3 ${SCRIPT}`.cwd(directory).quiet().nothrow()
      if (r.exitCode !== 2) {
        reported.delete(sessionID)
        return
      }
      const findings = r.stderr.toString().trim()
      if (!findings || reported.get(sessionID) === findings) return
      reported.set(sessionID, findings)
      await client.session.prompt({
        path: { id: sessionID },
        body: { parts: [{ type: "text", text: findings }] },
      })
    },
  }
}
