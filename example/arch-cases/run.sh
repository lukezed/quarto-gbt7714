#!/bin/sh
# Regression checks for the citeproc integration; exit 1 on the first failed assertion.
cd "$(dirname "$0")"
fail() { echo "FAIL: $1"; exit 1; }
has() { grep -q -- "$2" "$1" || fail "$1 lacks: $2"; }
lacks() { ! grep -q -- "$2" "$1" || fail "$1 has: $2"; }
for s in numeric authoryear note margin owncsl citeas2; do quarto render $s.qmd --to html >/dev/null 2>&1 || fail "render $s"; done
quarto render numeric.qmd --to gfm -o numeric-gfm.md >/dev/null 2>&1 || fail "render gfm"
for s in numeric authoryear note; do
  has $s.html 'id="quarto-bibliography"'          # heading + appendix, as without the filter
  has $s.html '参考文献'
  has $s.html 'href="#tbl-a"'                     # crossref resolved
done
has numeric.html '>1</a>-<a'                        # [1-3] compressed, links kept
has numeric.html 'nosuchkey?'                       # typo shown, valid key in the same cite kept
has numeric.html 'data-cites="d nosuchkey"'
has numeric.html 'id="ref-d"'
has margin.html 'class="csl-entry'                  # margin citations present
lacks numeric-gfm.md '<span class="citation"'
pandoc owncsl.html -t plain --wrap=none > owncsl.txt
has owncsl.txt '两篇{a; b}，叙述 {c}'                  # user's own CSL: no GB/T rewrites
lacks owncsl.html '<sup>'
has citeas2.html '张三. T2\[J/OL\]'                 # cite-as uses the csl: given in YAML
echo "arch-cases: ok"
