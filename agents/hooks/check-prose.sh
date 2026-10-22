#!/bin/sh
# check-prose.pyの起動, 各エージェントのhookから共通利用
# GUIアプリ起動時のPATH欠落対策
PATH="/run/current-system/sw/bin:/etc/profiles/per-user/$USER/bin:$HOME/.nix-profile/bin:$HOME/.local/bin:/nix/var/nix/profiles/default/bin:$PATH"
export PATH
exec "$(command -v ja-prose-python || command -v python3)" "$(dirname "$0")/check-prose.py" "$@"
