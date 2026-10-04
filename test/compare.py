"""Golden test: upstream gbt7714 bst (bibtex) vs our CSL (pandoc citeproc), entry by entry.

Usage: python3 test/compare.py authoryear|numeric [-v]
Prints the share of identical entries, whether the sort order matches, and (-v) each diff.

Citation mode: python3 test/compare.py cite-authoryear|cite-numeric [-v]
Compiles CITES with gbt7714.sty + bst (xelatex) and pandoc, compares each line.
Superscripts are marked as ^(...) on both sides.

Regression guard: --check fails (exit 1) if an entry/citation identical in test/baseline.json
is no longer identical; --update rewrites the baseline from the current results.
Pandoc runs with the user's default settings (no `lang`), as README promises.
"""
import html, json, os, re, shutil, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
UP = os.path.join(HERE, 'upstream')
EXT = os.path.join(HERE, '..', '_extensions', 'gbt7714')
BIB = os.path.join(UP, 'gbt7714-examples.bib')
CJK = r'[\u3000-\u9fff\uff00-\uffef]'

def norm(s):
    s = s.replace('\u2019', "'").replace('\u2013', '--')  # typography only, not a style difference
    s = re.sub(r'[ \t\r\n]+', ' ', s).strip()  # not \s: keep em/thin spaces significant
    return re.sub(rf'(?<={CJK}) (?={CJK})', '', s)

def bst(style):
    with tempfile.TemporaryDirectory() as d:
        open(os.path.join(d, 'a.aux'), 'w').write(
            f'\\citation{{*}}\n\\bibstyle{{{os.path.join(UP, "gbt7714-" + style)}}}\n\\bibdata{{{BIB[:-4]}}}\n')
        r = subprocess.run(['bibtex', 'a'], cwd=d, capture_output=True, text=True)
        if not os.path.exists(os.path.join(d, 'a.bbl')): sys.exit('bibtex failed:\n' + r.stdout)
        bbl = open(os.path.join(d, 'a.bbl'), encoding='utf-8').read()
    out = []
    for item in bbl.split('\\bibitem')[1:]:
        i = 0
        if item.startswith('['):  # skip optional label, which may nest [] and {}
            depth = 0
            for i, ch in enumerate(item):
                depth += ch in '[{'
                depth -= ch in ']}'
                if depth == 0: break
            i += 1
        m = re.match(r'\{([^}]*)\}\s*', item[i:])
        key, body = m.group(1), item[i + m.end():]
        body = body.split('\\end{thebibliography}')[0]
        body = re.sub(rf'(?<={CJK})\n(?={CJK})', '', body)
        body = re.sub(r'\\(newblock|allowbreak)\b\s*', '', body)
        body = re.sub(r'\\(url|doi|cstr|natexlab|textit|emph|textbf|mbox|nolinkurl)\{([^{}]*)\}', r'\2', body)
        # LaTeX typography -> the characters it renders as
        body = (re.sub(r'\\quad\s*', '\u2003', body).replace('---', '\u2014').replace('$\\times$', '\u00d7')
                .replace('\\,', '\u2009').replace('``', '\u201c').replace("''", '\u201d'))
        body = body.replace('\\&', '&').replace('\\_', '_').replace('\\%', '%').replace('\\$', '$').replace('~', ' ')
        body = re.sub(r'\\[a-zA-Z]+\s*', '', body).replace('{', '').replace('}', '')
        out.append((key, norm(body)))
    return out

def csl(style):
    md = '---\nnocite: "@*"\n---\n'
    r = subprocess.run(['pandoc', '-f', 'markdown', '-t', 'html', '--wrap=none',
                        '-M', f'bibliography={BIB}', '-M', f'gbt7714={style}',
                        '-L', os.path.join(EXT, 'gbt7714.lua'), '--citeproc'],
                       input=md, capture_output=True, text=True)
    if r.returncode: sys.exit(r.stderr)
    out = []
    for chunk in r.stdout.split('<div id="ref-')[1:]:
        key, body = chunk.split('"', 1)
        body = body.split('>', 1)[1]
        out.append((html.unescape(key), norm(html.unescape(re.sub(r'<[^>]+>', '', body)))))
    return out

