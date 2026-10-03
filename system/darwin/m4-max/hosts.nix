{ pkgs, ... }:

{
  nixpkgs.hostPlatform = "aarch64-darwin";

  # ホスト固有パッケージ
  environment.systemPackages = [
    (pkgs.callPackage ../../../packages/mlx-serve { })
  ];
}
