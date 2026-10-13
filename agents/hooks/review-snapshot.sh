#!/usr/bin/env bash
# 指示送信時作業ツリーをrefs/review/*へ
# 引数: 対象ディレクトリ
set -u

keep=50

cd "${1:-$PWD}" 2>/dev/null || exit 0
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

tmp=$(mktemp -d "${TMPDIR:-/tmp}/review-snapshot.XXXXXX") || exit 0
trap 'rm -rf "$tmp"' EXIT

# 実index非変更, stat情報再利用
cp "$(git rev-parse --git-path index)" "$tmp/index" 2>/dev/null
export GIT_INDEX_FILE="$tmp/index"
git add -A >/dev/null 2>&1 || exit 0
tree=$(git write-tree 2>/dev/null) || exit 0
unset GIT_INDEX_FILE

# 前回と同一内容は省略
[ "$tree" = "$(git rev-parse -q --verify 'refs/review/latest^{tree}' 2>/dev/null)" ] && exit 0

parent=$(git rev-parse -q --verify HEAD 2>/dev/null)
commit=$(git commit-tree --no-gpg-sign "$tree" ${parent:+-p "$parent"} -m "review snapshot") || exit 0

name="refs/review/$(date +%Y%m%d-%H%M%S)-$(git rev-parse --short "$commit")"
git update-ref "$name" "$commit"
git update-ref refs/review/latest "$commit"

git for-each-ref --sort=-refname --format='%(refname)' 'refs/review/2*' |
  tail -n +$((keep + 1)) |
  while read -r ref; do git update-ref -d "$ref"; done

exit 0
