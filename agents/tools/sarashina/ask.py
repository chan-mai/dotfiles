#!/usr/bin/env python3
"""Sarashina APIで日本語の文章を生成

引数は指示を書いたファイル, systemプロンプトはsystem.txt
APIキーは1Passwordから取得, 参照先はSARASHINA_OP_REFで変更可
"""

import json
import os
import pathlib
import subprocess
import sys
import urllib.request

OP_REF = 'op://Personal/Sarashina/credential'
D = pathlib.Path(__file__).parent
SYSTEM = (D / 'system.txt').read_text()


def ask(user: str, key: str) -> str:
	body = json.dumps({
		'model': 'sarashina3-mini',
		'messages': [{'role': 'system', 'content': SYSTEM}, {'role': 'user', 'content': user}],
		'temperature': 0.2,
	}).encode()
	req = urllib.request.Request(
		'https://api.sarashina.ai/v1/chat/completions',
		data=body,
		headers={'Authorization': f'Bearer {key}', 'Content-Type': 'application/json'},
	)
	with urllib.request.urlopen(req, timeout=120) as r:
		return json.load(r)['choices'][0]['message']['content']


def read_key() -> str:
	ref = os.environ.get('SARASHINA_OP_REF', OP_REF)
	try:
		r = subprocess.run(['op', 'read', ref], capture_output=True, text=True, timeout=120)
	except (OSError, subprocess.TimeoutExpired) as e:
		print(f'op read failed: {e}', file=sys.stderr)
		return ''
	if r.returncode != 0:
		print(f'op read {ref} failed: {r.stderr.strip()}', file=sys.stderr)
		return ''
	return r.stdout.strip()


def main():
	if len(sys.argv) != 2:
		print('usage: ask.py PROMPT_FILE', file=sys.stderr)
		return 1
	key = read_key()
	if not key:
		return 1
	print(ask(pathlib.Path(sys.argv[1]).read_text(), key))
	return 0


if __name__ == '__main__':
	sys.exit(main())
