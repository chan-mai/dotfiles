{
  config,
  lib,
  pkgs,
  ...
}:

let
  dotfiles = "/Users/mq1/dotfiles";
  # リポジトリ内ファイルへの直接リンク, 編集が即時反映
  link = path: config.lib.file.mkOutOfStoreSymlink "${dotfiles}/${path}";
in
{
  imports = [ ../../../modules/home.nix ];

  home.stateVersion = "26.11";

  home.sessionVariables.PNPM_HOME = "$HOME/Library/pnpm";
  home.sessionPath = lib.mkBefore [ "$HOME/Library/pnpm" ];

  home.file = {
    # 1Password SSHエージェント, 空白なしパス
    ".1password/agent.sock".source = config.lib.file.mkOutOfStoreSymlink
      "/Users/mq1/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock";
    "Library/Application Support/com.mitchellh.ghostty/config.ghostty".source =
      link "ghostty/config.ghostty";
  };

  # AACSキーDB導入, 日次更新でfetchurl不可
  home.activation.installAacsKeydb = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    keydb="$HOME/Library/Preferences/aacs/KEYDB.cfg"
    if [ ! -e "$keydb" ]; then
      tmpDir=$(mktemp -d)
      # 配布サイト停止時はactivation継続
      if run ${pkgs.curl}/bin/curl -sSfL --max-time 300 -o "$tmpDir/keydb.zip" \
        "https://fvonline-db.bplaced.net/fv_download.php?lang=jpn"; then
        run ${pkgs.unzip}/bin/unzip -q "$tmpDir/keydb.zip" -d "$tmpDir"
        run mkdir -p "$HOME/Library/Preferences/aacs"
        run mv "$tmpDir/keydb.cfg" "$keydb"
      else
        echo "warning: KEYDB.cfg download failed, skipping" >&2
      fi
      run rm -rf "$tmpDir"
    fi
  '';
}