# (natbib command, pandoc markdown); keys from gbt7714-examples.bib
A, B, C = 'gbt7714.5.1:3', 'gbt7714.7.7:5', 'gbt7714.9.3.1.2:1'  # en: 1, 2, 3 authors
D, E, F = 'gbt7714.5.1:1', 'gbt7714.b.4:7', 'gbt7714.b.4:11'     # zh: 1, 2, 3 authors
G1, G2 = 'gbt7714.8.5.3:4', 'gbt7714.8.5.3:5'                    # same authors, same year
N = 'gbt7714.8.11.2.2:1'                                         # no author (佚名)
CITES = [
    (rf'\citep{{{A}}}', f'[@{A}]'),
    (rf'\citet{{{A}}}', f'@{A}'),
    (rf'\citep[42]{{{A}}}', f'[@{A}, 42]'),
    (rf'\citep{{{B}}}', f'[@{B}]'),
    (rf'\citep{{{C}}}', f'[@{C}]'),
    (rf'\citet[42]{{{C}}}', f'@{C} [42]'),
    (rf'\citep{{{D}}}', f'[@{D}]'),
    (rf'\citet{{{D}}}', f'@{D}'),
    (rf'\citep[35]{{{D}}}', f'[@{D}, 35]'),
    (rf'\citep{{{E}}}', f'[@{E}]'),
    (rf'\citep{{{F}}}', f'[@{F}]'),
    (rf'\citet{{{F}}}', f'@{F}'),
    (rf'\citep[11-13]{{{E}}}', f'[@{E}, pp. 11-13]'),
    (rf'\citep{{{G1},{G2}}}', f'[@{G1}; @{G2}]'),
    (rf'\citep{{{A},{D}}}', f'[@{A}; @{D}]'),
    (rf'\citep{{{A},{B},{C}}}', f'[@{A}; @{B}; @{C}]'),
    (rf'\citep[5]{{{A}}}\citep[7]{{{D}}}', f'[@{A}, 5; @{D}, 7]'),   # each with its own page
    (rf'\citep{{{F},{A},{D}}}', f'[@{F}; @{A}; @{D}]'),               # upstream keeps written order
    (rf'\citet{{{N}}}', f'@{N}'),                                     # narrative, no author
    (rf'\citep{{{N}}}', f'[@{N}]'),
    (rf'\citep[见][]{{{D}}}', f'[见 @{D}]'),                           # prefix
    (rf'\citep[第2章]{{{D}}}', f'[@{D}, 第2章]'),                       # non-page locator
    (rf'\citep{{{A},{B},{F}}}', f'[@{A}; @{B}; @{F}]'),               # numeric compression
]

def cite_bst(style):
    body = '\n\n'.join(f'T{i}: {tex}' for i, (tex, _) in enumerate(CITES))
    tex = (f'\\documentclass{{ctexart}}\n\\usepackage[paperwidth=100cm,paperheight=100cm]{{geometry}}\n'
           f'\\usepackage{{gbt7714}}\n\\bibliographystyle{{gbt7714-{style}}}\n'
           f'\\renewcommand{{\\textsuperscript}}[1]{{SUP(#1)}}\n\\pagestyle{{empty}}\n'
           f'\\begin{{document}}\n{body}\n\\bibliography{{gbt7714-examples}}\n\\end{{document}}\n')
    with tempfile.TemporaryDirectory() as d:
        for f in ('gbt7714.sty', f'gbt7714-{style}.bst', 'gbt7714-examples.bib'):
            shutil.copy(os.path.join(UP, f), d)
        open(os.path.join(d, 'a.tex'), 'w', encoding='utf-8').write(tex)
        for cmd in (['xelatex', '-interaction=batchmode', 'a'], ['bibtex', 'a'],
                    ['xelatex', '-interaction=batchmode', 'a'], ['xelatex', '-interaction=batchmode', 'a']):
            subprocess.run(cmd, cwd=d, capture_output=True)
        if not os.path.exists(os.path.join(d, 'a.pdf')): sys.exit('xelatex failed, see a.log')
        bbox = subprocess.run(['pdftotext', '-bbox', 'a.pdf', '-'], cwd=d, capture_output=True, text=True).stdout
    # Rebuild lines from word boxes: plain pdftotext splits a superscript that overlaps "）".
    words = sorted((float(y), float(x), html.unescape(w)) for x, y, w in re.findall(
        r'xMin="([\d.]+)" yMin="[\d.]+" xMax="[\d.]+" yMax="([\d.]+)">(.*?)</word>', bbox))
    lines, last = [], None
    for y, x, w in words:
        if last is None or y - last > 5: lines.append([])  # superscripts sit < 5pt off the baseline
        lines[-1].append((x, w)); last = y
    txt = '\n'.join(' '.join(w for _, w in sorted(ws)) for ws in lines)
    txt = re.sub(r'\s*SUP\(', '^(', txt)
    return dict(re.findall(r'^(T\d+):\s*(.*)$', txt, re.M))

