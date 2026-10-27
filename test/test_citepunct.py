"""gbt7714-citepunct: half-width brackets and separators for author-year in-text citations (#2)."""
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
FILTER = ROOT / '_extensions/gbt7714/gbt7714.lua'
BIB = '''@book{p, author={Priestley, Mark and Biesta, Gert and Robinson, Sarah}, title={Teacher agency}, year={2015}}
@book{l, author={Lareau, Annette}, title={Unequal childhoods}, year={2011}}
@book{z, author={张三}, title={中文}, year={2020}}
'''
BODY = '见 [@p; @z]。@p 指出。Lareau [-@l] 认为。张三 [-@z] 认为。见 [@l, 42]。'
with tempfile.TemporaryDirectory() as tmp:
    (Path(tmp) / 'refs.bib').write_text(BIB)

    def run(meta):
        source = f'---\n{meta}---\n\n{BODY}\n'
        r = subprocess.run(['quarto', 'pandoc', '-f', 'markdown', '-t', 'plain', '--wrap=none',
                            '-L', str(FILTER), '--citeproc', '--bibliography=refs.bib'],
                           input=source, cwd=tmp, text=True, capture_output=True)
        assert r.returncode == 0, r.stderr
        return r.stdout

    gb = run('gbt7714: authoryear\n')
    assert '（Priestley et al.，2015；张三，2020）' in gb, gb
    half = run('gbt7714: authoryear\ngbt7714-citepunct: half\n')
    body = half.split('\n\n')[0]
    assert '(Priestley et al., 2015; 张三, 2020)' in body, body
    assert 'Priestley et al. (2015)' in body, body          # narrative keeps the space
    assert 'Lareau (2011)' in body, body                    # explicit Latin prose author keeps it
    assert '张三(2020)' in body, body                       # CJK prose author attaches
    md = subprocess.run(['quarto', 'pandoc', '-f', 'markdown', '-t', 'markdown', '-L', str(FILTER), '--citeproc',
                         '--bibliography=refs.bib'], input='---\ngbt7714-citepunct: half\n---\n\n见 [@l, 42]。\n',
                        cwd=tmp, text=True, capture_output=True).stdout
    assert '见(Lareau, 2011)^42^。' in md, md              # page superscript after the half-width bracket
    assert not any(c in body for c in '（），；'), body
    # bibliography unchanged by citepunct alone
    assert gb.split('\n\n', 1)[1] == half.split('\n\n', 1)[1]
    # bibpunct half implies half-width citations
    assert '(Priestley et al., 2015; 张三, 2020)' in run('gbt7714: authoryear\ngbt7714-bibpunct: half\n')
    r = subprocess.run(['quarto', 'pandoc', '-f', 'markdown', '-t', 'plain', '-L', str(FILTER), '--citeproc',
                        '--bibliography=refs.bib'], input='---\ngbt7714-citepunct: wide\n---\n\n[@p]\n',
                       cwd=tmp, text=True, capture_output=True)
    assert r.returncode != 0 and 'gbt7714-citepunct' in r.stderr
print('citepunct: half-width author-year citations, narrative spacing, bibliography untouched, invalid value ok')
