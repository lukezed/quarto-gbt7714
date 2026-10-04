"""The final citeproc pass owns automatic headings; user headings survive."""
from pathlib import Path
import json
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
PANDOC = ['quarto', 'pandoc'] if shutil.which('quarto') else ['pandoc']

for style in ('authoryear', 'numeric', 'note'):
    for explicit in (False, True):
        source = '[@knuth1984]\n'
        if explicit:
            source += '\n# My bibliography {.unnumbered}\n\n::: {#refs}\n:::\n'
        args = PANDOC + [
            '-f', 'markdown', '-t', 'json',
            '-M', f'bibliography={ROOT / "example/refs.bib"}',
            '-M', f'gbt7714={style}',
            '-M', 'reference-section-title=参考文献',
            '-L', str(ROOT / '_extensions/gbt7714/gbt7714.lua'), '--citeproc',
        ]
        result = subprocess.run(args, input=source, text=True, capture_output=True, check=True)
        blocks = json.loads(result.stdout)['blocks']
        headings = [b for b in blocks if b['t'] == 'Header']
        assert len(headings) == 1, (style, explicit, headings)
        expected = 'My bibliography' if explicit else '参考文献'
        words = ' '.join(i['c'] for i in headings[0]['c'][2] if i['t'] == 'Str')
        assert words == expected, (style, explicit, words)
        refs = [b for b in blocks if b['t'] == 'Div' and b['c'][0][0] == 'refs']
        assert len(refs) == 1 and refs[0]['c'][1], (style, explicit, refs)

print('bibliography headings: ok (automatic and explicit, all three styles)')
