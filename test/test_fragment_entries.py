"""Preserve series/volume titles and date-only first-citation footnotes."""
import html
import re
import shutil
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PANDOC = ['quarto', 'pandoc'] if shutil.which('quarto') else ['pandoc']
BIB = r'''@book{volume, series={中国科学技术史}, volume={第二卷}, title={科学思想史}, langid={chinese}}
@book{standalone, series={不应显示的丛书}, title={独立书名}, langid={chinese}}
@book{dateonly, year={[1936]}, langid={chinese}}
'''

def plain(markup):
    return html.unescape(re.sub(r'<[^>]+>', '', markup)).strip()

with tempfile.TemporaryDirectory() as directory:
    (Path(directory) / 'refs.bib').write_text(BIB, encoding='utf-8')
    for style in ('authoryear', 'numeric', 'note'):
        result = subprocess.run(
            PANDOC + ['-f', 'markdown', '-t', 'html', '--wrap=none',
                      '-L', str(ROOT / '_extensions/gbt7714/gbt7714.lua'), '--citeproc',
                      '-M', 'bibliography=refs.bib', '-M', f'gbt7714={style}'],
            input='First [@volume].\n\nSecond [@standalone].\n\nDate [@dateonly].\n\nRepeat [@dateonly].',
            cwd=directory, text=True, capture_output=True, check=True,
        )
        text = plain(result.stdout)
        assert '中国科学技术史：第二卷\u2003科学思想史[M]' in text, text
        assert '独立书名[M]' in text and '不应显示的丛书' not in text, text
        if style == 'note':
            notes = re.findall(r'<li id="fn\d+"[^>]*>(.*?)</li>', result.stdout, re.S)
            assert len(notes) == 4, notes
            assert '[1936].' in plain(notes[2]), notes[2]
            assert '同3.' in plain(notes[3]), notes[3]
        print(style, 'series and date fragments: ok')
