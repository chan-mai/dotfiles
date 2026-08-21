# dotfiles

macOS(nix-darwin + home-manager)の設定レポジトリ

## 構成

```
ghostty/          Ghostty設定
git/              git設定(gitconfig, ignore)
zsh/              zsh設定(zshrc, zshenv, zprofile)
packages/         インストールするパッケージ・フォント一覧
system/darwin/    nix-darwin flake
  _common/        全ホスト共通設定(darwin.nix, home.nix)
  m4-max/         ホスト固有設定
```

ツール設定はhome-managerがホームディレクトリへシンボリックリンクを作成する。リポジトリ内のファイルを編集すると再適用なしで反映される(はず)

## 適用

```sh
sudo darwin-rebuild switch --flake ~/dotfiles/system/darwin#M4-Max
```

新しい.nixファイルを追加した場合、適用前に`git add`すること

## 更新

```sh
cd ~/dotfiles/system/darwin
nix flake update
sudo darwin-rebuild switch --flake ~/dotfiles/system/darwin#M4-Max
```
