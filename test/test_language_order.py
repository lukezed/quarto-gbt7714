"""Language groups are configurable without changing numeric order or pinyin keys."""
from pathlib import Path
import subprocess
import tempfile
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
FILTER = ROOT / '_extensions/gbt7714/gbt7714.lua'
BIB = '''@book{zh_z, author={张三}, title={中文}, year={2024}, key={zhang1 san1}, langid={chinese}}
@book{zh_c, author={陈四}, title={中文}, year={2024}, key={chen2 si4}, langid={chinese}}
@book{en, author={Smith, John}, title={English}, year={2024}, langid={english}}
@book{ja, author={山田太郎}, title={日本語}, year={2024}, langid={japanese}}
@book{ru, author={Иванов}, title={Русский}, year={2024}, langid={russian}}
@book{other, author={Dupont, Jean}, title={Français}, year={2024}, langid={french}}
'''
CITES = '[@en; @zh_z; @other; @ja; @ru; @zh_c]'
with tempfile.TemporaryDirectory() as tmp:
    directory = Path(tmp)
    (directory / 'refs.bib').write_text(BIB)

    def render(mode='authoryear', order=None):
        setting = '' if order is None else f'gbt7714-language-order: {order}\n'
        source = f'---\ngbt7714: {mode}\n{setting}---\n\n{CITES}'
        return subprocess.run(['quarto', 'pandoc', '-f', 'markdown', '-t', 'html',
                               '-L', str(FILTER), '--citeproc', '--bibliography=refs.bib'],
                              input=source, cwd=tmp, text=True, capture_output=True)

    def ids(result):
        assert result.returncode == 0, result.stderr
        root = ET.fromstring('<root>' + result.stdout + '</root>')
        return [n.get('id')[4:] for n in root.iter('div') if n.get('id', '').startswith('ref-')]

    default = ['zh_c', 'zh_z', 'ja', 'en', 'ru', 'other']
    assert ids(render()) == default
    assert ids(render(order='[zh, ja, en, ru, other]')) == default
    assert ids(render(order='[en, zh, ja, ru, other]')) == ['en', 'zh_c', 'zh_z', 'ja', 'ru', 'other']
    assert ids(render(order='[ja, en, ru, other, zh]')) == ['ja', 'en', 'ru', 'other', 'zh_c', 'zh_z']
    for mode in ('numeric', 'note'):
        assert ids(render(mode, '[en, zh, ja, ru, other]')) == ['en', 'zh_z', 'other', 'ja', 'ru', 'zh_c']
    for invalid in ('en', '[en, zh]', '[en, zh, ja, ru, en]', '[en, zh, ja, ru, ko]'):
        result = render(order=invalid)
        assert result.returncode != 0 and 'gbt7714-language-order' in result.stderr
print('language order: defaults, override, pinyin keys, numeric/note and invalid settings ok')
