"""docx: an author-year citation after Chinese prose gets its own run, so Word does not set
accented Latin letters (Bürkner) in the East Asian font via w:hint="eastAsia"."""
from pathlib import Path
import re
import subprocess
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]
FILTER = ROOT / '_extensions/gbt7714/gbt7714.lua'
with tempfile.TemporaryDirectory() as tmp:
    d = Path(tmp)
    (d / 'refs.bib').write_text('@article{b, author={Bürkner, Paul-Christian}, title={T}, journal={J}, year={2021}}\n')
    for meta in ('', 'gbt7714-citepunct: half\n'):
        (d / 't.md').write_text(f'---\nlang: zh\n{meta}---\n\n标定参数[@b]。\n')
        r = subprocess.run(['quarto', 'pandoc', 't.md', '-L', str(FILTER), '--citeproc',
                            '--bibliography=refs.bib', '-o', 't.docx'], cwd=tmp, capture_output=True, text=True)
        assert r.returncode == 0, r.stderr
        xml = zipfile.ZipFile(d / 't.docx').read('word/document.xml').decode()
        runs = re.findall(r'<w:r>(.*?)</w:r>', xml)
        cite = [x for x in runs if 'rkner' in x][0]  # body comes before the bibliography
        assert 'eastAsia' not in cite and '标定' not in cite, cite
print('docx citation run: separate from CJK prose, no eastAsia hint')
