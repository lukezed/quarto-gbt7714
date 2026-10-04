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
    for _, v in ipairs(NAME_VARS) do
      if r[v] then for i, n in ipairs(r[v]) do r[v][i] = format_name(n) end end
    end
  end
  doc.meta.references = refs
  doc.meta.bibliography = nil
  return doc
end
