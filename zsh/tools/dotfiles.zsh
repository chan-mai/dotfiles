# dotfilesのTaskfileを任意のディレクトリから実行:
#   dotfiles              # dotfilesを編集
#   dotfiles apply
#   dotfiles apply:update
function dotfiles() {
  task --dir "$HOME/dotfiles" "$@"
}
