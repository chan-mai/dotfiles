# codex-lbのAPIキーを1Passwordから取得しpiを起動
function pi() {
  CODEX_LB_API_KEY=$(op read "op://Personal/codex-lb-secrets/credential") command pi "$@"
}
