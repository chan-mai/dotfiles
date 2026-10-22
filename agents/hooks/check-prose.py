#!/usr/bin/env python3
"""Stop hook: 応答文の検査

対象は最終応答(最後のツール呼び出し以降のassistant応答本文), 作業途中の報告文は文脈としてのみ利用
入力はClaude Code, CodexのStop hook形式, Cursorのhook形式(afterAgentResponse, stop), またはopencode, pi用の{session_id, messages: [{role, text}]}
1. 表記規則(check-style.pyの定義), LLM常套句, 翻訳調
2. GiNZAによる禁止語と係り受けの検査(ja-prose-python実行時のみ)
3. textlint(preset-ja-technical-writing, preset-ai-words-ja, 設定は../textlint)
4. Sonnetによる文脈欠落の査読(規則はcheck-prose.md)
違反は最終応答を書き直させる(差し戻し6回超過分はユーザへ表示)
検査済みの最終応答と差し戻し回数はセッション単位で記録

手動実行:
  check-prose.py --text FILE   ファイルまたは標準入力(-)の文章を検査
  check-prose.py --scan JSONL  transcript内の全応答を機械検査のみで集計
  check-prose.py --test        自己試験
"""

import fcntl
import hashlib
import importlib.util
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time

HERE = os.path.dirname(os.path.abspath(__file__))
RUBRIC = os.path.join(HERE, 'check-prose.md')
TEXTLINTRC = os.path.join(HERE, '..', 'textlint', 'textlintrc.json')
LOG = os.path.expanduser('~/.cache/check-prose/log.jsonl')
LOG_MAX = 20 * 1024 * 1024
STATE_DIR = os.path.expanduser('~/.cache/check-prose/state')
STATE_KEEP = 2000
LLM_ATTEMPTS = 3

MARKER = '応答文検査'
# Claude Codeの連続継続上限8回未満
MAX_RETRY = 6
# 査読対象とする日本語の最小文字数
MIN_JP_LLM = 1
MODEL = os.environ.get('CHECK_PROSE_MODEL', 'sonnet')
LLM_TIMEOUT = 150
CONTEXT_CHARS = 12000

JP = re.compile(r'[ぁ-んァ-ヶ一-龠]')


def load_check_style():
	spec = importlib.util.spec_from_file_location('check_style', os.path.join(HERE, 'check-style.py'))
	mod = importlib.util.module_from_spec(spec)
	spec.loader.exec_module(mod)
	return mod


STYLE = load_check_style()

# 語の原形で照合, check-style.pyのBANNEDと同じ語
BANNED_LEMMAS = {
	'足す', '効く', '利く', '捨てる', '飛ばす', '通す', '落とす', '踏む', '尽きる', '抑える',
	'絞る', '緩める', '張る', '壊す', '弾く', '委ねる', '打ち切る', '組み立てる', '要る',
	'乗る', '乗せる', '割る', '撃つ', '捌く', '借りる', '貼る', '流す', '断る', '許す',
	'差し込む', '噛ませる', '生やす', '寄せる', '畳む', '剥がす', '潰す', '握る', '拾う',
}
BANNED_NOUN_LEMMAS = {'満タン', '巻き添え', '取りこぼし', '番人', '砦', '源泉'}

# 技術用語の言い換え, 単独の名詞で違反
TERMS = {
	'口': 'エンドポイント, コマンド, ポート, インタフェース',
	'砂場': 'サンドボックス',
	'枝': 'ブランチ',
	'窓': 'ウィンドウ',
	'版': 'バージョン',
}
# 複合語は慣用表現あり, 要判定
TERMS_COMPOUND_OK = {'窓', '版'}
HINT_NOUNS = {
	'画面': 'コンポーネント, ページ等の具体名か',
	'部品': 'コンポーネント等の具体名か',
	'窓口': 'エンドポイント, インタフェースの言い換えか',
	'入口': 'エントリポイント, エンドポイントの言い換えか',
	'入り口': 'エントリポイント, エンドポイントの言い換えか',
	'出口': '出力先, 終了処理の言い換えか',
	'箱': 'コンテナ, サーバ等の言い換えか',
	'器': 'コンテナ, 型等の言い換えか',
	'土台': '基盤, ベースの言い換えか',
}
# 人や物の動きを処理に当てた動詞, 助詞直後のみ要判定
MOTION_VERBS = {
	'拾う', '引く', '通る', '響く', '抜ける', '抜く', '落ちる', '走る', '走らせる', '回す', '回る',
	'投げる', '吐く', '叩く', '刺さる', '刺す', '生える', '流れる', '噛む', '食う', '食べる', '飛ぶ',
	'掴む', '潰れる', '殺す', '死ぬ', '生きる', '育つ', '眠る', '溜まる', '溜める', '詰まる', '絡む',
	'漏れる', '溢れる', '折れる', '割れる', '崩れる', '背負う', '抱える', '担ぐ', '跨ぐ', '触る',
	'当たる', '当てる', '被る', '寄る', '逃がす', '逃げる', '捕まえる', '掬う', '汲む', '撫でる',
	'揉む', '締める', '壊れる', '焼く', '黙る', '崩す', '運ぶ', '住む', '語る', '守る', '届く',
}
MOTION_PARTICLES = {'が', 'を', 'に', 'も', 'は'}

