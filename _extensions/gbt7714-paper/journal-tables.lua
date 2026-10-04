-- Longtable cannot run in two-column LaTeX. After Quarto resolves table
-- cross-references, render journal tables as ordinary column-width floats.
-- Tables must fit on a page; use manuscript layout for multipage tables.
function Pandoc(doc)
  if not quarto.doc.is_format('pdf') or
      pandoc.utils.stringify(doc.meta['paper-style'] or '') ~= 'journal' then
    return doc
  end
  return doc:walk({Table = function(tbl)
    local latex = pandoc.write(pandoc.Pandoc({tbl}), 'latex')
    local caption = ''
    latex = latex:gsub('(\\caption.-)\\tabularnewline', function(value)
      caption = value
      return ''
    end, 1)
    -- Keep the first header, omit the repeated continuation header, and move
    -- the final footer to the end of the single-page tabular.
    latex = latex:gsub('\\endfirsthead.-\\endhead', '')
    latex = latex:gsub('\\endhead', ''):gsub('\\endfoot', '')
    local footer = ''
    latex = latex:gsub('(.-)\\endlastfoot', function(before)
      local start = before:find('\\bottomrule', 1, true)
      if start then footer = before:sub(start); return before:sub(1, start - 1) end
      return before
    end, 1)
    latex = latex:gsub('\\begin{longtable}%b[]', '\\begin{tabular}', 1)
    latex = latex:gsub('\\end{longtable}', function() return footer .. '\n\\end{tabular}' end, 1)
    if caption ~= '' then
      latex = '\\begin{table}[htbp]\n\\centering\n' .. caption .. '\n' .. latex .. '\n\\end{table}'
    end
    return pandoc.RawBlock('latex', latex)
  end})
end
