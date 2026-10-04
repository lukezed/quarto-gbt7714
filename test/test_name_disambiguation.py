"""Narrative labels must share citeproc's parenthetical disambiguation context.

Usage: python3 test/test_name_disambiguation.py
"""
import json
import shutil
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LUA = ROOT / '_extensions/gbt7714/gbt7714.lua'
PANDOC = ['quarto', 'pandoc'] if shutil.which('quarto') else ['pandoc']
BIB = '''@book{john, author={John Smith}, title={First}, year={2020}}
@book{alice, author={Alice Smith}, title={Second}, year={2020}}
@book{alan, author={Alan Brown}, title={Third}, year={2021}}
@book{alex, author={Alex Brown}, title={Fourth}, year={2021}}
@book{other, author={Oliver Smith}, title={Fifth}, year={2022}}
@book{zhjohn, author={John Jones}, title={中文著作一}, year={2023}, langid={chinese}}
@book{zhalice, author={Alice Jones}, title={中文著作二}, year={2023}, langid={chinese}}
'''


def text(node):
    if isinstance(node, list):
        return ''.join(text(n) for n in node)
    if not isinstance(node, dict):
        return ''
    if node.get('t') == 'Str':
        return node['c']
    if node.get('t') in ('Space', 'SoftBreak', 'LineBreak'):
        return ' '
    return text(node.get('c'))


def render(source, directory, lang, links, style='authoryear'):
    result = subprocess.run(
        PANDOC + ['-f', 'markdown', '-t', 'json', '-L', str(LUA), '--citeproc',
                  '-M', 'bibliography=refs.bib', '-M', f'gbt7714={style}',
                  '-M', f'lang={lang}', '-M', f'link-citations={str(links).lower()}',
                  '-M', 'suppress-bibliography=true'],
        input=source, cwd=directory, capture_output=True, text=True, check=True,
    )
    return [text(b) for b in json.loads(result.stdout)['blocks'] if b['t'] == 'Para']


with tempfile.TemporaryDirectory() as directory:
    (Path(directory) / 'refs.bib').write_text(BIB, encoding='utf-8')
    source = '\n\n'.join(
        f'N: @{key} here.\n\nP: [@{key}] here.'
        for key in ('john', 'alice', 'alan', 'alex', 'other')
    ) + '\n\nM: @john [see also @alice] here.\n\nL: @john [p. 7; @alice] here.'
    for lang in ('zh', 'en'):
        for links in (False, True):
            paragraphs = render(source, directory, lang, links)
            labels, years = {}, {}
            for i, key in enumerate(('john', 'alice', 'alan', 'alex', 'other')):
                narrative, parenthetical = paragraphs[2 * i:2 * i + 2]
                inside = parenthetical.removeprefix('P: （').removesuffix('） here.')
                label, year = inside.rsplit('，', 1)
                assert narrative == f'N: {label}（{year}） here.', (lang, links, narrative, parenthetical)
                labels[key], years[key] = label, year
            # Upstream bst uses Latin surnames and year suffixes, including when
            # given names differ. Citeproc must apply this to both citation forms.
            assert labels['john'] == labels['alice'] == labels['other'] == 'Smith', labels
            assert years['john'] != years['alice'], years
            assert years['alan'] != years['alex'], years
            assert years['other'] == '2022', years
            assert paragraphs[10] == f'M: {labels["john"]}（{years["john"]}；see also {labels["alice"]}，{years["alice"]}） here.', paragraphs[10]
            assert paragraphs[11] == f'L: {labels["john"]}（{years["john"]}）7（{labels["alice"]}，{years["alice"]}） here.', paragraphs[11]
            # Chinese-language entries with Latin names use the CSL's long-name
            # macro. Manually reconstructed surname-only prose loses these initials.
            chinese = render('N: @zhjohn here.\n\nP: [@zhjohn] here.\n\nN: @zhalice here.\n\nP: [@zhalice] here.\n\nM: @zhjohn [see also @zhalice] here.', directory, lang, links)
            for i, label in enumerate(('Jones J', 'Jones A')):
                inside = chinese[2 * i + 1].removeprefix('P: （').removesuffix('） here.')
                name, year = inside.rsplit('，', 1)
                assert name == label, chinese
                assert chinese[2 * i] == f'N: {name}（{year}） here.', chinese
            assert chinese[4].startswith('M: Jones J（'), chinese[4]
            print(lang, 'linked' if links else 'unlinked', 'ok')
    for style in ('numeric', 'note'):
        paragraphs = render('N: @john here.\n\nP: [@alice] here.', directory, 'zh', True, style)
        assert paragraphs[0].startswith('N: Smith'), paragraphs
        assert not paragraphs[0].startswith('N: Smith J'), paragraphs
        print(style, 'ok')
