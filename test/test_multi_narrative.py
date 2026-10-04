"""Check multi-reference narrative citations, including a page locator.

Usage: python3 test/test_multi_narrative.py
"""
import json
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LUA = ROOT / '_extensions/gbt7714/gbt7714.lua'
PANDOC = ['quarto', 'pandoc'] if shutil.which('quarto') else ['pandoc']


def text(node, include_notes=True):
    if isinstance(node, list):
        return ''.join(text(n, include_notes) for n in node)
    if not isinstance(node, dict):
        return ''
    if node.get('t') == 'Note' and not include_notes:
        return ''
    if node.get('t') == 'Str':
        return node['c']
    if node.get('t') in ('Space', 'SoftBreak', 'LineBreak'):
        return ' '
    return text(node.get('c'), include_notes)


def nodes(node, kind):
    if isinstance(node, list):
        for n in node:
            yield from nodes(n, kind)
    elif isinstance(node, dict):
        if node.get('t') == kind:
            yield node
        yield from nodes(node.get('c'), kind)


for style in ('authoryear', 'numeric', 'note'):
    source = f'''---
bibliography: example/refs.bib
gbt7714: {style}
---

@smith2020 [see also @wang2015].

@smith2020 [p. 7; @wang2015].
'''
    result = subprocess.run(
        PANDOC + ['-f', 'markdown', '-t', 'json', '-L', str(LUA), '--citeproc'],
        input=source, cwd=ROOT, capture_output=True, text=True, check=True,
    )
    doc = json.loads(result.stdout)
    first, second = doc['blocks'][:2]
    assert text(first, False).startswith('Smith et al.'), (style, text(first, False))
    assert text(second, False).startswith('Smith et al.'), (style, text(second, False))
    if style == 'note':
        first_notes = list(nodes(first, 'Note'))
        second_notes = list(nodes(second, 'Note'))
        assert len(first_notes) == len(second_notes) == 1, 'cluster must stay in one note'
        full = text(first_notes[0])
        assert 'Smith J，Lee A，Brown T，et al.' in full, full
        assert '王明' in full and 'see also' in full, full
        repeated = text(second_notes[0])
        assert repeated.count('同1') == 2 and '：7' in repeated, repeated
    elif style == 'numeric':
        assert '[1,see also 2]' in text(first), text(first)
        assert '[1]7[2]' in text(second), text(second)
    else:
        assert 'Smith et al.（2020；see also 王明，2015）' in text(first), text(first)
        assert 'Smith et al.（2020）7（王明，2015）' in text(second), text(second)
    # Both references must remain in the bibliography; numeric/note order follows first use.
    refs = [d for d in nodes(doc['blocks'], 'Div') if d['c'][0][0].startswith('ref-')]
    ids = [d['c'][0][0] for d in refs]
    expected = ['ref-wang2015', 'ref-smith2020'] if style == 'authoryear' else ['ref-smith2020', 'ref-wang2015']
    assert ids == expected, (style, ids)
    print(style, 'ok')
