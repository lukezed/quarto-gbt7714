-- GB/T 7714—2025 citations for any Quarto/pandoc format.
-- Metadata: `gbt7714: authoryear | numeric | note` (default authoryear).
-- The CSL branches on the presence of `language`, so we set it on CJK entries only
-- (CJK as the bst decides it: langid/language field, else script detection).

local dir = pandoc.path.directory(PANDOC_SCRIPT_FILE)
local STYLES = { authoryear = true, numeric = true, note = true }

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

-- Raw .bib fields the bst sorts on but pandoc drops or reshapes (key, year, langid, ...).
-- ponytail: one-field-per-line parse (`name = {value},`); multi-line values keep only line 1,
-- which is enough for key/year/langid/organization and for script detection.
local function bib_entries(meta)
  local entries, bibs = {}, meta.bibliography
  if bibs == nil then return entries end
  if pandoc.utils.type(bibs) ~= 'List' then bibs = { bibs } end
  for _, b in ipairs(bibs) do
    local path = pandoc.utils.stringify(b)
    local f = path:match('%.bib$') and io.open(path)
    if f then
      local cur
      for line in f:read('a'):gmatch('[^\n]+') do
        local t, k = line:match('^%s*@(%w+)%s*{%s*([^,%s]+)%s*,')
        if t then
          cur = { type = t:lower() }
          entries[k] = cur
        elseif cur then
          local name, val = line:match('^%s*([%w_-]+)%s*=%s*(.-)%s*,?%s*$')
          if name then
            val = val:gsub('^[{"]', ''):gsub('[}"]$', '')
            cur[name:lower()] = val
          end
        end
      end
      f:close()
    end
  end
  return entries
end

-- bst `sortify` = purify$ + lowercase: hyphens/ties/whitespace become spaces,
-- other ASCII punctuation goes, bytes >= 128 (CJK etc.) stay.
-- Explicit ASCII classes: %s/%w/lower() follow the C locale and can hit UTF-8 bytes (0x85, 0xA0).
local function sortify(s)
  s = s:gsub('[-~ \t\r\n\f\v]', ' '):gsub('[^0-9A-Za-z \128-\255]', '')
  return (s:gsub('[A-Z]', function(c) return string.char(c:byte() + 32) end))
end

local function str(v)
  if v == nil then return '' end
  return type(v) == 'string' and v or pandoc.utils.stringify(v)
end

-- bst get.str.lang: the "highest" script among all characters wins.
local SCRIPT_RANK = { other = 0, en = 1, ru = 2, zh = 3, ja = 4, ko = 5 }
local function script_of(cp)
  if cp < 128 then
    return (cp >= 65 and cp <= 90 or cp >= 97 and cp <= 122) and 'en' or 'other'
  elseif cp >= 1024 and cp <= 1327 then return 'ru'
  elseif cp >= 19968 and cp <= 40959 or cp >= 13312 and cp <= 19903 then return 'zh'
  elseif cp >= 12352 and cp <= 12543 then return 'ja'
  elseif cp >= 44032 and cp <= 55215 then return 'ko'
  end
  return 'other'
end

local LANGID = {
  english = 'en', american = 'en', british = 'en', chinese = 'zh',
  japanese = 'ja', korean = 'ko', russian = 'ru',
}

-- bst set.entry.lang: langid/language field, else detect from the first non-empty field.
local function entry_lang(raw, r)
  local id = raw.langid or raw.language
  if id and id ~= '' then return LANGID[id:lower()] or 'other' end
  local text = ''
  for _, v in ipairs({
    raw.title or str(r.title), raw.author or '', raw.journal or '', raw.journaltitle or '',
    raw.booktitle or str(r['container-title']), raw.address or '', raw.location or '',
    raw.publisher or str(r.publisher),
  }) do
    if v ~= '' then text = v; break end
  end
  local lang = 'other'
  for _, cp in utf8.codes(text, true) do
    local s = script_of(cp)
    if SCRIPT_RANK[s] > SCRIPT_RANK[lang] then lang = s end
  end
  return lang
end

-- bst sort.format.names with "{vv{ } }{ll{ }}{  ff{ }}{  jj{ }}".
local function sort_names(names, year)
  local out
  for i, n in ipairs(names) do
    local t = str(n.literal)
    if t == '' then
      local von = table.concat({ str(n['dropping-particle']), str(n['non-dropping-particle']) }, ' '):gsub('^ +', ''):gsub(' +$', '')
      t = (von ~= '' and von .. ' ' or '') .. str(n.family)
      if str(n.given) ~= '' then t = t .. '  ' .. str(n.given) end
      if str(n.suffix) ~= '' then t = t .. '  ' .. str(n.suffix) end
    end
    if i == 1 then
      out = sortify(t)
    else
      out = out .. '   ' .. ((#names > 2 and i == 2) and ('zz' .. year .. '   ') or '') .. sortify(t)
    end
  end
  return out
end

-- bst presort / bib.sort.order: language order, then `key` or names, then year, then cite key.
-- Hex-encoded so citeproc's collation reproduces bibtex's plain byte order
-- (CJK without `key` sorts by code point, after any pinyin `key`).
local LANG_ORDER = { zh = 1, ja = 2, en = 3, ru = 4 }
local function bst_sort_key(raw, r, lang)
  local year = raw.year or ''
  local function names(list) return list and #list > 0 and sort_names(list, year) or nil end
  local who = raw.key
  if who == nil or who == '' then
    local anon = lang == 'zh' and 'yi4 ming2' or 'anon'
    local t = raw.type
    if t == 'book' or (t == 'inbook' and raw.booktitle) then
      who = names(r.author) or names(r.editor) or anon
    elseif t == 'collection' or t == 'proceedings' then
      who = names(r.editor)
        or (raw.organization and sortify((raw.organization:gsub('^The ', ''))))
        or anon
    else
      who = names(r.author) or anon
    end
  end
  local s = string.char(64 + (LANG_ORDER[lang] or 5)) .. '    ' .. who .. '    '
    .. sortify(year) .. '    ' .. r.id
  return (s:sub(1, 250):gsub('.', function(c) return string.format('%02x', c:byte()) end))
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
  local raw = bib_entries(doc.meta)
  for _, r in ipairs(refs) do
    local lang = entry_lang(raw[r.id] or {}, r)
    r['gbt-sort'] = bst_sort_key(raw[r.id] or {}, r, lang)
    r.type = types[r.id] or r.type
    if lang == 'zh' or lang == 'ja' or lang == 'ko' then  -- bst is.lang.cjk
      r.language = 'zh'
    else
      r.language = nil
      r.title = sentence_case(r.title)
    end
  end
  doc.meta.references = refs
  doc.meta.bibliography = nil
  return doc
end
