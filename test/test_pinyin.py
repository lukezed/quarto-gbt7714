"""Optional sorting across bibliography formats, overrides and citeproc disambiguation.

Run using a Python environment with pypinyin installed.
"""
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET

from pypinyin import lazy_pinyin  # fail clearly if the optional test dependency is missing

ROOT = Path(__file__).resolve().parents[1]
FILTER = ROOT / '_extensions/gbt7714/gbt7714.lua'


def entry(id, name, role='author'):
    return dict(id=id, type='book', title='测试', language='zh-CN',
                issued={'date-parts': [[2024]]}, **{role: [{'family': name}]})


with tempfile.TemporaryDirectory() as tmp:
    path = Path(tmp)
    refs = [entry('shan', '单明'), entry('zhang', '张三'), entry('chen', '陈四')]
    (path / 'refs.json').write_text(json.dumps(refs, ensure_ascii=False))
    (path / 'refs.bib').write_text('\n'.join(
        '@book{%s, author={%s}, title={测试}, year={2024}, langid={chinese}}'
        % (r['id'], r['author'][0]['family']) for r in refs))

    def render(file='refs.json', config='', mode='authoryear', inline=None, extra=()):
        source = ('---\ngbt7714: ' + mode + '\ngbt7714-pinyin-python: '
                  + json.dumps(sys.executable) + '\n' + config)
        if inline is not None:
            source += 'references: ' + json.dumps(inline, ensure_ascii=False) + '\n'
        source += '---\n\n[@shan; @zhang; @chen]\n\n'
        command = ['quarto', 'pandoc', '-f', 'markdown', '-t', 'html', *extra,
                   '-L', str(FILTER), '--citeproc']
        if file:
            command += ['--bibliography=' + file]
        return subprocess.run(command, input=source, cwd=tmp, text=True, capture_output=True)

    def parse(result):
        assert result.returncode == 0, result.stderr
        root = ET.fromstring('<root>' + result.stdout + '</root>')
        entries = {n.get('id')[4:]: ''.join(n.itertext()) for n in root.iter('div')
                   if n.get('id', '').startswith('ref-')}
        return list(entries), entries, root

    auto = 'gbt7714-sort: pinyin\n'
    for file in ('refs.json', 'refs.bib', None):
        inline = refs if file is None else None
        assert parse(render(file, inline=inline))[0] == ['shan', 'zhang', 'chen']
        assert parse(render(file, auto, inline=inline))[0] == ['chen', 'shan', 'zhang']
        keys = 'gbt7714-sort-keys:\n  zhang: aaa\n'
        assert parse(render(file, auto + keys, inline=inline))[0] == ['zhang', 'chen', 'shan']
        assert parse(render(file, keys, inline=inline))[0] == ['zhang', 'shan', 'chen']
        for mode in ('numeric', 'note'):
            assert parse(render(file, auto, mode, inline))[0] == ['shan', 'zhang', 'chen']

    # .bib key wins over automatic reading; YAML key wins over .bib key.
    bib = (path / 'refs.bib').read_text().replace('author={张三}', 'key={aaa}, author={张三}')
    (path / 'refs.bib').write_text(bib)
    assert parse(render('refs.bib', auto))[0] == ['zhang', 'chen', 'shan']
    assert parse(render('refs.bib', auto + 'gbt7714-sort-keys:\n  zhang: zzz\n'))[0] == ['chen', 'shan', 'zhang']

    # Editor-only CSL JSON books and literal institutions get usable sort keys.
    variants = [entry('shan', '单明', 'editor'), entry('chen', '陈四', 'editor'),
                dict(entry('zhang', 'unused'), author=[{'literal': '北京大学'}])]
    assert parse(render(None, auto, inline=variants))[0] == ['zhang', 'chen', 'shan']

    # The surname exception matters relative to Qiu (普通读音 dan would precede qiu).
    variants = [entry('shan', '单明'), entry('chen', '仇明'), entry('zhang', '张三')]
    assert parse(render(None, auto, inline=variants))[0] == ['chen', 'shan', 'zhang']

    # Same author/year suffixes agree between citations and bibliography.
    variants = [entry('shan', '陈四'), entry('zhang', '陈四'), entry('chen', '张三')]
    ids, entries, root = parse(render(None, auto, inline=variants))
    assert ids == ['shan', 'zhang', 'chen']
    assert '2024a' in entries['shan'] and '2024b' in entries['zhang'], entries
    citations = ' '.join(''.join(n.itertext()) for n in root.iter('span') if n.get('class') == 'citation')
    assert '2024a，b' in citations, citations

    for setting in ('gbt7714-sort: nonsense\n', 'gbt7714-sort-keys: word\n',
                    'gbt7714-sort-keys: [one, two]\n', 'gbt7714-sort-keys: {shan: ""}\n'):
        result = render(config=setting)
        assert result.returncode != 0 and 'gbt7714-sort' in result.stderr, result.stderr
    result = render(config=auto + 'gbt7714-pinyin-python: nonexistent-python-gbt7714\n')
    assert result.returncode != 0 and 'install pypinyin' in result.stderr
    # Existing default mode and fully explicit keys never require a Python executable.
    assert render(config='gbt7714-pinyin-python: nonexistent-python-gbt7714\n').returncode == 0
    explicit = 'gbt7714-sort-keys: {shan: shan4, zhang: zhang1, chen: chen2}\n'
    assert render(config=auto + explicit + 'gbt7714-pinyin-python: nonexistent-python-gbt7714\n').returncode == 0

    # A preceding Cite filter can still change citation order before our early citeproc.
    (path / 'reverse.lua').write_text('function Cite(c)\n local r={}\n for i=#c.citations,1,-1 do r[#r+1]=c.citations[i] end\n c.citations=r\n return c\nend\n')
    assert parse(render(config=auto, mode='numeric', extra=('-L', str(path / 'reverse.lua'))))[0] == ['chen', 'zhang', 'shan']
print('pinyin: bibliography formats, defaults, overrides, editor/institution, surnames, suffixes, errors and filter composition ok')
