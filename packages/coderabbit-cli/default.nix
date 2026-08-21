{
  lib,
  stdenvNoCC,
  fetchurl,
  unzip,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "coderabbit-cli";
  version = "0.7.5";

  src = fetchurl {
    url = "https://cli.coderabbit.ai/releases/${finalAttrs.version}/coderabbit-darwin-arm64.zip";
    hash = "sha256-Wt0e3XJpztoBMDv9bNnOax+iBNfdnIm+1BLDZoDK8CA=";
  };

  nativeBuildInputs = [ unzip ];
  sourceRoot = ".";

  installPhase = ''
    runHook preInstall
    install -Dm755 coderabbit $out/bin/coderabbit
    ln -s $out/bin/coderabbit $out/bin/cr
    runHook postInstall
  '';

  meta = {
    description = "AI code review CLI";
    homepage = "https://www.coderabbit.ai/cli";
    license = lib.licenses.unfree;
    platforms = [ "aarch64-darwin" ];
    mainProgram = "coderabbit";
  };
})
