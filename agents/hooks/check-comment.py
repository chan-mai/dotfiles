#!/usr/bin/env python3
"""PostToolUse hook: 追加コメント行の再確認依頼

対象はファイル編集ツールで追加されたコメント行
該当行があればexit 2で差し戻し
入力はClaude Code, CodexのPostToolUse形式, CursorのafterFileEdit, stop形式
opencode, piはアダプタがClaude Codeの形式へ変換
CursorはafterFileEditで記録, stopのfollowup_messageで差し戻し
"""

import json
import os
import re
import sys

SLASH = {'.ts', '.tsx', '.js', '.jsx', '.mjs', '.cjs', '.vue', '.rs', '.go', '.java', '.kt', '.swift', '.c', '.h', '.cpp', '.css', '.scss', '.tsp', '.jsonc'}
HASH = {'.py', '.sh', '.zsh', '.bash', '.rb', '.yml', '.yaml', '.toml', '.nix', '.tf'}
DASH = {'.sql', '.lua'}
NAMES = {'Dockerfile': HASH, 'Taskfile': HASH}

# 検査器向け指示, shebang等はコメント扱いしない
DIRECTIVE = re.compile(
	r'@ts-|eslint|oxlint|biome-ignore|prettier-ignore|oxfmt-ignore|istanbul|v8 ignore|c8 ignore'
	r'|noqa|type:\s*ignore|pragma|shellcheck|yaml-language-server|^#!|^#\s*-\*-|<reference\s'
)

PATCH_FILE = re.compile(r'^\*\*\* (Add|Update|Delete) File: (.+)$')
STATE_DIR = os.path.expanduser('~/.cache/check-comment')
MAX = 30


def patterns(path):
	ext = os.path.splitext(path)[1]
	kind = SLASH if ext in SLASH else HASH if ext in HASH else DASH if ext in DASH else None
	if kind is None:
		kind = NAMES.get(os.path.basename(path).split('.')[0])
	if kind is SLASH:
		pats = [re.compile(r'^\s*(//|/\*|\*(?!/))\s*\S'), re.compile(r'\S\s+//\s*\S')]
		if ext == '.vue':
			pats.append(re.compile(r'^\s*<!--'))
		return pats
	if kind is HASH:
		return [re.compile(r'^\s*#\s*\S'), re.compile(r'\S\s+#\s+\S')]
	if kind is DASH:
		return [re.compile(r'^\s*--\s*\S'), re.compile(r'\S\s+--\s+\S')]
	if ext in {'.html', '.md'}:
		return [re.compile(r'^\s*<!--')]
	return []


def comments(path, text):
	pats = patterns(path)
	out = []
	for line in text.splitlines():
		s = line.strip()
		if not s or DIRECTIVE.search(s):
			continue
		if any(p.search(line) for p in pats):
			out.append(s)
	return out


def added(path, old, new):
	before = set(comments(path, old))
	return [(path, c) for c in comments(path, new) if c not in before]


def from_patch(text):
	found = []
	path, old, new = None, [], []
	for line in text.splitlines() + ['*** End Patch']:
		m = PATCH_FILE.match(line)
		if m or line.startswith('*** End Patch'):
			if path:
				found += added(path, '\n'.join(old), '\n'.join(new))
			path, old, new = (m.group(2).strip() if m and m.group(1) != 'Delete' else None), [], []
		elif path and line.startswith('+'):
			new.append(line[1:])
		elif path and line.startswith('-'):
			old.append(line[1:])
	return found


def from_edits(path, edits):
	found = []
	for e in edits or []:
		if isinstance(e, dict):
			found += added(path, e.get('old_string') or '', e.get('new_string') or '')
	return found


def collect(payload):
	inp = payload.get('tool_input') or {}
	if payload.get('tool_name') == 'apply_patch':
		cmd = inp.get('command')
		return from_patch(cmd if isinstance(cmd, str) else '\n'.join(str(c) for c in cmd or []))
	path = inp.get('file_path') or payload.get('file_path') or ''
	if not path:
		return []
	if 'edits' in payload:
		return from_edits(path, payload['edits'])
	if 'edits' in inp:
		return from_edits(path, inp['edits'])
	if 'content' in inp:
		return added(path, '', inp.get('content') or '')
	return added(path, inp.get('old_string') or '', inp.get('new_string') or '')


