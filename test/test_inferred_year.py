"""Inferred and published years must receive independent author-year suffixes.

Usage: python3 test/test_inferred_year.py
"""
import html
import json
import re
import shutil
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LUA = ROOT / '_extensions/gbt7714/gbt7714.lua'
PANDOC = ['quarto', 'pandoc'] if shutil.which('quarto') else ['pandoc']

references = []
for language, prefix in (('en', 'en'), ('zh', 'zh')):
    title = 'Example' if language == 'en' else '中文示例'
    for kind in ('published', 'inferred-a', 'inferred-b', 'literal'):
        ref = {'id': f'{prefix}-{kind}', 'type': 'webpage', 'title': title,
               'language': language, 'URL': f'https://example.org/{prefix}-{kind}',
               'accessed': {'date-parts': [[2020, 2, 3]]}}
        if kind == 'published':
            ref['issued'] = {'date-parts': [[2020, 1, 1]]}
        elif kind == 'literal':
            ref['issued'] = {'literal': 'unknown'}
        references.append(ref)


def plain(markup):
    return html.unescape(re.sub(r'<[^>]+>', '', markup)).strip()


with tempfile.TemporaryDirectory() as directory:
    bib = Path(directory) / 'refs.json'
    bib.write_text(json.dumps(references, ensure_ascii=False), encoding='utf-8')
    source = '\n\n'.join(f'N: @{r["id"]} here.\n\nP: [@{r["id"]}] here.'
                         for r in references)
    for lang in ('zh', 'en'):
        for links in (False, True):
            result = subprocess.run(
                PANDOC + ['-f', 'markdown', '-t', 'html', '--wrap=none',
                          '-L', str(LUA), '--citeproc', '-M', f'bibliography={bib}',
                          '-M', 'gbt7714=authoryear', '-M', f'lang={lang}',
                          '-M', f'link-citations={str(links).lower()}'],
                input=source, capture_output=True, text=True, check=True,
            )
            paragraphs = [plain(p) for p in re.findall(r'<p>(.*?)</p>', result.stdout, re.S)]
            entries = {html.unescape(key): plain(body) for key, body in re.findall(
                r'<div id="ref-([^"]+)"[^>]*>(.*?)</div>', result.stdout, re.S)}
            for i, ref in enumerate(references):
                author = '佚名' if ref['language'] == 'zh' else 'Anon'
                kind = ref['id'].split('-', 1)[1]
                year = {'published': '2020', 'inferred-a': '[2020a]',
                        'inferred-b': '[2020b]', 'literal': 'unknown'}[kind]
                narrative, parenthetical = paragraphs[2 * i:2 * i + 2]
                assert narrative == f'N: {author}（{year}） here.', (ref['id'], narrative)
                assert parenthetical == f'P: （{author}，{year}） here.', (ref['id'], parenthetical)
                entry = entries[ref['id']]
                assert entry.startswith(f'{author}，{year}.'), (ref['id'], entry)
                assert '[2020-02-03]' in entry, (ref['id'], entry)
            print(lang, 'linked' if links else 'unlinked', 'ok')
