-- GB/T 7714—2025 citations for any Quarto/pandoc format.
-- Metadata: `gbt7714: authoryear | numeric | note` (default authoryear).
-- The CSL branches on the presence of `language`, so we set it on CJK entries only.

local dir = pandoc.path.directory(PANDOC_SCRIPT_FILE)
local STYLES = { authoryear = true, numeric = true, note = true }

-- ponytail: CJK = UTF-8 lead bytes E3-E9 (U+3000-U+9FFF, incl. kana); misses rare Ext-B names.
local function has_cjk(v)
  local s = type(v) == 'string' and v or pandoc.utils.stringify(v or '')
  return s:find('[\227-\233][\128-\191][\128-\191]') ~= nil
end

local function is_cjk(r)
  if has_cjk(r.title) or has_cjk(r['container-title']) then return true end
  for _, role in ipairs({ 'author', 'editor', 'translator' }) do
    for _, n in ipairs(r[role] or {}) do
      if has_cjk(n.family) or has_cjk(n.literal) then return true end
    end
  end
  return false
end

-- Mirror bst `change.case$ "t"`: lowercase everything except the first character
-- and {braced} text (pandoc's bibtex reader turns those into Spans).
local function sentence_case(title)
  if title == nil or type(title) == 'string' then return title end
  local first = true
  return title:walk({
    Span = function(sp) first = false; return sp, false end,
    Str = function(s)
      local t = pandoc.text.lower(s.text)
      if first then t = pandoc.text.sub(s.text, 1, 1) .. pandoc.text.sub(t, 2); first = false end
      return pandoc.Str(t)
    end,
  })
end

-- biblatex types pandoc maps to an empty or lossy CSL type; the CSL expects these.
local BIBTYPE = {
  archive = 'collection', map = 'map', preprint = 'article', standard = 'standard',
  periodical = 'periodical', proceedings = 'paper-conference',
}

-- ponytail: regex scan of .bib files for `@type{key,`; CSL-JSON/YAML bibs carry correct types already.
local function bib_types(meta)
  local types, bibs = {}, meta.bibliography
  if bibs == nil then return types end
  if pandoc.utils.type(bibs) ~= 'List' then bibs = { bibs } end
  for _, b in ipairs(bibs) do
    local path = pandoc.utils.stringify(b)
    local f = path:match('%.bib$') and io.open(path)
    if f then
      for t, k in f:read('a'):gmatch('@(%w+)%s*{%s*([^,%s]+)%s*,') do
        types[k] = BIBTYPE[t:lower()]
      end
      f:close()
    end
  end
  return types
end

-- Note style, narrative `@key`: citeproc puts the full author list in the prose and
-- drops it from the note, and for repeat citations ("同N") the name vanishes entirely.
-- Instead write the short name ourselves (as the author-year in-text form: 张三等 /
-- Smith et al.) and keep a normal citation, so the note holds the complete entry.
local function narrative_to_text(doc, refs)
  local by_id = {}
  for _, r in ipairs(refs) do by_id[r.id] = r end
  return doc:walk({
    Cite = function(cite)
      local c = cite.citations
      if #c ~= 1 or c[1].mode ~= 'AuthorInText' then return nil end
      local r = by_id[c[1].id]
      local names = r and (r.author or r.editor)
      if not names or #names == 0 then return nil end
      local name = pandoc.utils.stringify(names[1].family or names[1].literal or '')
      if #names >= 2 then name = name .. (r.language and '等' or ' et al.') end
      c[1].mode = 'NormalCitation'
      cite.citations = c
      return { pandoc.Str(name), cite }
    end,
  })
end

function Pandoc(doc)
  local style = pandoc.utils.stringify(doc.meta.gbt7714 or 'authoryear')
  if not STYLES[style] then
    error('gbt7714: unknown style "' .. style .. '" (use authoryear, numeric or note)')
  end
  if doc.meta.csl == nil then
    doc.meta.csl = pandoc.path.join({ dir, 'gbt7714-' .. style .. '.csl' })
  end

  local refs = pandoc.utils.references(doc)
  if #refs == 0 then return doc end
  local types = bib_types(doc.meta)
  for _, r in ipairs(refs) do
    r.type = types[r.id] or r.type
    if is_cjk(r) then
      r.language = 'zh'
    else
      r.language = nil
      r.title = sentence_case(r.title)
    end
  end
  doc.meta.references = refs
  doc.meta.bibliography = nil
  if style == 'note' then doc = narrative_to_text(doc, refs) end
  return doc
end