# LLM常套句と翻訳調
FILLER = [
	'と言えるでしょう', 'と言えるだろう', 'と言えます', 'ということになるでしょう',
	'大切なのは', '結論から言うと', '結論として', 'いかがでしたか', 'まとめると', '総じて',
	'非常に重要', '極めて重要', '言うまでもなく', '言うまでもありません', 'まさしく',
	'ここで注目したいのは', '見ていきましょう', '紹介していきます', '解説していきます',
	'深掘り', '掘り下げ', '一概には言えません', 'あくまで一例ですが',
	'正面から', '核心的', '鍵となる', '根本的な', '多角的', '包括的', '総合的', '言語化',
	'について見ていく', 'を探求する', 'に他ならない', 'であることは間違いない',
	'という観点から', 'という側面から', 'することによって', '静かに',
]
FILLER_HINT = ['重要なのは', 'このように', '不可欠', 'ポイントは', 'という点で', 'のではないでしょうか']


PORT = re.compile(r'^\d{2,5}$')
CODE_SPAN = re.compile(r'`[^`\n]+`')
IDENT = re.compile(r'\b(?:[a-z]+[A-Z]\w*|[A-Z][a-z]+[A-Z]\w*|\w+_\w+|\w+\.\w+\(\))')
FENCE = re.compile(r'^\s*(```|~~~)')

# 連用接続の節数, 超過で違反
CHAIN_ERROR = 4
CHAIN_HINT = 3


# ---- transcript ----

def _text_of(content):
	if isinstance(content, str):
		return content
	parts = []
	for b in content or []:
		if isinstance(b, dict) and b.get('type') == 'text':
			parts.append(b.get('text', ''))
	return '\n'.join(parts)


def _is_tool_result(content):
	return isinstance(content, list) and any(isinstance(b, dict) and b.get('type') == 'tool_result' for b in content)


def _codex_event(d):
	"""Codexのrollout行, 対象外はNone"""
	if d.get('type') != 'response_item':
		return None
	p = d.get('payload') or {}
	t = p.get('type')
	if t in ('function_call', 'custom_tool_call', 'local_shell_call', 'tool_search_call', 'web_search_call'):
		return ('tool', '')
	if t != 'message' or p.get('role') not in ('user', 'assistant'):
		return None
	text = '\n'.join(c.get('text', '') for c in p.get('content') or [] if isinstance(c, dict) and c.get('type') in ('input_text', 'output_text')).strip()
	# 環境情報等の自動挿入メッセージは除外
	if not text or (p['role'] == 'user' and text.startswith('<')):
		return None
	return (p['role'], text)


