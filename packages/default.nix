final: prev: {
  coderabbit-cli = final.callPackage ./coderabbit-cli { };
  codex-custom = final.callPackage ./codex-custom { };
  ja-prose-python = final.callPackage ./ja-prose-python { };
  lucide-icon-theme = final.callPackage ./lucide-icon-theme { };
  mlx-serve = final.callPackage ./mlx-serve { };
  # nixpkgs版vlcとの衝突回避
  vlc-bin = final.callPackage ./vlc { };
}
