# dotfiles

nix-darwin / NixOS + home-managerの設定レポジトリ

## 構成

```
ghostty/          Ghostty設定
git/              git設定(gitconfig, ignore)
hypr/             Hyprland設定(Lua)
nvim/             Neovim設定
zsh/              zsh設定(zshrc, zshenv, zprofile)
modules/          OS共通モジュール
  common.nix      パッケージ・フォント一覧(全OS共通)
  darwin.nix      パッケージ一覧(macOS共通)
  home.nix        home-manager共通設定
  skills.nix      エージェントskill一覧
packages/         自作derivation(overlay)
system/darwin/    nix-darwin flake
  _common/        全ホスト共通設定(darwin.nix, home.nix)
  m4-max/         ホスト固有設定
system/nixos/     NixOS flake
  _common/        全ホスト共通設定(nixos.nix, desktop.nix, home.nix)
  kumo/           ホスト固有設定
```

ツール設定はhome-managerがホームディレクトリへシンボリックリンクを作成する。リポジトリ内のファイルを編集すると再適用なしで反映される(はず)

## 適用

```sh
task apply
```

macOSは`darwin-rebuild`, NixOSは`nixos-rebuild`をホスト名で実行する。新しい.nixファイルを追加した場合、適用前に`git add`すること

## 更新

```sh
task update
```

