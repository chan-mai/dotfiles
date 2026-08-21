#!/usr/bin/env python3
"""Stop hook: 表記規則の検査

対象はgit差分の追加行と未追跡ファイル
違反があればexit 2でClaudeへ差し戻す(同一ターンの差し戻しは1回)
新しい違反の指摘を受けたらBANNED/PUNCT/COMMENTへパターンを追加する
"""

import json
import os
import re
import subprocess
import sys

EXTS = {
	'.ts', '.tsx', '.js', '.mjs', '.cjs', '.vue', '.md', '.tsp', '.py', '.rs',
	'.go', '.java', '.kt', '.swift', '.rb', '.sh', '.yml', '.yaml', '.toml', '.txt',
}

JP = re.compile(r'[ぁ-んァ-ヶ一-龠]')

# 検査器自身のパターン定義と規則文書を除外
EXCLUDE = re.compile(r'(^|/)agents/(hooks/|AGENTS\.md$)')

# 比喩・擬人化・口語の禁止語(発生した違反で拡充する)
BANNED = [
	('満タン', re.compile(r'満タン')),
	('足す', re.compile(r'(?<![満発不補])足[すしせそ]')),
	('効く', re.compile(r'効[くきいか]')),
	('捨てる', re.compile(r'(?<!切り)捨て')),
	('飛ばす', re.compile(r'(?<!読み)飛ば')),
	('通す', re.compile(r'(?<!見)通[すさせ]')),
	('落とす', re.compile(r'落と')),
	('踏む', re.compile(r'踏[むみまん]')),
	('尽きる', re.compile(r'尽き')),
	('抑える', re.compile(r'抑え')),
	('絞る', re.compile(r'絞')),
	('緩める', re.compile(r'緩[めむま]')),
	('張る', re.compile(r'(?<![拡主緊])張[るりらろれっ]')),
	('壊す', re.compile(r'(?<!破)壊[すさ]')),
	('弾く', re.compile(r'弾[くきかい]')),
	('巻き添え', re.compile(r'巻き添え')),
	('取りこぼし', re.compile(r'取りこぼ')),
	('委ねる', re.compile(r'委ね')),
	('打ち切る', re.compile(r'打ち切')),
	('組み立てる', re.compile(r'組み立て')),
	('要る', re.compile(r'要[るり]')),
	('枝', re.compile(r'枝')),
	('キー無し', re.compile(r'キー無し')),
	('乗る', re.compile(r'乗[るせっ]')),
	('割る', re.compile(r'(?<!日)割[るられ]')),
	('撃つ', re.compile(r'撃')),
	('捌く', re.compile(r'捌')),
	('借りる', re.compile(r'借り')),
	('貼る', re.compile(r'貼(?!り付|り直)')),
	('流す', re.compile(r'流[すしせ]')),
	('番人', re.compile(r'番人')),
	('砦', re.compile(r'砦')),
	('源泉', re.compile(r'源泉')),
	('断る(擬人化)', re.compile(r'断[るら]')),
	('許す(擬人化)', re.compile(r'許[すさせ]')),
	('気付かれない(擬人化)', re.compile(r'気付かれ|気づかれ')),
]

# 読点・括弧・スペース
PUNCT = [
	('従属節の後は「、」', re.compile(r'(ので|ため|であり|れば|なら|るが|たが|いが|うが), ')),
	('全角括弧・全角記号', re.compile(r'[（），：；]')),
]

SPACE = re.compile(r'[ぁ-んァ-ヶ一-龠ー] [A-Za-z0-9`]|[A-Za-z0-9`] [ぁ-んァ-ヶ一-龠ー]')

COMMENT_LINE = re.compile(r'^\s*(//|\*|/\*\*)')
COMMENT = [
	('コメントは体言止め', re.compile(r'(する|しない|できる|できない|される|されない|させる|になる|ならない)(\s*\*/)?\s*$')),
	('コメントに「。」を付けない', re.compile(r'。')),
	('コメントで因果構文を書かない', re.compile(r'(ので|ため)[、,]')),
]


def ok_ext(path):
	if EXCLUDE.search(path):
		return False
	return os.path.splitext(path)[1] in EXTS