def read_transcript(path):
	"""(kind, text)の列, kindはuser / feedback / assistant / tool, Claude Code, Codex, Cursorの形式に対応"""
	events = []
	try:
		fh = open(path, encoding='utf-8', errors='ignore')
	except OSError:
		return events
	seen = set()
	with fh:
		for line in fh:
			try:
				d = json.loads(line)
			except ValueError:
				continue
			if not isinstance(d, dict) or d.get('isSidechain'):
				continue
			if 'payload' in d:
				ev = _codex_event(d)
				if ev:
					events.append(ev)
				continue
			# Cursorはroleで発言者を表す
			t = d.get('type') or d.get('role')
			msg = d.get('message') or {}
			content = msg.get('content')
			if t == 'user':
				if _is_tool_result(content):
					events.append(('tool', ''))
					continue
				text = _text_of(content)
				if d.get('isMeta'):
					if text.startswith('Stop hook feedback:'):
						events.append(('feedback', text))
					continue
				if text.lstrip().startswith(('<local-command', '<command-name>', '<task-notification>')):
					continue
				text = re.sub(r'<system-reminder>.*?</system-reminder>', '', text, flags=re.S).strip()
				query = re.search(r'<user_query>(.*?)</user_query>', text, flags=re.S)
				if query:
					text = query.group(1).strip()
				# Cursor, opencode, piの差し戻しは利用者の発言として記録
				if text.startswith(f'{MARKER}で違反を検出'):
					events.append(('feedback', text))
				elif text:
					events.append(('user', text))
			elif t == 'assistant':
				for b in content or []:
					if not isinstance(b, dict):
						continue
					if b.get('type') == 'tool_use':
						events.append(('tool', ''))
					elif b.get('type') == 'text' and b.get('text', '').strip():
						key = (msg.get('id'), b['text'])
						if key in seen:
							continue
						seen.add(key)
						events.append(('assistant', b['text']))
	return events


def read_messages(messages):
	"""opencode, pi用, [{role, text}]を(kind, text)の列へ"""
	events = []
	for m in messages or []:
		if not isinstance(m, dict):
			continue
		role, text = m.get('role'), (m.get('text') or '').strip()
		if role == 'tool':
			events.append(('tool', ''))
		elif role in ('user', 'assistant', 'feedback') and text:
			events.append((role, text))
	return events


def text_key(text):
	return hashlib.sha1(text.strip().encode('utf-8')).hexdigest()


def split_final(events, last=None):
	"""(最終応答, ユーザ発言のキー, 文脈)"""
	last_user = max((i for i, e in enumerate(events) if e[0] == 'user'), default=-1)
	turn = text_key(f'{last_user}:{events[last_user][1]}') if last_user >= 0 else None
	# 最終応答は最後のユーザ発言, 差し戻し, ツール呼び出しより後の応答
	start = max((i for i, e in enumerate(events) if e[0] in ('user', 'feedback', 'tool')), default=-1) + 1
	if isinstance(last, str) and last.strip():
		final = last.strip()
	else:
		final = '\n\n'.join(e[1] for e in events[start:] if e[0] == 'assistant')
	# 新しい順に文脈を集め、上限内で古い順へ戻す
	ctx, size = [], 0
	for kind, text in reversed(events[:start]):
		if kind in ('feedback', 'tool'):
			continue
		label = 'ユーザ' if kind == 'user' else 'エージェント'
		chunk = f'[{label}]\n{text[-4000:]}'
		if size + len(chunk) > CONTEXT_CHARS:
			break
		ctx.append(chunk)
		size += len(chunk)
	return final, turn, '\n\n'.join(reversed(ctx))


# ---- 前処理 ----

def prose_lines(text):
	"""コードブロック, 引用行, URLを除外した本文行"""
	out, fenced = [], False
	for line in text.splitlines():
		if FENCE.match(line):
			fenced = not fenced
			continue
		if fenced or line.lstrip().startswith('>'):
			continue
		line = re.sub(r'https?://\S+', 'URL', line)
		if line.lstrip().startswith('|'):
			if re.fullmatch(r'\s*\|[\s:|-]+\|\s*', line):
				continue
			out.extend(c.strip() for c in line.strip().strip('|').split('|'))
			continue
		out.append(re.sub(r'^\s*(#+|[-*+]|\d+\.)\s+', '', line))
	return [l for l in out if l.strip()]


def mask(line):
	"""インラインコードと「」引用を名詞のプレースホルダへ置換"""
	line = CODE_SPAN.sub('CODE', line)
	return re.sub(r'「[^」]*」|"[^"\n]*"', '「Q」', line)


def sentences(lines):
	out = []
	for line in lines:
		for s in re.split(r'(?<=[。！？!?])', line):
			s = s.strip()
			if s and JP.search(s):
				out.append(s)
	return out


# ---- 機械検査 ----

class Finding:
	def __init__(self, rule, quote, note='', sure=True):
		self.rule, self.quote, self.note, self.sure = rule, quote, note, sure

	def line(self):
		note = f' ({self.note})' if self.note else ''
		return f'[{self.rule}] {self.quote[:80]}{note}'


