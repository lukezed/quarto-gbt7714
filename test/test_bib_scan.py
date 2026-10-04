"""Regression check for gbt7714.lua's raw .bib scan: BOM, indented entries, .BIB extension,
quoted/bare values, field-like text inside an abstract, date-only year in the sort key.
Usage: python3 test/test_bib_scan.py
"""
import os, subprocess

HERE = os.path.dirname(os.path.abspath(__file__))
LUA = os.path.join(HERE, '..', '_extensions', 'gbt7714', 'gbt7714.lua')
out = subprocess.run(['pandoc', '-f', 'markdown', '-t', 'plain', '--wrap=none',
                      '-M', 'bibliography=bib_edge.BIB', '-M', 'gbt7714=authoryear',
                      '-L', LUA, '--citeproc'],
                     input='[@std1; @dateonly; @yearonly]', cwd=HERE,
                     capture_output=True, text=True, check=True).stdout
print(out)
assert '[S]' in out, 'BOM/indent/.BIB/quoted langid: @standard not recognised'
assert '信息与文献 资源描述' in out, '\\quad title not restored'
assert out.index('只有年份') < out.index('只有日期'), 'date-only entry (2025) should sort after 2021'
print('ok')
