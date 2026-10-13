{ pkgs, ... }:

{
  nixpkgs.hostPlatform = "aarch64-darwin";

  # ホスト固有パッケージ
  environment.systemPackages = with pkgs; [
    coderabbit-cli
    mlx-serve
    cargo-audit
    delve
    go-tools
    gopls
    govulncheck
    kubernetes-controller-tools
    playwright-mcp
    redocly
    setup-envtest
    typespec
    worker-build
    # GUI
    appcleaner
    blender
    chatgpt
    cloudflare-warp
    code-cursor
    prismlauncher
    slack
    zed-editor
    zoom-us
  ];
}
