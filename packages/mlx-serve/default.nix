{
  lib,
  stdenvNoCC,
  fetchurl,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "mlx-serve";
  version = "26.10.1";

  src = fetchurl {
    url = "https://github.com/ddalcu/mlx-serve/releases/download/v${finalAttrs.version}/mlx-serve-bin-macos-arm64.tar.gz";
    hash = "sha256-5TBW5IE2T/chiPr+qLPrCusLW3zrzW5ufSa/HOQiOHM=";
  };

  sourceRoot = "mlx-serve-macos-arm64";

  # @executable_path/lib参照, 同一ディレクトリ構成で配置
  installPhase = ''
    runHook preInstall
    mkdir -p $out/libexec/mlx-serve $out/bin
    cp -R mlx-serve lib $out/libexec/mlx-serve/
    ln -s $out/libexec/mlx-serve/mlx-serve $out/bin/mlx-serve
    runHook postInstall
  '';

  meta = {
    description = "MLX inference server for Apple Silicon";
    homepage = "https://github.com/ddalcu/mlx-serve";
    license = lib.licenses.mit;
    platforms = [ "aarch64-darwin" ];
    mainProgram = "mlx-serve";
  };
})