def check_style_rules(lines):
	out = []
	for raw in lines:
		text = mask(raw)
		if not JP.search(text):
			continue
		for name, pat in STYLE.PUNCT:
			if pat.search(text):
				out.append(Finding(name, raw.strip()))
		# 「は create, update」形式の列挙は許容
		if STYLE.SPACE.search(text) and not re.search(r'[A-Za-z0-9`]+(, | / )[A-Za-z0-9`]', text):
			out.append(Finding('日本語とASCII間にスペースを入れない', raw.strip()))
	return out


def check_filler(sents):
	out = []
	for s in sents:
		m = mask(s)
		for w in FILLER:
			if w in m:
				out.append(Finding(f'定型句: {w}', s, '中身のない定型句, 内容をそのまま書く'))
		for w in FILLER_HINT:
			if w in m:
				out.append(Finding(f'要判定: {w}', s, '中身のない定型句か', sure=False))
	return out


def check_regex(sents):
	"""GiNZA無し環境用"""
	out = []
	for s in sents:
		m = mask(s)
		for name, pat in STYLE.BANNED:
			if pat.search(m):
				out.append(Finding(f'禁止語: {name}', s))
	return out


def _predicate(t):
	return t.pos_ in ('VERB', 'ADJ') or (t.pos_ == 'NOUN' and any(c.dep_ in ('aux', 'cop') for c in t.children))


def _chain(doc):
	"""連用中止, て形で接続された節数"""
	n = 1
	for t in doc:
		if t.dep_ not in ('advcl', 'conj') or not _predicate(t):
			continue
		tail = [c for c in t.children if c.i > t.i and c.dep_ in ('mark', 'aux')]
		last = max(tail, key=lambda c: c.i) if tail else t
		nxt = doc[last.i + 1] if last.i + 1 < len(doc) else None
		# 読点で区切られた連用中止とて形のみ, 「〜になり」等の補語は対象外
		if nxt is None or nxt.orth_ != '、':
			continue
		if '連用形' in str(last.morph.get('Inflection')) or last.orth_ in ('て', 'で'):
			n += 1
	return n


def check_ginza(nlp, sents):
	out = []
	for s in sents:
		doc = nlp(mask(s))
		for t in doc:
			lem = t.lemma_
			if t.pos_ in ('VERB', 'ADJ', 'AUX') and lem in BANNED_LEMMAS:
				out.append(Finding(f'禁止語: {lem}', s, '比喩的な動詞, 動作をそのまま書く'))
			elif lem in ('気付く', '気づく') and any(x.lemma_ in ('れる', 'られる') for x in doc[t.i + 1:t.i + 3]):
				out.append(Finding('禁止語: 気付かれない(擬人化)', s))
			elif t.pos_ == 'VERB' and lem in MOTION_VERBS and t.i > 0 and doc[t.i - 1].orth_ in MOTION_PARTICLES:
				out.append(Finding(f'要判定: {doc[t.i - 1].orth_}{lem}', s, '動きの比喩か, 何が起きるか分かるか', sure=False))
			# 「難しいです」型, 前後から孤立した文の兆候
			if t.tag_.startswith('形容詞') and t.i + 1 < len(doc) and doc[t.i + 1].orth_ == 'です':
				out.append(Finding(f'要判定: {t.orth_}です', s, '文が前後から孤立していないか', sure=False))
			if not t.tag_.startswith('名詞'):
				continue
			if lem in BANNED_NOUN_LEMMAS:
				out.append(Finding(f'禁止語: {lem}', s))
			elif lem in TERMS and len(doc) > 1:
				prev = doc[t.i - 1] if t.i > 0 else None
				compound = prev is not None and prev.idx + len(prev.orth_) == t.idx and prev.pos_ in ('NOUN', 'PROPN', 'NUM')
				if compound and lem in TERMS_COMPOUND_OK:
					out.append(Finding(f'要判定: {prev.orth_}{lem}', s, f'{TERMS[lem]}の言い換えか', sure=False))
				else:
					out.append(Finding(f'用語の言い換え: {lem}', s, TERMS[lem]))
			elif lem in HINT_NOUNS:
				out.append(Finding(f'要判定: {lem}', s, HINT_NOUNS[lem], sure=False))
			elif len(t.orth_) > 1 and t.orth_.endswith('口') and t.orth_ not in ('人口', '利口', '窓口'):
				out.append(Finding(f'要判定: {t.orth_}', s, '仕組みを場所にたとえた名詞か', sure=False))
			elif t.pos_ == 'NUM' and PORT.match(t.orth_) and t.dep_ in ('nsubj', 'obj', 'obl') and 80 <= int(t.orth_) <= 65535:
				nxt = doc[t.i + 1] if t.i + 1 < len(doc) else None
				if nxt is not None and nxt.pos_ == 'ADP':
					out.append(Finding(f'要判定: {t.orth_}', s, 'ポート番号でサーバを指しているか', sure=False))
		# 括弧内の列挙は節に数えない
		bare = re.sub(r'\([^()]*\)', '', mask(s))
		n = _chain(nlp(bare) if bare != mask(s) else doc)
		if n >= CHAIN_ERROR:
			out.append(Finding('抽象度の混在: 連用接続の節が多い', s, f'{n}節, 1文1主張へ分割'))
		elif n >= CHAIN_HINT:
			out.append(Finding('要判定: 連用接続', s, f'{n}節, 各節の主語と対象が分かるか', sure=False))
	return out


