-- GB/T 7714—2025 citations for any Quarto/pandoc format.
-- Metadata: `gbt7714: authoryear | numeric | note` (default authoryear).
-- The CSL branches on the presence of `language`, so we set it on CJK entries only
-- (CJK as the bst decides it: langid/language field, else script detection).

local dir = pandoc.path.directory(PANDOC_SCRIPT_FILE)
local STYLES = { authoryear = true, numeric = true, note = true }

-- ponytail: CJK = UTF-8 lead bytes E3-E9 (U+3000-U+9FFF, incl. kana); misses rare Ext-B names.
local function has_cjk(v)
  local s = type(v) == 'string' and v or pandoc.utils.stringify(v or '')
  return s:find('[\227-\233][\128-\191][\128-\191]') ~= nil
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

local function fullwidth_str(s)
  return (s:gsub(', ', '，'):gsub(': ', '：'):gsub('; ', '；'):gsub('!', '！'):gsub('%?', '？')
    :gsub(' ?%(', '（'):gsub('%) ?', '）'))
end

-- bst change.case$ "t" on a raw bib string: lowercase ASCII outside {braces}, keep the first char.
local function sentence_case_raw(s)
  local depth, out = 0, {}
  for i = 1, #s do
    local c = s:sub(i, i)
    if c == '{' then depth = depth + 1
    elseif c == '}' then depth = depth - 1
    else out[#out + 1] = (depth == 0 and #out > 0) and c:gsub('[A-Z]', string.lower) or c end
  end
  return table.concat(out)
end
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
        local before = nxt and nxt.t == 'Str' and nxt.text:match('^%(')
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

-- Mirror bst `format.name`: names are pre-formatted here and the CSL prints given as-is
-- (no initialize-with). CJK family: keep given only if it is CJK too. Cyrillic: drop dots.
-- Latin: full given if it is pinyin (bst CTL_check_pinyin), else initials ("D E", "J-L").
local PINYIN = {}
for w in ('a ai an ang ao ba bai ban bang bao bei ben beng bi bian biao bie bin bing bo bu ca cai can cang cao ce cen ceng cha chai chan chang chao che chen cheng chi chong chou chu chuai chuan chuang chui chun chuo ci cong cou cu cuan cui cun cuo da dai dan dang dao de dei deng di dia dian diao die ding diu dong dou du duan dui dun duo e ei en eng er fa fan fang fei fen feng fo fou fu ga gai gan gang gao ge gei gen geng gong gou gu gua guai guan guang gui gun guo ha hai han hang hao he hei hen heng hong hou hu hua huai huan huang hui hun huo ji jia jian jiang jiao jie jin jing jiong jiu ju juan jue jun ka kai kan kang kao ke ken keng kong kou ku kua kuai kuan kuang kui kun kuo la lai lan lang lao le lei leng li lia lian liang liao lie lin ling liu long lou lu luan lun luo lyu lyue ma mai man mang mao me mei men meng mi mian miao mie min ming miu mo mou mu na nai nan nang nao ne nei nen neng ni nian niang niao nie nin ning niu nong nu nuan nuo nyu nyue o ou pa pai pan pang pao pei pen peng pi pian piao pie pin ping po pou pu qi qia qian qiang qiao qie qin qing qiong qiu qu quan que qun ran rang rao re ren reng ri rong rou ru ruan rui run ruo sa sai san sang sao se sen seng sha shai shan shang shao she shei shen sheng shi shou shu shua shuai shuan shuang shui shun shuo si song sou su suan sui sun suo ta tai tan tang tao te teng ti tian tiao tie ting tong tou tu tuan tui tun tuo wa wai wan wang wei wen weng wo wu xi xia xian xiang xiao xie xin xing xiong xiu xu xuan xue xun ya yan yang yao ye yi yin ying yong you yu yuan yue yun za zai zan zang zao ze zei zen zeng zha zhai zhan zhang zhao zhe zhei zhen zheng zhi zhong zhou zhu zhua zhuai zhuan zhuang zhui zhun zhuo zi zong zou zu zuan zui zun zuo'):gmatch('%S+') do PINYIN[w] = true end

local function is_cap(w) return w:match('^[A-Z][a-z]*$') ~= nil end
local function syllable(w) return PINYIN[w:lower()] == true end
local function two_syllables(w)
  w = w:lower()
  if PINYIN[w] then return true end
  for i = 1, #w - 1 do
    if PINYIN[w:sub(1, i)] and PINYIN[w:sub(i + 1)] then return true end
  end
  return false
end
local function hyphenated(w)
  local a, b = w:match('^([^-]+)-([^-]+)$')
  return a ~= nil and is_cap(a) and syllable(a) and is_cap(b) and syllable(b)
end
local function pinyin_name(n)
  local fam, giv = n.family or '', n.given or ''
  if fam == '' or giv == '' or n['non-dropping-particle'] or n['dropping-particle'] or n.suffix then
    return false
  end
  local fam_ok = fam:find('-') and hyphenated(fam) or (is_cap(fam) and syllable(fam))
  if not fam_ok then return false end
  if giv:find('-') then return hyphenated(giv) end
  giv = giv:gsub('’', "'")
  local a, b = giv:match("^([^']+)'([^']+)$")
  if a then return is_cap(a) and syllable(a) and b:match('^[a-z]+$') ~= nil and syllable(b) end
  return is_cap(giv) and two_syllables(giv)
end

local NAME_VARS = { 'author', 'editor', 'translator', 'container-author', 'collection-editor',
                    'composer', 'director', 'illustrator', 'interviewer', 'recipient' }

local function initials(given)
  local out = {}
  for word in given:gmatch('%S+') do
    local parts = {}
    for part in word:gmatch('[^-]+') do
      parts[#parts + 1] = part:match('^[%z\1-\127\194-\244][\128-\191]*')
    end
    out[#out + 1] = table.concat(parts, '-')
  end
  return table.concat(out, ' ')
end

local function format_name(n)
  if n.literal then n.literal = fullwidth_str(n.literal) end  -- bst format.names punctuations
  if n.literal or not n.family then return n end
  local fam, giv = n.family, n.given
  if has_cjk(fam) then
    if giv and not has_cjk(giv) then n.given = nil end
  elseif fam:find('[\208-\211]') then  -- Cyrillic
    if giv then n.given = giv:gsub('%.', '') end
  elseif giv and not pinyin_name(n) then
    n.given = initials(giv)
  end
  if n.suffix then n.suffix = n.suffix:gsub('%.', '') end
  return n
end

local PERIODICAL_TYPES = { article = true, ['article-journal'] = true, ['article-magazine'] = true,
                          ['article-newspaper'] = true, periodical = true }

-- container-title holds the bst `booktitle` for these types (sentence-cased like title).
local BOOKTITLE_TYPES = { chapter = true, ['paper-conference'] = true,
                          ['entry-dictionary'] = true, ['entry-encyclopedia'] = true }

-- biblatex types pandoc maps to an empty or lossy CSL type; the CSL expects these.
local BIBTYPE = {
  archive = 'collection', map = 'map', preprint = 'article', standard = 'standard',
  periodical = 'periodical', proceedings = 'paper-conference',
}

-- ponytail: regex scan of .bib files for `@type{key, field = {value}, ...}`; CSL-JSON/YAML bibs
-- carry correct types already. Ceiling: values must be {braced} (not "quoted" or bare macros).
-- Returns key -> { type = biblatex type, <field> = raw value } for fields pandoc drops.
local RAW_FIELDS = { year = true, booktitle = true, holder = true, scale = true, dimensions = true, cstr = true, eid = true,
                     archiveprefix = true, eprinttype = true,
                     -- bst sort key and set.entry.lang
                     key = true, organization = true, langid = true, language = true, title = true, author = true,
                     journal = true, journaltitle = true, address = true, location = true, publisher = true }

local function bib_scan(meta)
  local entries, bibs = {}, meta.bibliography
  if bibs == nil then return entries end
  if pandoc.utils.type(bibs) ~= 'List' then bibs = { bibs } end
  for _, b in ipairs(bibs) do
    local path = pandoc.utils.stringify(b)
    local f = path:match('%.bib$') and io.open(path)
    if f then
      local text = '\n' .. f:read('a')
      f:close()
      for chunk in text:gsub('\n@', '\0@'):gmatch('%z@([^%z]*)') do
        local t, k, body = chunk:match('^(%w+)%s*{%s*([^,%s]+)%s*,(.*)$')
        if not t then goto continue end
        local e = { type = t:lower() }
        for name, val in body:gmatch('([%w_-]+)%s*=%s*"([^"]*)"') do  -- quoted / bare values
          if RAW_FIELDS[name:lower()] then e[name:lower()] = val end
        end
        for name, val in body:gmatch('([%w_-]+)%s*=%s*(%d+)%s*[,}\n]') do
          if RAW_FIELDS[name:lower()] then e[name:lower()] = val end
        end
        for name, val in body:gmatch('([%w_-]+)%s*=%s*(%b{})') do
          name = name:lower()
          if RAW_FIELDS[name] then
            e[name] = val:sub(2, -2):gsub('[{}]', '')
            e[name .. '_braced'] = val:sub(2, -2)
          end
        end
        entries[k] = e
        ::continue::
      end
    end
  end
  return entries
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
-- Note style: @key -> Author + normal citation, so the note keeps the full entry (citeproc
-- would move the author list into the prose, and drop the name on "同N" repeats).
local function gbt_cites(doc, refs, note)
  local byid = {}
  for _, r in ipairs(refs) do byid[r.id] = r end
  return doc:walk({
    Cite = function(c)
      if #c.citations ~= 1 then return nil end
      local ct = c.citations[1]
      local out = pandoc.Inlines({})
      if ct.mode == 'AuthorInText' then
        local a = intext_author(byid[ct.id])
        if a then out:insert(pandoc.Str(a)); ct.mode = note and 'NormalCitation' or 'SuppressAuthor' end
      end
      local loc = page_locator(ct.suffix)
      if note then
        -- under lang: zh citeproc only knows "页"; a bare number is read as a page locator
        if loc then ct.suffix = pandoc.Inlines({ pandoc.Str(','), pandoc.Space(), pandoc.Str(loc) }) end
        c.citations = { ct }; out:insert(c); return out
      end
      if loc then ct.suffix = pandoc.Inlines({}) end
      c.citations = { ct }
      out:insert(c)
      if loc then out:insert(pandoc.Superscript({ pandoc.Str(loc) })) end
      return out
    end,
  })
end

-- Raw .bib fields the bst sorts on but pandoc drops or reshapes (key, year, langid, ...).
-- ponytail: one-field-per-line parse (`name = {value},`); multi-line values keep only line 1,
-- which is enough for key/year/langid/organization and for script detection.
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
  local raw = bib_scan(doc.meta)
  for _, r in ipairs(refs) do
    local e = raw[r.id] or {}
    local elang = entry_lang(e, r)  -- bst set.entry.lang
    -- pandoc drops \quad, which GB/T titles use between title elements (信息与文献\quad 资源描述)
    -- ponytail: rebuilt via the LaTeX reader, so {braced} protection in such titles is lost
    if e.title_braced and e.title_braced:find('\\quad') then
      local t = e.title_braced:gsub('\\quad%s*', '\u{2003}')
      r.title = pandoc.utils.blocks_to_inlines(pandoc.read(t, 'latex').blocks)
    end
    r['gbt-sort'] = bst_sort_key(e, r, elang)
    r.type = BIBTYPE[e.type] or r.type
    -- fields pandoc drops; bst uses holder (patent assignee) in place of the inventors
    if e.holder then
      r.author = {}
      for h in (e.holder .. ' and '):gmatch('(.-)%s+and%s+') do table.insert(r.author, { literal = h }) end
    end
    r.scale = r.scale or e.scale
    r.dimensions = r.dimensions or (e.dimensions and e.dimensions:gsub('\\,', '\u{2009}'))
    if e.cstr then  -- bst format.doi: CSTR replaces DOI, and is omitted when the URL contains it
      r.doi = nil
      if not (r.url and pandoc.utils.stringify(r.url):find(e.cstr, 1, true)) then r.CSTR = e.cstr end
    end
    if not r.page and e.eid then r.page = e.eid end
    if r.type == 'periodical' then
      -- bst `periodical`: no container; volume/year ranges with full-width punctuation and "—"
      r['container-title'] = nil
      if r.volume then
        r.volume = fullwidth_str(pandoc.utils.stringify(r.volume)):gsub('%-', '—')
      end
      if e.year and e.year:find('-') then r.issued = { literal = e.year:gsub('%-', '—') } end
    end
    -- bst article.journal: without volume/number the journal is followed by the date only
    -- when it is a full date. Passed as event-date: pandoc's metadata reader does not parse
    -- available-date as a date, and event-date is otherwise unused on journal articles.
    local dp = r.issued and r.issued['date-parts'] and r.issued['date-parts'][1]
    if (r.type == 'article-journal' or r.type == 'article-magazine') and not r.volume and not r.issue
      and not r['event-date'] and dp and #dp == 3 then
      r['event-date'] = { ['date-parts'] = { { dp[1], dp[2], dp[3] } } }
    end
    if r.type == 'article' and not r.publisher then r.publisher = e.archiveprefix or e.eprinttype end
    local lang = r.language and pandoc.utils.stringify(r.language):lower() or ''
    local cjk = elang == 'zh' or elang == 'ja' or elang == 'ko'  -- bst is.lang.cjk
    local en = elang == 'en'
    if r.type == 'map' and e.booktitle and not r['container-title'] then  -- map in an atlas
      r['container-title'] = fullwidth_str(en and sentence_case_raw(e.booktitle_braced) or e.booktitle)
    end
    r.edition = edition(r.edition, cjk, lang)
    if r.volume and not PERIODICAL_TYPES[r.type] then  -- bst format.bvolume (books, maps, ...)
      local v = pandoc.utils.stringify(r.volume)
      if v:match('^%d+$') then
        r.volume = (lang:match('^ko') or lang == 'korean') and ('제 ' .. v .. ' 권')
          or cjk and ('第 ' .. v .. ' 卷') or ('v.' .. v)
      end
    end
    if cjk then
      r.language = 'zh'
    else
      r.language = nil
      -- bst change.sentence.case: English entries only; periodical titles kept
      if en and r.type ~= 'periodical' then r.title = sentence_case(r.title) end
      if en and BOOKTITLE_TYPES[r.type] then r['container-title'] = sentence_case(r['container-title']) end
    end
    r['event-title'] = r['event-title'] or r.event
    -- bst format.doi: no DOI when the URL already contains it
    if r.doi and r.url and pandoc.utils.stringify(r.url):find(pandoc.utils.stringify(r.doi), 1, true) then
      r.doi = nil
    end
    for _, f in ipairs(FW_FIELDS) do r[f] = fullwidth(r[f]) end
    for _, v in ipairs(NAME_VARS) do
      if r[v] then for i, n in ipairs(r[v]) do r[v][i] = format_name(n) end end
    end
  end
  doc.meta.references = refs
  doc.meta.bibliography = nil
  doc = gbt_cites(doc, refs, style == 'note')
  return doc
end
