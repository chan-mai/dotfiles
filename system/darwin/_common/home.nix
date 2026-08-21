{ config, ... }:

let
  dotfiles = "/Users/mq1/dotfiles";
  # リポジトリ内ファイルへの直接リンク, 編集が即時反映
  link = path: config.lib.file.mkOutOfStoreSymlink "${dotfiles}/${path}";
in
{
  home.stateVersion = "26.11";

  home.sessionVariables = {
    # Bitwarden SSHエージェント
    SSH_AUTH_SOCK = "$HOME/.bitwarden-ssh-agent.sock";
    PNPM_HOME = "$HOME/Library/pnpm";
    # nixストアは書き込み不可, npmグローバルは専用ディレクトリ
    NPM_CONFIG_PREFIX = "$HOME/.npm-global";
  };

  home.sessionPath = [
    "$HOME/Library/pnpm"
    "$HOME/.npm-global/bin"
    "$HOME/.local/bin"
  ];

  home.file = {
    # skills実体
    ".claude/skills".source = config.lib.file.mkOutOfStoreSymlink "/Users/mq1/.agents/skills";
    # 共通指示, opencode側はAGENTS.mdとして参照
    ".claude/CLAUDE.md".source = link "agents/AGENTS.md";
    ".claude/settings.json".source = link "claude/settings.json";
    ".zshrc".source = link "zsh/zshrc";
    ".zshenv".source = link "zsh/zshenv";
    ".zprofile".source = link "zsh/zprofile";
    ".gitconfig".source = link "git/gitconfig";
    "Library/Application Support/com.mitchellh.ghostty/config.ghostty".source =
      link "ghostty/config.ghostty";
  };

  xdg.configFile."git/ignore".source = link "git/ignore";
  # ファイル単位リンク, node_modules等の実行時生成物はopencode管理
  xdg.configFile."opencode/AGENTS.md".source = link "agents/AGENTS.md";
  xdg.configFile."opencode/plugins/check-style.js".source = link "agents/hooks/opencode-check-style.js";
  xdg.configFile."opencode/opencode.jsonc".source = link "opencode/opencode.jsonc";
  xdg.configFile."opencode/tui.json".source = link "opencode/tui.json";
}
