{ pkgs, ... }:

let
  app = "/Library/Input Methods/Mozc.app";
  processes = "Mozc MozcConverter MozcRenderer mozc_zenz_scorer";
  tisctl = "${pkgs.tisctl}/bin/tisctl";

  inputMethod = "org.mozc.inputmethod.Japanese";
  disabledInputSources = [
    "${inputMethod}.Roman"
    "${inputMethod}.Katakana"
    "${inputMethod}.HalfWidthKana"
    "${inputMethod}.FullWidthRoman"
    "com.apple.inputmethod.Kotoeri.RomajiTyping.Japanese"
    "com.apple.inputmethod.Kotoeri.RomajiTyping"
  ];
  matchDisabled = pkgs.lib.concatMapStringsSep " " (id: "-e ${id}") disabledInputSources;

  configDb = pkgs.runCommand "mozkey-config1.db" { nativeBuildInputs = [ pkgs.protobuf ]; } ''
    cp ${pkgs.mozkey.configProto} config.proto
    protoc --proto_path=. --encode=mozc.config.Config config.proto \
      < ${../../../mozkey/config.textproto} > $out
  '';
in
{
  # サーバ探索パスがバイナリ内で固定
  system.activationScripts.extraActivation.text = ''
    mozkeySrc="${pkgs.mozkey}${app}"
    mozkeyDst="${app}"
    if ! /usr/bin/cmp -s "$mozkeySrc/Contents/_CodeSignature/CodeResources" "$mozkeyDst/Contents/_CodeSignature/CodeResources" \
      || ! /usr/bin/cmp -s "$mozkeySrc/Contents/MacOS/Mozc" "$mozkeyDst/Contents/MacOS/Mozc"; then
      /bin/rm -rf "$mozkeyDst"
      /bin/mkdir -p "/Library/Input Methods"
      /bin/cp -R "$mozkeySrc" "$mozkeyDst"
      /bin/chmod -R u+w "$mozkeyDst"
      /usr/bin/killall ${processes} 2>/dev/null || true
    fi
  '';

  launchd.user.agents = {
    mozkey-converter.serviceConfig = {
      Label = "org.mozc.inputmethod.Japanese.Converter";
      Program = "${app}/Contents/Resources/MozcConverter.app/Contents/MacOS/MozcConverter";
      MachServices."org.mozc.inputmethod.Japanese.Converter.session" = true;
      KeepAlive = false;
    };
    mozkey-renderer.serviceConfig = {
      Label = "org.mozc.inputmethod.Japanese.Renderer";
      Program = "${app}/Contents/Resources/MozcRenderer.app/Contents/MacOS/MozcRenderer";
      MachServices."org.mozc.inputmethod.Japanese.Renderer.renderer" = true;
      KeepAlive = false;
    };
  };

  home-manager.users.mq1 =
    { lib, ... }:
    {
      # 設定保存時にMozkeyがファイル置換
      home.activation.installMozkeyConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        mozkeyProfile="$HOME/Library/Application Support/Mozc"
        if ! /usr/bin/cmp -s ${configDb} "$mozkeyProfile/config1.db"; then
          run /bin/mkdir -p -m 700 "$mozkeyProfile"
          run /usr/bin/install -m 600 ${configDb} "$mozkeyProfile/config1.db"
          run /usr/bin/killall ${processes} 2>/dev/null || true
        fi
      '';

      # LaunchAgentからの入力ソース設定書き込みはTCCが拒否されるみたい
      home.activation.setMozkeyInputSources = lib.hm.dag.entryAfter [ "installMozkeyConfig" ] ''
        mozkeySources() { ${tisctl} list | /usr/bin/cut -f1; }
        mozkeyWait() {
          for _ in 1 2 3 4 5 6 7 8 9 10; do
            enabled=$(mozkeySources)
            if /usr/bin/grep -qxF "$@" <<< "$enabled"; then
              [ "$mozkeyWaitFor" = present ] && return 0
            else
              [ "$mozkeyWaitFor" = absent ] && return 0
            fi
            /bin/sleep 1
          done
          return 1
        }

        enabled=$(mozkeySources)
        if ! /usr/bin/grep -qxF -e ${inputMethod} <<< "$enabled"; then
          run "${app}/Contents/MacOS/Mozc" --register_input_source
          [[ -v DRY_RUN ]] || mozkeyWaitFor=present mozkeyWait -e ${inputMethod}.base || true
        fi

        enabled=$(mozkeySources)
        if /usr/bin/grep -qxF ${matchDisabled} <<< "$enabled"; then
          run ${tisctl} disable ${toString disabledInputSources}
          if [[ ! -v DRY_RUN ]] && ! mozkeyWaitFor=absent mozkeyWait ${matchDisabled}; then
            echo "warning: input sources are still enabled; the terminal running the activation needs Full Disk Access" >&2
          fi
        fi
      '';
    };
}
