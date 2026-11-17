{
  lib,
  stdenvNoCC,
  fetchurl,
  xar,
  cpio,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "mozkey";
  version = "1.1.0";

  src = fetchurl {
    url = "https://github.com/koyasi777/mozkey/releases/download/v${finalAttrs.version}/Mozkey_v${finalAttrs.version}_macos_universal.pkg";
    hash = "sha256-Zfx2P2sdIEmQMKGr70Nc6H05fO4hW1jk09B5YfPvk8s=";
  };

  nativeBuildInputs = [
    xar
    cpio
  ];

  unpackPhase = ''
    runHook preUnpack
    xar -xf $src
    zcat Mozc.pkg/Payload | cpio -idm --quiet
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/Library/Input Methods"
    cp -R "Library/Input Methods/Mozc.app" "$out/Library/Input Methods/"
    runHook postInstall
  '';

  # ad-hoc署名維持
  dontFixup = true;

  passthru.configProto = fetchurl {
    url = "https://raw.githubusercontent.com/koyasi777/mozkey/v${finalAttrs.version}/src/protocol/config.proto";
    hash = "sha256-Ga16LJe1avUOQ5e5anvbWCVqayrNv1jpB43SpTkzKHk=";
  };

  meta = {
    description = "Japanese input method based on Mozc with live conversion";
    homepage = "https://github.com/koyasi777/mozkey";
    license = lib.licenses.bsd3;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = lib.platforms.darwin;
  };
})
