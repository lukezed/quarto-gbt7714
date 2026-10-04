"""Regression check for gbt7714.lua's raw .bib scan: BOM, indented entries, .BIB extension,
quoted/bare values, field-like text inside an abstract, date-only year in the sort key,
CJK citekeys with spaces around them, CJK patent holders split on "and", a "quoted" Chinese title keeping its English capitals.
Usage: python3 test/test_bib_scan.py
"""
import os, subprocess

HERE = os.path.dirname(os.path.abspath(__file__))
LUA = os.path.join(HERE, '..', '_extensions', 'gbt7714', 'gbt7714.lua')
out = subprocess.run(['pandoc', '-f', 'markdown', '-t', 'plain', '--wrap=none',
                      '-M', 'bibliography=bib_edge.BIB', '-M', 'gbt7714=authoryear',
                      '-L', LUA, '--citeproc'],
                     input='[@std1; @dateonly; @yearonly; @标准2021; @pat1; @quoted1]', cwd=HERE,
                     capture_output=True, text=True, check=True).stdout
print(out)
assert '[S]' in out, 'BOM/indent/.BIB/quoted langid: @standard not recognised'
assert '信息与文献 资源描述' in out, '\\quad title not restored'
assert out.index('只有年份') < out.index('只有日期'), 'date-only entry (2025) should sort after 2021'
assert 'GB/T 3792—2021 信息与文献 资源描述（中文键）[S]' in out.replace('\u2003', ' '), 'CJK citekey: entry not scanned'
assert '文章，李四' in out, 'CJK holder split on "and" broken'
assert '基于 Python 的 BERT 文本分析' in out, '"quoted" CJK title lost its capitals (pandoc unTitlecase)'
print('ok')
