"""gbt7714-bibpunct mirrors bst CTL_bib_punct: GB (default), half, bylanguage."""
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
FILTER = ROOT / '_extensions/gbt7714/gbt7714.lua'
BIB = '''@article{en, author={Liu, Shengnan and Hallinger, Philip}, title={Does leadership matter? Evidence ({China})},
  journal={Teaching and Teacher Education}, year={2016}, volume={59}, number={2}, pages={79--91}}
@article{zh, author={冯剑峰 and 姜浩哲}, title={教师数智素养：测评框架}, journal={教育发展研究},
  year={2024}, volume={44}, number={10}, pages={21--29}}
'''
FW = '，：；（）？'
with tempfile.TemporaryDirectory() as tmp:
    (Path(tmp) / 'refs.bib').write_text(BIB)

    def entries(mode, punct=None):
        setting = '' if punct is None else f'gbt7714-bibpunct: {punct}\n'
        source = f'---\ngbt7714: {mode}\n{setting}---\n\n[@en; @zh]\n'
        r = subprocess.run(['quarto', 'pandoc', '-f', 'markdown', '-t', 'plain', '--wrap=none',
                            '-L', str(FILTER), '--citeproc', '--bibliography=refs.bib'],
                           input=source, cwd=tmp, text=True, capture_output=True)
        assert r.returncode == 0, r.stderr
        lines = r.stdout.splitlines()
        en = next(l for l in lines if l.startswith('Liu') or 'Teaching and Teacher Education' in l and 'Liu' in l)
        zh = next(l for l in lines if '教育发展研究' in l)
        return en, zh

    for mode in ('authoryear', 'numeric', 'note'):
        en, zh = entries(mode)
        assert any(c in en for c in FW), en          # GB default: Western entries full-width too
        en_gb, zh_gb = en, zh
        assert entries(mode, 'GB') == (en_gb, zh_gb)
        en, zh = entries(mode, 'bylanguage')
        assert not any(c in en for c in FW), en
        assert '59(2): 79-91' in en and 'matter? evidence (China)' in en, en
        assert zh == zh_gb, zh                       # CJK entries unchanged
        en, zh = entries(mode, 'half')
        assert not any(c in en for c in FW), en
        assert '44(10): 21-29' in zh, zh
    r = subprocess.run(['quarto', 'pandoc', '-f', 'markdown', '-t', 'plain', '-L', str(FILTER), '--citeproc',
                        '--bibliography=refs.bib'], input='---\ngbt7714-bibpunct: wide\n---\n\n[@en]\n',
                       cwd=tmp, text=True, capture_output=True)
    assert r.returncode != 0 and 'gbt7714-bibpunct' in r.stderr
print('bibpunct: GB default, half, bylanguage across authoryear/numeric/note, invalid value ok')