def check_detail_first(lines):
	"""冒頭文の識別子"""
	for raw in lines:
		if not JP.search(raw):
			continue
		first = re.split(r'(?<=[。！？])', raw)[0]
		n = len(CODE_SPAN.findall(first)) + len(IDENT.findall(CODE_SPAN.sub('', first)))
		if n >= 2:
			return [Finding('要判定: 冒頭から識別子', first, f'識別子{n}個, 結論と動機より前に詳細を述べていないか', sure=False)]
		return []
	return []


_NLP = False


def nlp():
	global _NLP
	if _NLP is False:
		try:
			import spacy
			_NLP = spacy.load('ja_ginza')
		except Exception:
			_NLP = None
	return _NLP


# 違反扱い, それ以外は要判定
TEXTLINT_SURE = {
	'ja-technical-writing/no-mix-dearu-desumasu',
	'ja-technical-writing/ja-no-redundant-expression',
	'ja-technical-writing/no-double-negative-ja',
	'ja-technical-writing/no-dropping-the-ra',
	'ja-technical-writing/no-doubled-conjunctive-particle-ga',
	'ja-technical-writing/no-doubled-conjunction',
	'ja-technical-writing/arabic-kanji-numbers',
	'ja-technical-writing/no-hankaku-kana',
	'ja-technical-writing/no-nfd',
	'ja-technical-writing/no-zero-width-spaces',
	'ja-technical-writing/no-invalid-control-character',
}
# 正当な語, またはGiNZA側で検出済みの語
TEXTLINT_SKIP = {
	f'ai-words-ja/no-ai-words:"{w}"' for w in ('効く', '検査', '照合', '部品', '入口', '静かに', '壊れる', '走る', '焼く', '黙って', '崩す')
}


def check_textlint(text):
	exe = shutil.which('textlint')
	if not exe:
		return []
	try:
		r = subprocess.run(
			[exe, '--config', TEXTLINTRC, '--stdin', '--stdin-filename', 'response.md', '--format', 'json'],
			input=text, capture_output=True, text=True, timeout=60,
		)
		results = json.loads(r.stdout or '[]')
	except (subprocess.TimeoutExpired, OSError, ValueError):
		return []
	lines = text.splitlines()
	out = []
	for res in results:
		for m in res.get('messages', []):
			rule = m.get('ruleId', '')
			msg = re.sub(r'\s+', ' ', m.get('message', '')).strip()
			word = re.match(r'"[^"]+"', msg)
			if word and f'{rule}:{word.group(0)}' in TEXTLINT_SKIP:
				continue
			line = lines[m['line'] - 1].strip() if 0 < m.get('line', 0) <= len(lines) else ''
			name = rule.split('/')[-1]
			sure = rule in TEXTLINT_SURE
			out.append(Finding(f'{"" if sure else "要判定: "}textlint {name}', line, msg[:120], sure=sure))
	return out


def mechanical(text):
	lines = prose_lines(text)
	sents = sentences(lines)
	found = check_style_rules(lines) + check_detail_first(lines) + check_filler(sents)
	model = nlp()
	found += check_ginza(model, sents) if model else check_regex(sents)
	found += check_textlint(text)
	uniq, keys = [], set()
	for f in found:
		k = (f.rule, f.quote)
		if k not in keys:
			keys.add(k)
			uniq.append(f)
	return uniq


# ---- LLM査読 ----

