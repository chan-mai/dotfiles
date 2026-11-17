{ lib, stdenv }:

stdenv.mkDerivation {
  pname = "tisctl";
  version = "0.1.0";

  src = ./tisctl.c;
  dontUnpack = true;

  buildPhase = ''
    runHook preBuild
    $CC -O2 -Wall -Wextra -framework Carbon -o tisctl $src
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 tisctl $out/bin/tisctl
    runHook postInstall
  '';

  meta = {
    description = "List and disable macOS input sources via Text Input Sources API";
    platforms = lib.platforms.darwin;
    mainProgram = "tisctl";
  };
}
