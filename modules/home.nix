{
  config,
  pkgs,
  ...
}:

let
  dotfiles = "${config.home.homeDirectory}/dotfiles";
  # リポジトリ内ファイルへの直接リンク, 編集が即時反映
  link = path: config.lib.file.mkOutOfStoreSymlink "${dotfiles}/${path}";
  # diffview.nvim保守版フォーク
  diffview-plus = pkgs.vimUtils.buildVimPlugin {
    pname = "diffview-plus";
    version = "0-unstable-2026-10-13";
    src = pkgs.fetchFromGitHub {
      owner = "dlyongemallo";
      repo = "diffview.nvim";
      rev = "5ec4af8064924259f72c27f7d1e051a5bd643edf";
      hash = "sha256-ybPmLOP8MmkToG6oj07z4vzlZNuQkwCQsxFnlW3sQ+0=";
    };
    doCheck = false;
  };
  shepherd-nvim = pkgs.vimUtils.buildVimPlugin {
    pname = "shepherd-nvim";
    version = "0-unstable-2026-07-11";
    src = pkgs.fetchgit {
      url = "https://codeberg.org/SOM38/shepherd.nvim";
      rev = "6f71c4e3d2ab91c2c1adc69957b65df07c26fd03";
      hash = "sha256-qJ2ttlayfAauKxIsNb/QAwkM3oLhj4IbD00IJsrksFo=";
    };
    doCheck = false;
  };
in
{
  imports = [ ./skills.nix ];

  home.sessionVariables = {
    SSH_AUTH_SOCK = "$HOME/.1password/agent.sock";
    # nixストアは書き込み不可, npmグローバルは専用ディレクトリ
    NPM_CONFIG_PREFIX = "$HOME/.npm-global";
  };

  home.sessionPath = [
    "$HOME/.npm-global/bin"
    "$HOME/.local/bin"
  ];

  home.file = {
    # skills実体
    ".claude/skills".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.agents/skills";
    # 共通指示, opencode, pi, Codex側はAGENTS.mdとして参照
    ".claude/CLAUDE.md".source = link "agents/AGENTS.md";
    ".claude/settings.json".source = link "claude/settings.json";
    ".claude/output-styles".source = link "claude/output-styles";
    ".zshrc".source = link "zsh/zshrc";
    ".zshenv".source = link "zsh/zshenv";
    ".zprofile".source = link "zsh/zprofile";
    ".gitconfig".source = link "git/gitconfig";
    ".pi/agent/settings.json".source = link "pi/settings.json";
    ".pi/agent/custom-provider.json".source = link "pi/custom-provider.json";
    ".pi/agent/extensions/review.ts".source = link "pi/extensions/review.ts";
    ".pi/agent/extensions/check-prose.ts".source = link "pi/extensions/check-prose.ts";
    ".pi/agent/AGENTS.md".source = link "agents/AGENTS.md";
    ".codex/AGENTS.md".source = link "agents/AGENTS.md";
    # 応答文検査, 差し戻し上限はcheck-prose.py側で管理
    ".cursor/hooks.json".text = builtins.toJSON {
      version = 1;
      hooks = {
        afterAgentResponse = [ { command = "${dotfiles}/agents/hooks/check-prose.sh"; } ];
        stop = [
          {
            command = "${dotfiles}/agents/hooks/check-prose.sh";
            timeout = 600;
            loop_limit = null;
          }
        ];
      };
    };
  };

  programs.neovim = {
    enable = true;
    withRuby = false;
    withPython3 = false;
    plugins = with pkgs.vimPlugins; [
      catppuccin-nvim
      diffview-plus
      gitsigns-nvim
      nvim-lspconfig
      nvim-treesitter.withAllGrammars
      nvim-web-devicons
      plenary-nvim
      shepherd-nvim
      telescope-fzf-native-nvim
      telescope-nvim
    ];
    initLua = ''require("config")'';
  };
  xdg.configFile."nvim/lua/config".source = link "nvim/lua/config";

  xdg.configFile."git/ignore".source = link "git/ignore";
  # ファイル単位リンク, node_modules等の実行時生成物はopencode管理
  xdg.configFile."opencode/AGENTS.md".source = link "agents/AGENTS.md";
  xdg.configFile."opencode/plugins/check-style.js".source = link "agents/hooks/opencode-check-style.js";
  xdg.configFile."opencode/plugins/check-prose.js".source = link "agents/hooks/opencode-check-prose.js";
  xdg.configFile."opencode/opencode.jsonc".source = link "opencode/opencode.jsonc";
  xdg.configFile."opencode/tui.json".source = link "opencode/tui.json";
}
