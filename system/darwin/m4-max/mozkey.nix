{ pkgs, ... }:

let
  app = "/Library/Input Methods/Mozc.app";
  processes = "Mozc MozcConverter MozcRenderer mozc_zenz_scorer";

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
    mozkey-input-sources = {
      script = ''
        "${app}/Contents/MacOS/Mozc" --register_input_source
        ${pkgs.tisctl}/bin/tisctl disable \
          org.mozc.inputmethod.Japanese.Roman \
          org.mozc.inputmethod.Japanese.Katakana \
          org.mozc.inputmethod.Japanese.HalfWidthKana \
          org.mozc.inputmethod.Japanese.FullWidthRoman \
          com.apple.inputmethod.Kotoeri.RomajiTyping.Japanese \
          com.apple.inputmethod.Kotoeri.RomajiTyping
      '';
      serviceConfig.RunAtLoad = true;
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
    };
}