def message(found):
	lines = [
		'追加したコメントを確認すること。',
		'削除対象: コードから読み取れる内容, 識別子名の言い換え, WHATやHOWの説明, 変更経緯。',
		'残す行はコードコメントの規則(1行, 体言止め, 30文字程度)に合わせる。該当が無ければ変更も返答も不要。',
	]
	lines += [f'- {p}: {c[:160]}' for p, c in found[:MAX]]
	if len(found) > MAX:
		lines.append(f'- ほか{len(found) - MAX}件')
	return '\n'.join(lines)


def state_path(payload):
	key = re.sub(r'[^A-Za-z0-9_-]', '', str(payload.get('conversation_id') or 'default'))
	return os.path.join(STATE_DIR, f'{key}.json')


def cursor_record(payload, found):
	if not found:
		return
	os.makedirs(STATE_DIR, exist_ok=True)
	p = state_path(payload)
	try:
		with open(p, encoding='utf-8') as fh:
			prev = json.load(fh)
	except (OSError, ValueError):
		prev = []
	with open(p, 'w', encoding='utf-8') as fh:
		json.dump(prev + [list(f) for f in found], fh, ensure_ascii=False)


def cursor_stop(payload):
	p = state_path(payload)
	try:
		with open(p, encoding='utf-8') as fh:
			found = [tuple(f) for f in json.load(fh)]
		os.remove(p)
	except (OSError, ValueError):
		found = []
	print(json.dumps({'followup_message': message(found)} if found else {}, ensure_ascii=False))


def self_test():
	cases = [
		('a.ts', '', 'const a = 1; // 初期値\n', 1),
		('a.ts', '', "const u = 'https://example.com';\n", 0),
		('a.ts', '// 既存', '// 既存\nconst a = 1;\n', 0),
		('a.ts', '', '// @ts-expect-error 型定義不足\n', 0),
		('a.ts', '', '/**\n * 件数を取得\n */\n', 2),
		('a.py', '', '#!/usr/bin/env python3\n# 件数を取得\nx = 1\n', 1),
		('a.py', '', "x = '#fff'\n", 0),
		('a.vue', '', '<!-- 一覧 -->\n<div />\n', 1),
		('a.json', '', '{"a": "// x"}\n', 0),
		('a.md', '', '# 見出し\n', 0),
	]
	bad = [c for c in cases if len(added(c[0], c[1], c[2])) != c[3]]
	patch = '*** Begin Patch\n*** Update File: src/a.ts\n@@\n-// 旧\n+// 旧\n+// 件数を取得\n+const n = 1;\n*** Add File: b.py\n+# 初期化\n+x = 1\n*** Delete File: c.ts\n*** End Patch'
	payloads = [
		({'tool_name': 'apply_patch', 'tool_input': {'command': patch}}, 2),
		({'tool_name': 'Edit', 'tool_input': {'file_path': 'a.ts', 'edits': [{'old_string': '', 'new_string': '// x'}]}}, 1),
		({'hook_event_name': 'afterFileEdit', 'file_path': 'a.ts', 'edits': [{'old_string': '', 'new_string': '// x'}]}, 1),
		({'tool_name': 'Write', 'tool_input': {'file_path': 'a.ts', 'content': 'const a = 1;\n'}}, 0),
	]
	bad += [p for p, n in payloads if len(collect(p)) != n]
	print('failed:', bad)
	return 1 if bad else 0


def main():
	if '--test' in sys.argv:
		return self_test()
	try:
		payload = json.load(sys.stdin)
	except Exception:
		return 0
	event = payload.get('hook_event_name')
	if event == 'stop':
		cursor_stop(payload)
		return 0
	found = collect(payload)
	if event == 'afterFileEdit':
		cursor_record(payload, found)
		return 0
	if not found:
		return 0
	print(message(found), file=sys.stderr)
	return 2


if __name__ == '__main__':
	sys.exit(main())