SCHEMA = {
	'type': 'object',
	'properties': {
		'violations': {
			'type': 'array',
			'items': {
				'type': 'object',
				'properties': {
					'quote': {'type': 'string'},
					'rule': {'type': 'string', 'enum': [
						'term', 'calque', 'personify', 'colloquial', 'context', 'detail-first', 'motive',
						'mechanism', 'procedure', 'mixed-level', 'syntax', 'nominal', 'vague', 'compressed', 'filler',
					]},
					'problem': {'type': 'string'},
					'fix': {'type': 'string'},
				},
				'required': ['quote', 'rule', 'problem', 'fix'],
			},
		},
	},
	'required': ['violations'],
}

RULE_NAMES = {
	'term': '用語の言い換え', 'calque': '英語の直訳', 'personify': '擬人化と動きの比喩',
	'colloquial': '話し言葉', 'context': '文脈の省略', 'detail-first': '詳細の先行',
	'motive': '動機の欠落', 'mechanism': '因果の仕組みの省略', 'procedure': '手続きの列挙',
	'mixed-level': '抽象度の混在', 'syntax': '係り受け', 'nominal': '動作の名詞化',
	'vague': '曖昧化', 'compressed': '過度の圧縮', 'filler': '中身のない定型句と演出',
}


def strip_fences(text):
	out, fenced = [], False
	for line in text.splitlines():
		if FENCE.match(line):
			if not fenced:
				out.append('[コードブロック省略]')
			fenced = not fenced
			continue
		if not fenced:
			out.append(line)
	return '\n'.join(out)


def llm_review(target, context, found):
	claude = shutil.which('claude') or os.path.expanduser('~/.local/bin/claude')
	if not os.path.exists(claude):
		return None, 'claude not found'
	try:
		with open(RUBRIC, encoding='utf-8') as fh:
			system = fh.read()
	except OSError as e:
		return None, str(e)
	mech = '\n'.join(('確定 ' if f.sure else '要判定 ') + f.line() for f in found) or 'なし'
	prompt = (
		f'## 会話の文脈(古い順)\n\n{context or "なし"}\n\n'
		f'## 機械検査の結果\n\n{mech}\n\n'
		f'## 査読対象の応答文\n\n{strip_fences(target)}\n'
	)
	cmd = [
		claude, '-p', '--model', MODEL, '--effort', 'medium',
		'--output-format', 'json', '--json-schema', json.dumps(SCHEMA),
		'--tools', '', '--setting-sources', '', '--settings', '{"disableAllHooks":true}',
		'--no-session-persistence', '--system-prompt', system,
	]
	env = dict(os.environ, CHECK_PROSE_CHILD='1')
	err = None
	for _ in range(LLM_ATTEMPTS):
		# プロジェクトのCLAUDE.md読込回避
		with tempfile.TemporaryDirectory() as cwd:
			try:
				r = subprocess.run(cmd, input=prompt, capture_output=True, text=True, timeout=LLM_TIMEOUT, cwd=cwd, env=env)
			except (subprocess.TimeoutExpired, OSError) as e:
				err = type(e).__name__
				continue
		try:
			out = json.loads(r.stdout)
			return out['structured_output']['violations'], None
		except (ValueError, KeyError, TypeError):
			err = f'bad output: rc={r.returncode} {r.stderr.strip()[:200]}'
	return None, err


# ---- 出力 ----

