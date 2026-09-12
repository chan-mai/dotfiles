{
  lib,
  stdenvNoCC,
  fetchurl,
  undmg,
  makeWrapper,
  jdk17,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "vlc";
  version = "3.0.23";

  src = fetchurl {
    url = "https://download.videolan.org/pub/videolan/vlc/${finalAttrs.version}/macosx/vlc-${finalAttrs.version}-arm64.dmg";
    hash = "sha256-/G+sCNh/U4UX1ErKDF56JEtnyMTLWJv0eDY6cxX9Xg0=";
  };

  nativeBuildInputs = [
    undmg
    makeWrapper
  ];
  sourceRoot = ".";

  installPhase = ''
    runHook preInstall
    mkdir -p $out/Applications
    cp -R VLC.app $out/Applications/
    # BD-JメニューはJava 17必須, JAVA_HOME設定済み起動コマンド
    makeWrapper $out/Applications/VLC.app/Contents/MacOS/VLC $out/bin/vlc \
      --set JAVA_HOME ${jdk17.home}
    runHook postInstall
  '';

  meta = {
    description = "Cross-platform media player";
    homepage = "https://www.videolan.org/vlc/";
    license = lib.licenses.gpl2Plus;
    platforms = [ "aarch64-darwin" ];
    mainProgram = "vlc";
  };
})
