"""Golden test: upstream gbt7714 bst (bibtex) vs our CSL (pandoc citeproc), entry by entry.

Usage: python3 test/compare.py authoryear|numeric [-v]
Prints the share of identical entries, whether the sort order matches, and (-v) each diff.
"""
import html, json, os, re, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
UP = os.path.join(HERE, 'upstream')
EXT = os.path.join(HERE, '..', '_extensions', 'gbt7714')
BIB = os.path.join(UP, 'gbt7714-examples.bib')
CJK = r'[\u3000-\u9fff\uff00-\uffef]'

def norm(s):
    s = s.replace('\u2019', "'").replace('\u2013', '--')  # typography only, not a style difference
    s = re.sub(r'\s+', ' ', s).strip()
    return re.sub(rf'(?<={CJK}) (?={CJK})', '', s)

def bst(style):
    with tempfile.TemporaryDirectory() as d:
        open(os.path.join(d, 'a.aux'), 'w').write(
            f'\\citation{{*}}\n\\bibstyle{{{os.path.join(UP, "gbt7714-" + style)}}}\n\\bibdata{{{BIB[:-4]}}}\n')
        subprocess.run(['bibtex', 'a'], cwd=d, capture_output=True)
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
        body = body.replace('\\&', '&').replace('\\_', '_').replace('\\%', '%').replace('\\$', '$').replace('~', ' ')
        body = re.sub(r'\\[a-zA-Z]+\s*', '', body).replace('{', '').replace('}', '')
        out.append((key, norm(body)))
    return out

def csl(style):
    md = '---\nnocite: "@*"\n---\n'
    r = subprocess.run(['pandoc', '-f', 'markdown', '-t', 'html', '--wrap=none',
                        '-M', f'bibliography={BIB}', '-M', f'gbt7714={style}', '-M', 'lang=zh-u-co-pinyin',
                        '-L', os.path.join(EXT, 'gbt7714.lua'), '--citeproc'],
                       input=md, capture_output=True, text=True)
    if r.returncode: sys.exit(r.stderr)
    out = []
    for chunk in r.stdout.split('<div id="ref-')[1:]:
        key, body = chunk.split('"', 1)
        body = body.split('>', 1)[1]
        out.append((html.unescape(key), norm(html.unescape(re.sub(r'<[^>]+>', '', body)))))
    return out

def main():
    style, verbose = sys.argv[1], '-v' in sys.argv
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

if __name__ == '__main__':
    main()