def added_lines(cwd):
	lines = []
	try:
		diff = subprocess.run(
			['git', 'diff', 'HEAD', '--unified=0'],
			capture_output=True, text=True, cwd=cwd, timeout=30,
		)
	except Exception:
		return lines
	if diff.returncode != 0:
		return lines
	current = None
	for l in diff.stdout.splitlines():
		if l.startswith('+++ b/'):
			current = l[6:]
		elif l.startswith('+') and not l.startswith('+++'):
			if current and ok_ext(current):
				lines.append((current, l[1:]))
	try:
		ls = subprocess.run(
			['git', 'ls-files', '--others', '--exclude-standard'],
			capture_output=True, text=True, cwd=cwd, timeout=30,
		)
		for f in ls.stdout.splitlines():
			if not ok_ext(f):
				continue
			p = os.path.join(cwd, f)
			try:
				if os.path.getsize(p) > 512 * 1024:
					continue
				with open(p, encoding='utf-8', errors='ignore') as fh:
					for t in fh.read().splitlines():
						lines.append((f, t))
			except OSError:
				pass
	except Exception:
		pass
	return lines


def check(lines):
	findings = []
	for path, text in lines:
		if not JP.search(text):
			continue
		for name, pat in BANNED:
			if pat.search(text):
				findings.append((path, name, text))
		for name, pat in PUNCT:
			if pat.search(text):
				findings.append((path, name, text))
		if not text.lstrip().startswith('|') and 'http' not in text and '@ts-expect-error' not in text and SPACE.search(text):
			findings.append((path, '日本語とASCII間にスペースを入れない', text))
		if COMMENT_LINE.match(text) and not path.endswith('.md'):
			for name, pat in COMMENT:
				if pat.search(text):
					findings.append((path, name, text))
	return findings


def self_test():
	ok = [
		('a.ts', '// readyに現れた未知キーはtokens上限から開始'),
		('a.ts', '// スキップ後のバケットは不変, 回復時刻はここで確定'),
		('a.md', '`Policy`に`perKeyRate`が増えるので、独自にPolicyを構築している利用者は指定が必要になる'),
		('a.md', '| `rate` | `null` | 一定時間あたりの実行数の上限 |'),
		('a.ts', '// 有効にした場合の低下は実測で約17%'),
		('a.md', '`concurrencyKey`がnullのジョブには適用されません。'),
	]
	ng = [
		('a.ts', '// 満タンのキーは含めない'),
		('a.md', 'Policyへ`perKeyRate`を足す'),
		('a.md', 'レート制限はshard全体に効き、キー単位では制限できない'),
		('a.ts', '// 候補を飛ばすだけにする'),
		('a.md', '設定した流量を超えるが, 実害は無い'),
		('a.md', '比例するので, 有界になる'),
		('a.ts', '// 全角括弧（例）を使う'),
		('a.md', 'キャッシュを 100件に制限'),
		('a.ts', '// 出力の正規化で除外する'),
		('a.ts', '// 満杯なら書かない。'),
		('a.ts', '// 反映が遅れるため, 再取得'),
	]
	bad = [t for t in ok if check([t])]
	missed = [t for t in ng if not check([t])]
	print('false positives:', bad)
	print('missed:', missed)
	return 0 if not bad and not missed else 1


def main():
	if '--test' in sys.argv:
		return self_test()
	try:
		payload = json.load(sys.stdin)
	except Exception:
		payload = {}
	# 差し戻しは1ターン1回, 修正不能な行での無限ループを回避
	if payload.get('stop_hook_active'):
		return 0
	cwd = payload.get('cwd') or os.getcwd()
	if not os.path.isdir(os.path.join(cwd, '.git')):
		return 0
	findings = check(added_lines(cwd))
	if not findings:
		return 0
	print('表記規則違反を検出。追加行のうち自分が書いた行を修正すること。', file=sys.stderr)
	print('ユーザが書いた行は修正せず報告にとどめること。', file=sys.stderr)
	for path, name, text in findings[:40]:
		print(f'- [{name}] {path}: {text.strip()[:120]}', file=sys.stderr)
	if len(findings) > 40:
		print(f'- ほか{len(findings) - 40}件', file=sys.stderr)
	return 2


if __name__ == '__main__':
	sys.exit(main())