def log(record):
	try:
		os.makedirs(os.path.dirname(LOG), exist_ok=True)
		# 上限超過で古い半分を削除
		if os.path.exists(LOG) and os.path.getsize(LOG) > LOG_MAX:
			with open(LOG, encoding='utf-8') as fh:
				rows = fh.readlines()
			with open(LOG, 'w', encoding='utf-8') as fh:
				fh.writelines(rows[len(rows) // 2:])
		with open(LOG, 'a', encoding='utf-8') as fh:
			fh.write(json.dumps(record, ensure_ascii=False) + '\n')
	except OSError:
		pass


def findings_lines(sure, violations):
	lines, grouped = [], {}
	for f in sure:
		grouped.setdefault(f.quote, []).append(f.rule + (f' ({f.note})' if f.note else ''))
	for quote, rules in grouped.items():
		lines.append(f'- 「{quote[:100]}」: ' + ' / '.join(rules))
	for v in violations:
		lines.append(f'- [{RULE_NAMES.get(v["rule"], v["rule"])}] 「{v["quote"]}」: {v["problem"]} → {v["fix"]}')
	return lines


def report(sure, violations):
	head = [
		f'{MARKER}で違反を検出。指摘箇所をすべて書き直した最終応答を、改めて全文出力すること。',
		'書き直しでは結論, 動機, 振る舞い, 詳細の順に書き、技術用語は正式名称を使うこと。',
	]
	return '\n'.join(head + findings_lines(sure, violations))


def audit(target, context, use_llm=True):
	found = mechanical(target)
	sure = [f for f in found if f.sure]
	violations, err, elapsed = [], None, 0.0
	if use_llm and len(JP.findall(target)) >= MIN_JP_LLM:
		start = time.time()
		res, err = llm_review(target, context, found)
		elapsed = round(time.time() - start, 1)
		violations = res or []
	return found, sure, violations, err, elapsed


class State:
	"""セッション単位の検査済み応答, 並列hook間で排他"""

	def __init__(self, session):
		os.makedirs(STATE_DIR, exist_ok=True)
		name = re.sub(r'[^A-Za-z0-9_-]', '_', session or 'unknown')
		self.path = os.path.join(STATE_DIR, f'{name}.json')
		self.fh = open(self.path, 'a+', encoding='utf-8')
		fcntl.flock(self.fh, fcntl.LOCK_EX)
		self.fh.seek(0)
		try:
			data = json.loads(self.fh.read() or '{}')
		except ValueError:
			data = {}
		data = data if isinstance(data, dict) else {}
		self.keys = data.get('keys', [])
		# ユーザ発言単位のStop差し戻し回数
		self.turn = data.get('turn')
		self.stops = data.get('stops', 0)
		# Cursor用, afterAgentResponseで受けた最終応答
		self.pending = data.get('pending')

	def retries(self, turn):
		return self.stops if self.turn == turn else 0

	def blocked(self, turn):
		self.stops = self.retries(turn) + 1
		self.turn = turn

	def add(self, texts):
		self.keys.extend(text_key(t) for t in texts)
		self.keys = self.keys[-STATE_KEEP:]
		self.save()

	def save(self):
		self.fh.seek(0)
		self.fh.truncate()
		self.fh.write(json.dumps({'keys': self.keys, 'turn': self.turn, 'stops': self.stops, 'pending': self.pending}, ensure_ascii=False))
		self.fh.flush()

	def close(self):
		fcntl.flock(self.fh, fcntl.LOCK_UN)
		self.fh.close()


def emit(obj):
	print(json.dumps(obj, ensure_ascii=False))


def run_hook():
	try:
		payload = json.load(sys.stdin)
	except ValueError:
		payload = {}
	# 入れ子のclaude -p, サブエージェントの終了は対象外
	if os.environ.get('CHECK_PROSE_CHILD') or payload.get('agent_id'):
		return 0
	event = payload.get('hook_event_name', 'Stop')
	if event not in ('Stop', 'stop', 'afterAgentResponse'):
		return 0
	cursor = event != 'Stop'
	session = f'cursor-{payload.get("conversation_id")}' if cursor else payload.get('session_id')
	state = State(session)
	try:
		# Cursorはstopに本文が無い, afterAgentResponseの本文を保存
		if event == 'afterAgentResponse':
			state.pending = payload.get('text')
			state.save()
			return 0
		if cursor:
			if payload.get('status') != 'completed':
				return 0
			payload['last_assistant_message'] = state.pending
		return _run_hook(payload, state, cursor)
	finally:
		state.close()


def _run_hook(payload, state, cursor=False):
	if 'messages' in payload:
		events = read_messages(payload['messages'])
	else:
		events = read_transcript(payload.get('transcript_path') or '')
	final, turn, context = split_final(events, payload.get('last_assistant_message'))
	if not JP.search(final) or text_key(final) in state.keys:
		return 0
	retries = state.retries(turn)
	use_llm = os.environ.get('CHECK_PROSE_LLM', '1') != '0'
	found, sure, violations, err, elapsed = audit(final, context, use_llm)
	state.add([final])
	log({
		'time': time.strftime('%Y-%m-%dT%H:%M:%S'), 'session': payload.get('session_id'),
		'cwd': payload.get('cwd'), 'retry': retries, 'chars': len(final), 'llm_sec': elapsed,
		'llm_error': err, 'mechanical': [[f.rule, f.quote, f.sure] for f in found],
		'violations': violations, 'target': final,
	})
	# Cursorのstopは警告表示の出力項目なし
	warn = f'{MARKER}: Sonnetの査読に失敗 ({err})' if err and not cursor else None
	if not sure and not violations:
		if warn:
			emit({'systemMessage': warn})
		return 0
	if retries >= MAX_RETRY:
		# 差し戻し上限, 残った違反をユーザへ表示
		if not cursor:
			emit({'systemMessage': '\n'.join([f'{MARKER}: 差し戻し{retries}回後も違反が残っています'] + findings_lines(sure, violations))})
		return 0
	state.blocked(turn)
	state.save()
	if cursor:
		emit({'followup_message': report(sure, violations)})
		return 0
	out = {'decision': 'block', 'reason': report(sure, violations)}
	if warn:
		out['systemMessage'] = warn
	emit(out)
	return 0


def run_text(path, use_llm):
	text = sys.stdin.read() if path == '-' else open(path, encoding='utf-8').read()
	found, sure, violations, err, elapsed = audit(text, '', use_llm)
	for f in found:
		print(('NG ' if f.sure else '?  ') + f.line())
	for v in violations:
		print(f'LLM [{v["rule"]}] {v["quote"]}: {v["problem"]} -> {v["fix"]}')
	if err:
		print(f'llm error: {err}', file=sys.stderr)
	if use_llm:
		print(f'llm: {elapsed}s', file=sys.stderr)
	return 1 if sure or violations else 0


def run_scan(paths):
	"""機械検査のみ, 規則別の件数"""
	counts, total = {}, 0
	for p in paths:
		for kind, text in read_transcript(p):
			if kind != 'assistant' or not JP.search(text):
				continue
			total += 1
			for f in mechanical(text):
				key = f.rule.split(':')[0] + (': ' + f.rule.split(': ')[1] if f.rule.startswith(('禁止語', '用語', '要判定')) and ': ' in f.rule else '')
				counts.setdefault(key, []).append(f.quote)
	print(f'responses: {total}')
	for k, qs in sorted(counts.items(), key=lambda kv: -len(kv[1])):
		print(f'{len(qs):5d} {k}')
		for q in qs[:3]:
			print(f'        {q[:100]}')
	return 0


def self_test():
	if not nlp():
		print('skip: GiNZA unavailable, run with ja-prose-python')
		return 0
	ok = [
		'〇〇データを登録するAPIエンドポイント(POST /api/hogehoge)が必要です',
		'日本語版を選択しました。',
		'入口で入力値を検証します。',
		'対象は create, update, delete です。',
		'`check-latest: true`を付けると、CIは毎回最新のパッチバージョンを使います。',
		'設定ファイルを読み込んでから、サーバを起動します。',
		'読み飛ばす処理は不要です。',
		'共通する処理を関数にまとめました。',
		'有効かどうかを確認します。',
		'ユーザは「口」という表現を避けるよう指示しています。',
		'読み取り専用になるため、変更するたびに`task apply`が必要になり、`git config --global`での書き込みはできなくなります。',
	]
	ng = [
		'入れる口が要ります。',
		'受け取る口を足し、ハンドラを差し込むことで検証が要り、キャッシュが効きます。',
		'版を0.9.0へ更新しました。',
		'別の枝で作業します。',
		'砂場で実行します。',
		'窓は短いですが、問題になります。',
		'設定が反映されるため, 再起動します。',
		'全角括弧（例）を使います。',
		'キャッシュを 100件に制限します。',
		'ファイルを読み、内容を解析し、結果を整形し、標準出力へ書き込みます。',
	]
	hint = [
		'共通部品にまとめます。',
		'8080が応答しません。',
		'`FooHandler`の`barContext`がnullのとき分岐します。',
	]
	bad = [t for t in ok if any(f.sure for f in mechanical(t))]
	missed = [t for t in ng if not any(f.sure for f in mechanical(t))]
	nohint = [t for t in hint if not any(not f.sure for f in mechanical(t))]
	print('ginza:', bool(nlp()))
	print('false positives:', [(t, [f.rule for f in mechanical(t)]) for t in bad])
	print('missed:', missed)
	print('missed hints:', nohint)
	return 0 if not bad and not missed and not nohint else 1


def main():
	args = sys.argv[1:]
	use_llm = '--no-llm' not in args
	args = [a for a in args if a != '--no-llm']
	if args[:1] == ['--test']:
		return self_test()
	if args[:1] == ['--text'] and len(args) == 2:
		return run_text(args[1], use_llm)
	if args[:1] == ['--scan']:
		return run_scan(args[1:])
	return run_hook()


if __name__ == '__main__':
	sys.exit(main())
