"""Check translator terms against upstream BST and document-language independence."""
from pathlib import Path
import shutil
import subprocess
import tempfile
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
FILTER = ROOT / '_extensions/gbt7714/gbt7714.lua'
BIB = '''@book{zh, author={张三}, title={中文测试}, translator={Jones, David}, year={2024}, langid={chinese}}
@book{en, author={Smith, John}, title={English test}, translator={陈七}, year={2024}, langid={english}}
@book{ja, author={山田太郎}, title={日本語}, translator={田中一郎}, year={2024}, langid={japanese}}
@book{editor, editor={Brown, Alice}, title={Edited book}, year={2023}, langid={english}}
'''

def entries(markup):
    root = ET.fromstring('<root>' + markup + '</root>')
    return {node.get('id')[4:]: ''.join(node.itertext()).strip()
            for node in root.iter('div') if node.get('id', '').startswith('ref-')}

with tempfile.TemporaryDirectory() as tmp:
    directory = Path(tmp)
    (directory / 'refs.bib').write_text(BIB)
    for mode in ('authoryear', 'numeric', 'note'):
        bst = 'authoryear' if mode == 'authoryear' else 'numeric'
        shutil.copy(ROOT / f'test/upstream/gbt7714-{bst}.bst', directory / 'style.bst')
        (directory / 'a.aux').write_text('\\citation{*}\n\\bibstyle{style}\n\\bibdata{refs}\n')
        subprocess.run(['bibtex', 'a'], cwd=tmp, capture_output=True, check=True)
        bbl = (directory / 'a.bbl').read_text()
        assert 'Jones' in bbl and '译' in bbl and bbl.count('trans.') == 2, bbl
        for lang in ('en-US', 'zh-CN'):
            result = subprocess.run(
                ['quarto', 'pandoc', '-f', 'markdown', '-t', 'html', '--wrap=none',
                 '-L', str(FILTER), '--citeproc', '--bibliography=refs.bib',
                 '-M', f'gbt7714={mode}', '-M', f'lang={lang}'],
                input='[@en; @zh; @ja; @editor]', cwd=tmp, text=True,
                capture_output=True, check=True)
            rendered = entries(result.stdout)
            assert 'Jones D，译' in rendered['zh'], rendered['zh']
            assert '陈七，trans.' in rendered['en'], rendered['en']
            assert '田中一郎，trans.' in rendered['ja'], rendered['ja']
            assert 'trans.' not in rendered['editor'] and '译' not in rendered['editor']
        print(mode, 'translator terms match BST across entry/document languages')
