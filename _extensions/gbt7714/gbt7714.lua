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
  -- Explicit langid wins, as in bst `is.lang.cjk` (pandoc keeps it as `language`).
  local lang = r.language and pandoc.utils.stringify(r.language):lower()
  if lang and lang ~= '' then
    return lang:match('^zh') or lang:match('^ja') or lang:match('^ko')
      or lang == 'chinese' or lang == 'japanese' or lang == 'korean' or false
  end
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
    traverse = 'topdown',  -- so a Span is seen (and skipped) before its Strs
    Span = function(sp) first = false; return sp, false end,
    Str = function(s)
      local t = s.text:gsub('[A-Z]', string.lower)  -- ASCII only, like bst change.case$; string.lower alone mangles UTF-8
      if first then t = s.text:sub(1, 1) .. t:sub(2); first = false end
      return pandoc.Str(t)
    end,
  })
end

-- Mirror bst `convert.fullwidth.punctuations` (default CTL_bib_punct = GB, all languages):
-- ", " ": " "; " -> ，：；  "!" "?" -> ！？  "(" ")" -> （）, dropping the adjacent space.
local FW_TRAIL = { [','] = '，', [':'] = '：', [';'] = '；' }
local FW_FIELDS = { 'title', 'container-title', 'collection-title', 'volume-title',
                    'publisher', 'publisher-place', 'event-title', 'event-place' }

local function fullwidth(x)
  if x == nil or type(x) == 'string' then return x end
  return x:walk({ Inlines = function(ils)
    local out = pandoc.Inlines{}
    for i, el in ipairs(ils) do
      local nxt = ils[i + 1]
      if el.t == 'Str' then
        local t = el.text:gsub('!', '！'):gsub('%?', '？'):gsub('%(', '（'):gsub('%)', '）')
        local last = t:sub(-1)
        if FW_TRAIL[last] and nxt and nxt.t == 'Space' then t = t:sub(1, -2) .. FW_TRAIL[last] end
        el = pandoc.Str(t)
      elseif el.t == 'Space' then
        local prev = out[#out]
        local after = prev and prev.t == 'Str' and prev.text:match('[，：；！？）]$')
        local before = nxt and nxt.t == 'Str' and nxt.text:match('^（')
        if after or before then el = nil end
      end
      if el then out:insert(el) end
    end
    return out
  end })
end

-- Mirror bst `format.edition`: ordinal words -> numbers, 1st edition omitted,
-- then "3 版" / "5th ed." / "5 изд."; other text (修订版, 新1版) is kept.
local WORDNUM = { first = 1, second = 2, third = 3, fourth = 4, fifth = 5,
                  sixth = 6, seventh = 7, eighth = 8, ninth = 9, tenth = 10 }
local REVISED = { ['revised edition'] = 'Rev. ed.', ['revised ed.'] = 'Rev. ed.',
                  revised = 'Rev. ed.', ['rev.'] = 'Rev. ed.', ['修订'] = '修订版' }

local function edition(e, cjk, lang)
  if e == nil then return nil end
  local s = pandoc.utils.stringify(e)
  local n = s:match('^(%d+)') or WORDNUM[s:lower()]
  if not n then return REVISED[s:lower()] or s end
  n = tostring(n)
  if n == '1' then return nil end
  if cjk then return n .. ' 版' end
  if lang:match('^ru') then return n .. ' изд.' end
  local suf = (n:sub(-2, -2) == '1' and 'th') or ({ ['1'] = 'st', ['2'] = 'nd', ['3'] = 'rd' })[n:sub(-1)] or 'th'
  return n .. suf .. ' ed.'
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
    local lang = r.language and pandoc.utils.stringify(r.language):lower() or ''
    local cjk = is_cjk(r)
    r.edition = edition(r.edition, cjk, lang)
    if cjk then
      r.language = 'zh'
    else
      r.language = nil
      r.title = sentence_case(r.title)
    end
    for _, f in ipairs(FW_FIELDS) do r[f] = fullwidth(r[f]) end
  end
  doc.meta.references = refs
  doc.meta.bibliography = nil
  return doc
end