def cite_csl(style):
    md = '\n\n'.join(f'T{i}: {m}' for i, (_, m) in enumerate(CITES))
    r = subprocess.run(['pandoc', '-f', 'markdown', '-t', 'html', '--wrap=none',
                        '-M', f'bibliography={BIB}', '-M', f'gbt7714={style}', '-M', 'suppress-bibliography=true',
                        '-L', os.path.join(EXT, 'gbt7714.lua'), '--citeproc'],
                       input=md, capture_output=True, text=True)
    if r.returncode: sys.exit(r.stderr)
    h = re.sub(r'<sup>(.*?)</sup>', r'^(\1)', r.stdout)
    h = html.unescape(re.sub(r'<[^>]+>', '', h))
    return dict(re.findall(r'^(T\d+):\s*(.*)$', h, re.M))

def cite_main(style, verbose):
    keys = set(re.findall(r'^@\w+\{([^,]+),', open(BIB, encoding='utf-8').read(), re.M))
    for tex, _ in CITES:
        for k in re.findall(r'\{([^{}]*)\}$', tex)[0].split(','):
            assert k in keys, f'citation key {k} no longer in upstream examples'
    b, c = cite_bst(style), cite_csl(style)
    if len(b) < len(CITES): sys.exit(f'only {len(b)}/{len(CITES)} bst lines found; LaTeX side broken?')
    sup = lambda v: norm(v.replace(')^(', ''))  # merge adjacent superscript runs
    # xeCJK glue between CJK and Latin shows up as a space in pdftotext; not a character
    glue = lambda v: re.sub(rf'(?<={CJK}) (?=[!-~])|(?<=[!-~]) (?={CJK})', '', v)
    b = {k: glue(sup(v)) for k, v in b.items()}
    c = {k: sup(v) for k, v in c.items()}
    same = [k for k in b if c.get(k) == b[k]]
    print(f'cite-{style}: {len(same)}/{len(CITES)} citations identical (bst lines found: {len(b)})')
    if verbose:
        for i, (tex, m) in enumerate(CITES):
            k = f'T{i}'
            if c.get(k) != b.get(k):
                print(f'\n{k} {m}\n  bst: {b.get(k)}\n  csl: {c.get(k)}')
    return same

def entries_main(style, verbose):
    b, c = bst(style), csl(style)
    if style == 'numeric':  # bst numbers by citation order; strip labels, compare text
        c = [(k, re.sub(r'^\[\d+\]\s*', '', v)) for k, v in c]
    bd, cd = dict(b), dict(c)
    same = [k for k in bd if cd.get(k) == bd[k]]
    print(f'{style}: {len(same)}/{len(bd)} entries identical; '
          f'missing in CSL: {len(set(bd) - set(cd))}; order identical: {[k for k, _ in b] == [k for k, _ in c]}')
    if verbose:
        for k in bd:
            if cd.get(k) != bd[k]:
                print(f'\n{k}\n  bst: {bd[k]}\n  csl: {cd.get(k)}')
    return same

BASELINE = os.path.join(HERE, 'baseline.json')
MODES = ['authoryear', 'numeric', 'cite-authoryear', 'cite-numeric']

def main():
    args = [a for a in sys.argv[1:] if not a.startswith('-')]
    verbose = '-v' in sys.argv
    modes = args or MODES
    results = {m: (cite_main(m[5:], verbose) if m.startswith('cite-') else entries_main(m, verbose))
               for m in modes}
    base = json.load(open(BASELINE)) if os.path.exists(BASELINE) else {}
    if '--update' in sys.argv:
        base.update({m: sorted(v) for m, v in results.items()})
        json.dump(base, open(BASELINE, 'w'), indent=1, ensure_ascii=False)
        print('baseline updated')
    elif '--check' in sys.argv:
        bad = {m: sorted(set(base.get(m, [])) - set(v)) for m, v in results.items()}
        bad = {m: v for m, v in bad.items() if v}
        for m, v in bad.items(): print(f'REGRESSION {m}: {v}')
        if bad: sys.exit(1)
        print('no regressions against baseline')

if __name__ == '__main__':
    main()
