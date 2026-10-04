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

-- Page locator in a citation suffix (", 42", ", p. 42", ", pp. 11-13"), or nil.
local function page_locator(suffix)
  local s = pandoc.utils.stringify(suffix or {}):gsub('\194\160', ' ')  -- pandoc puts nbsp after "pp."
  s = s:gsub('^%s*,?%s*', ''):gsub('%s*$', '')
  s = s:gsub('^[Pp]+%.%s*', ''):gsub('^pages?%s+', '')
  return s:gsub('–', '-'):match('^%d[%d%-, ]*$')
end

-- In-text author like the CSL's (et-al-min 2): "Falout et al." / "张群 等".
-- ponytail: no given-name disambiguation; add if two cited authors share a family name.
local function intext_author(r)
  local names = r and (r.author or r.editor)
  if not names or #names == 0 then return nil end
  local n = names[1]
  local name = n.literal or n.family
  if not name then return nil end
  if n['non-dropping-particle'] then name = n['non-dropping-particle'] .. ' ' .. name end
  if #names > 1 then name = name .. (r.language and ' 等' or ' et al.') end
  return name
end

-- GB/T 7714 citation forms the CSL cannot express (bst \citet and locator placement):
--   @key          -> Author + citation with author suppressed: "Boobier（2020）", "Boobier[1]"
--   [@key, 42]    -> page as a superscript after the closing bracket: "（Boobier，2020）⁴²", "[1]⁴²"
local function gbt_cites(doc, refs)
  local byid = {}
  for _, r in ipairs(refs) do byid[r.id] = r end
  return doc:walk({
    Cite = function(c)
      if #c.citations ~= 1 then return nil end
      local ct = c.citations[1]
      local out = pandoc.Inlines({})
      if ct.mode == 'AuthorInText' then
        local a = intext_author(byid[ct.id])
        if a then out:insert(pandoc.Str(a)); ct.mode = 'SuppressAuthor' end
      end
      local loc = page_locator(ct.suffix)
      if loc then ct.suffix = pandoc.Inlines({}) end
      c.citations = { ct }
      out:insert(c)
      if loc then out:insert(pandoc.Superscript({ pandoc.Str(loc) })) end
      return out
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
  if style ~= 'note' then doc = gbt_cites(doc, refs) end
  return doc
end
