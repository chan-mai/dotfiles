final: prev: {
  coderabbit-cli = final.callPackage ./coderabbit-cli { };
  mlx-serve = final.callPackage ./mlx-serve { };
  # nixpkgs版vlcとの衝突回避
  vlc-bin = final.callPackage ./vlc { };
}
