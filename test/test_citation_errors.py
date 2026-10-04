"""Targeted regressions for prose authors, custom CSL warnings and bibliography errors.
Usage: python3 test/test_citation_errors.py
"""
import html, os, re, shutil, subprocess, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
EXT = os.path.join(HERE, '..', '_extensions', 'gbt7714')
PANDOC = ['quarto', 'pandoc'] if shutil.which('quarto') else ['pandoc']
BIB = '@book{x, author={Annette Lareau}, title={Unequal Childhoods}, year={2011}}\n'


def render(md, directory, style='authoryear', *meta):
    args = [a for m in meta for a in ('-M', m)]
    return subprocess.run(PANDOC + ['-f', 'markdown', '-t', 'html', '--wrap=none',
                                   '-M', 'bibliography=refs.bib', '-M', f'gbt7714={style}',
                                   '-M', 'suppress-bibliography=true', *args,
                                   '-L', os.path.join(EXT, 'gbt7714.lua'), '--citeproc'],
                          input=md, cwd=directory, capture_output=True, text=True)


with tempfile.TemporaryDirectory() as d:
    with open(os.path.join(d, 'refs.bib'), 'w', encoding='utf-8') as f:
        f.write(BIB)
    # Keep the Latin author's space in narrative syntax and ordinary parenthetical citations;
    # suppress-author syntax attaches the year to the author already written in the prose.
    for md, expected in [('Lareau [-@x].', 'Lareau<span'),
                         ('Lareau\n[-@x].', 'Lareau<span'),
                         ('See [@x].', 'See <span'),
                         ('Lareau [-@x, 42].', 'Lareau<span'),
                         ('See [compare -@x].', 'See <span')]:
        r = render(md, d)
        assert r.returncode == 0, r.stderr
        assert expected in r.stdout, (md, r.stdout)
    r = render('英文叙述 @x。', d)
    assert r.returncode == 0, r.stderr
    assert html.unescape(re.sub(r'<[^>]+>', '', r.stdout)).strip() == '英文叙述 Lareau（2011）。', r.stdout
    r = render('Lareau [-@x].', d, 'authoryear', 'link-citations=true', 'suppress-bibliography=false')
    assert r.returncode == 0, r.stderr
    assert 'Lareau<span' in r.stdout and 'href="#ref-x"' in r.stdout, r.stdout
    for style in ('numeric', 'note'):
        r = render('Lareau [-@x].', d, style)
        assert r.returncode == 0, r.stderr
        assert 'Lareau<span' in r.stdout and '<sup>' in r.stdout, (style, r.stdout)
    # A separately named CSL is a user override, even when copied from the extension.
    shutil.copy(os.path.join(EXT, 'gbt7714-authoryear.csl'), os.path.join(d, 'custom.csl'))
    r = render('Lareau [-@x].', d, 'authoryear', 'csl=custom.csl')
    assert r.returncode == 0, r.stderr
    assert 'custom CSL "custom.csl"' in r.stderr and 'rewrites are disabled' in r.stderr, r.stderr
    assert 'Lareau <span' in r.stdout, r.stdout
    r = render('[@x]', d)
    assert 'custom CSL' not in r.stderr, r.stderr
    # Preserve parser diagnostics and a failing exit status, without implementation stack frames.
    with open(os.path.join(d, 'refs.bib'), 'w', encoding='utf-8') as f:
        f.write('@book{x, title={Broken}\n')
    r = render('[@x]', d)
    assert r.returncode != 0, 'malformed bibliography unexpectedly succeeded'
    assert 'ERROR: gbt7714:' in r.stderr and "bibliography file 'refs.bib'" in r.stderr, r.stderr
    assert 'line 2, column 1' in r.stderr and 'unexpected end of input' in r.stderr, r.stderr
    assert 'stack traceback' not in r.stderr and "in function 'Pandoc'" not in r.stderr, r.stderr
    r = render('[@x]', d, 'invalid')
    assert r.returncode != 0 and 'unknown style "invalid"' in r.stderr, r.stderr
    assert 'stack traceback' not in r.stderr, r.stderr
print('ok: prose authors, custom CSL warnings, clean bibliography errors')
