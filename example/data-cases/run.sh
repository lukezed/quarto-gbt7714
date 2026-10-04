#!/bin/sh
# Print the numeric bibliography for the data cases (pandoc, user-default settings).
cd "$(dirname "$0")"
sed -n '/^---$/,/^---$/!p' cases.qmd > /tmp/claude-dc.md
pandoc /tmp/claude-dc.md -M bibliography=refs.bib -M bibliography=refs.json -M gbt7714="${1:-numeric}" \
  -L ../../_extensions/gbt7714/gbt7714.lua --citeproc -t plain --wrap=none | sed '/^\s*$/d'
