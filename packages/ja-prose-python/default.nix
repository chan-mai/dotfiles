{
  lib,
  python3,
  writeShellScriptBin,
}:

let
  ps = python3.pkgs;

  ginza = ps.buildPythonPackage rec {
    pname = "ginza";
    version = "5.3.0";
    format = "wheel";
    src = ps.fetchPypi {
      inherit pname version format;
      dist = "py3";
      python = "py3";
      hash = "sha256-Tu3nsPc5C/3TJdOBHmbeWNIfcEccIV7qRX4ETcW3Zq0=";
    };
    dependencies = with ps; [
      plac
      spacy
      sudachipy
      sudachidict-core
    ];
    pythonImportsCheck = [ "ginza" ];
  };

  ja-ginza = ps.buildPythonPackage rec {
    pname = "ja_ginza";
    version = "5.3.0";
    format = "wheel";
    src = ps.fetchPypi {
      inherit pname version format;
      dist = "py3";
      python = "py3";
      hash = "sha256-rGR5qAXFxcI8JwVUk0wcHzRAOVYO86fksVpCdb6jxoU=";
    };
    dependencies = [ ginza ];
  };

  env = python3.withPackages (_: [
    ginza
    ja-ginza
  ]);
in
# python3との衝突回避, 別名で公開
(writeShellScriptBin "ja-prose-python" ''
  exec ${env}/bin/python3 "$@"
'').overrideAttrs
  {
    meta = {
      description = "Python with GiNZA for Japanese prose checks";
      license = lib.licenses.mit;
      mainProgram = "ja-prose-python";
    };
  }
