-- GB/T 7714—2025 citations for any Quarto/pandoc format.
-- Metadata: `gbt7714: authoryear | numeric | note` (default authoryear).
-- The CSL branches on the presence of `language`, so we set it on CJK entries only
-- (CJK as the bst decides it: langid/language field, else script detection).

local dir = pandoc.path.directory(PANDOC_SCRIPT_FILE)
local STYLES = { authoryear = true, numeric = true, note = true }

-- Lua's %s/%w/%a and string.lower follow the C locale, which under pandoc treats some UTF-8
-- bytes as space/letters (张 = E5 BC A0; 0xA0 matches %s). So: explicit ASCII classes everywhere
-- text may be non-ASCII, and this for case-folding.
local function ascii_lower(s) return (s:gsub('[A-Z]', string.lower)) end

-- Plain text of a metadata value that may be a string, Inlines or nil.
local function str(v)
  if v == nil then return '' end
  return type(v) == 'string' and v or pandoc.utils.stringify(v)
end

local function warning(msg)
  if quarto and quarto.log and quarto.log.warning then quarto.log.warning(msg) else io.stderr:write('[WARNING] ', msg, '\n') end
end

-- Quarto catches error() and may continue rendering; fail explicitly without a Lua traceback.
local function fatal(msg)
  io.stderr:write('ERROR: gbt7714: ', msg, '\n')
  os.exit(1)
end

-- The one CJK range (Han incl. Ext A/B+, kana, Hangul, CJK and full-width punctuation).
-- `script_of` is separate on purpose: it mirrors bst get.str.lang's per-script ranks.
local function is_cjk_cp(cp)
  return cp ~= nil and ((cp >= 0x1100 and cp <= 0x11FF) or (cp >= 0x2E80 and cp <= 0x9FFF)
    or (cp >= 0xA960 and cp <= 0xA97F) or (cp >= 0xAC00 and cp <= 0xD7AF)
    or (cp >= 0xF900 and cp <= 0xFAFF) or (cp >= 0xFF00 and cp <= 0xFFEF)
    or (cp >= 0x20000 and cp <= 0x3FFFF))
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

local function has_cjk(v)
  for _, cp in utf8.codes(str(v), true) do
    if is_cjk_cp(cp) then return true end
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
      local t = ascii_lower(s.text)  -- ASCII only, like bst change.case$
      if first then t = s.text:sub(1, 1) .. t:sub(2); first = false end
      return pandoc.Str(t)
    end,
  })
end

-- Mirror bst `convert.fullwidth.punctuations` (default CTL_bib_punct = GB, all languages):
-- ", " ": " "; " -> ，：；  "!" "?" -> ！？  "(" ")" -> （）, dropping the adjacent space.
local FW_TRAIL = { [','] = '，', [':'] = '：', [';'] = '；' }

-- Two forms of one rule: fullwidth_str for plain strings (literal names, volumes, raw bib
-- values), fullwidth (below) for pandoc Inlines, where spaces are separate elements.
local function fullwidth_str(s)
  return (s:gsub(', ', '，'):gsub(': ', '：'):gsub('; ', '；'):gsub('!', '！'):gsub('%?', '？')
    :gsub(' ?%(', '（'):gsub('%) ?', '）'))
end

-- bst change.case$ "t" on a raw bib string: lowercase ASCII outside {braces}, keep the first char.
-- Kept apart from sentence_case: it serves raw values pandoc never parsed (an atlas booktitle on
-- @map), where only the raw braces still mark protected text.
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

local FW_FIELDS = { 'title', 'container-title', 'collection-title', 'volume-title',
                    'publisher', 'publisher-place', 'event-title', 'event-place' }

-- Mirror bst `format.edition`: ordinal words -> numbers, 1st edition omitted; CJK (zh/ja/ko)
-- get no ordinal suffix; bbl.edition is 版 for zh/ja, изд. for ru, ed. otherwise:
-- "3 版", "5th ed.", "2 ed." (ko), "3rd изд." (ru, as upstream). Other text (修订版, 新1版) is kept.
local WORDNUM = { first = 1, second = 2, third = 3, fourth = 4, fifth = 5,
                  sixth = 6, seventh = 7, eighth = 8, ninth = 9, tenth = 10 }
local REVISED = { ['revised edition'] = 'Rev. ed.', ['revised ed.'] = 'Rev. ed.',
                  revised = 'Rev. ed.', ['rev.'] = 'Rev. ed.', ['修订'] = '修订版' }

local function edition(e, elang)
  if e == nil then return nil end
  local s = str(e)
  local n = s:match('^(%d+)') or WORDNUM[ascii_lower(s)]
  if not n then return REVISED[ascii_lower(s)] or s end
  n = tostring(n)
  if n == '1' then return nil end
  local term = (elang == 'zh' or elang == 'ja') and '版' or elang == 'ru' and 'изд.' or 'ed.'
  if elang == 'zh' or elang == 'ja' or elang == 'ko' then return n .. ' ' .. term end
  local suf = (n:sub(-2, -2) == '1' and 'th') or ({ ['1'] = 'st', ['2'] = 'nd', ['3'] = 'rd' })[n:sub(-1)] or 'th'
  return n .. suf .. ' ' .. term
end

-- Mirror bst `format.name`: names are pre-formatted here and the CSL prints given as-is
-- (no initialize-with). CJK family: keep given only if it is CJK too. Cyrillic: drop dots.
-- Latin: full given if it is pinyin (bst CTL_check_pinyin), else initials ("D E", "J-L").
local PINYIN = {}
for w in ('a ai an ang ao ba bai ban bang bao bei ben beng bi bian biao bie bin bing bo bu ca cai can cang cao ce cen ceng cha chai chan chang chao che chen cheng chi chong chou chu chuai chuan chuang chui chun chuo ci cong cou cu cuan cui cun cuo da dai dan dang dao de dei deng di dia dian diao die ding diu dong dou du duan dui dun duo e ei en eng er fa fan fang fei fen feng fo fou fu ga gai gan gang gao ge gei gen geng gong gou gu gua guai guan guang gui gun guo ha hai han hang hao he hei hen heng hong hou hu hua huai huan huang hui hun huo ji jia jian jiang jiao jie jin jing jiong jiu ju juan jue jun ka kai kan kang kao ke ken keng kong kou ku kua kuai kuan kuang kui kun kuo la lai lan lang lao le lei leng li lia lian liang liao lie lin ling liu long lou lu luan lun luo lyu lyue ma mai man mang mao me mei men meng mi mian miao mie min ming miu mo mou mu na nai nan nang nao ne nei nen neng ni nian niang niao nie nin ning niu nong nu nuan nuo nyu nyue o ou pa pai pan pang pao pei pen peng pi pian piao pie pin ping po pou pu qi qia qian qiang qiao qie qin qing qiong qiu qu quan que qun ran rang rao re ren reng ri rong rou ru ruan rui run ruo sa sai san sang sao se sen seng sha shai shan shang shao she shei shen sheng shi shou shu shua shuai shuan shuang shui shun shuo si song sou su suan sui sun suo ta tai tan tang tao te teng ti tian tiao tie ting tong tou tu tuan tui tun tuo wa wai wan wang wei wen weng wo wu xi xia xian xiang xiao xie xin xing xiong xiu xu xuan xue xun ya yan yang yao ye yi yin ying yong you yu yuan yue yun za zai zan zang zao ze zei zen zeng zha zhai zhan zhang zhao zhe zhei zhen zheng zhi zhong zhou zhu zhua zhuai zhuan zhuang zhui zhun zhuo zi zong zou zu zuan zui zun zuo'):gmatch('%S+') do PINYIN[w] = true end

local function is_cap(w) return w:match('^[A-Z][a-z]*$') ~= nil end
local function syllable(w) return PINYIN[ascii_lower(w)] == true end
local function two_syllables(w)
  w = ascii_lower(w)
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
  for word in given:gmatch('[^ \t\r\n]+') do  -- not %S: pandoc's locale treats UTF-8 bytes 0x85/0xA0 as space
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
  elseif fam ~= '' and script_of(utf8.codepoint(fam, 1)) == 'ru' then  -- Cyrillic
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

-- ponytail: pattern scan of .bib files for `@type{key, field = value, ...}`; CSL-JSON/YAML bibs
-- carry correct types already. Ceiling: no @string expansion or # concatenation (see bib_fields).
-- Returns key -> { type = biblatex type, <field> = raw value } for fields pandoc drops.
local RAW_FIELDS = { year = true, booktitle = true, holder = true, scale = true, dimensions = true, cstr = true, eid = true,
                     archiveprefix = true, eprinttype = true,
                     -- bst sort key and set.entry.lang
                     key = true, organization = true, langid = true, language = true, title = true, author = true,
                     journal = true, journaltitle = true, address = true, location = true, publisher = true,
                     series = true, eprint = true, url = true }

-- Fields of one entry body, in order: {braced} or "quoted" (also kept raw as name_braced), or bare.
-- ponytail: no @string expansion or # concatenation; bare macro names are kept verbatim.
local function bib_fields(body, e)
  local pos = 1
  while true do
    local _, stop, name = body:find('^[ \t\r\n,]*([A-Za-z0-9_%-:.]+)[ \t\r\n]*=[ \t\r\n]*', pos)
    if not stop then return end
    pos = stop + 1
    local c, val, raw = body:sub(pos, pos)
    if c == '{' then
      local a, b = body:find('%b{}', pos)
      if not a then return end
      raw = body:sub(a + 1, b - 1); val = raw:gsub('[{}]', ''); pos = b + 1
    elseif c == '"' then  -- same as {braced}: inner braces still protect text
      local a, b = body:find('^"[^"]*"', pos)
      if not a then return end
      raw = body:sub(a + 1, b - 1); val = raw:gsub('[{}]', ''); pos = b + 1
    else
      local a, b = body:find('^[^,} \t\r\n]+', pos)
      if not a then return end
      val = body:sub(a, b); pos = b + 1
    end
    name = ascii_lower(name)
    if RAW_FIELDS[name] then e[name] = val; e[name .. '_braced'] = raw end
  end
end

local function bib_scan(meta)
  local entries, bibs = {}, meta.bibliography
  if bibs == nil then return entries end
  if pandoc.utils.type(bibs) ~= 'List' then bibs = { bibs } end
  for _, b in ipairs(bibs) do
    local path = pandoc.utils.stringify(b)
    if path:match('%.[Bb][Ii][Bb]$') then
      local f = io.open(path)
      if not f then
        warning('gbt7714: cannot read ' .. path .. '; entry types and sort keys fall back to pandoc defaults')
      else
        local text = '\n' .. f:read('a'):gsub('^\239\187\191', '')  -- drop UTF-8 BOM
        f:close()
        for chunk in text:gsub('\n[ \t]*@', '\0@'):gmatch('%z@([^%z]*)') do
          local t, k, body = chunk:match('^([A-Za-z]+)[ \t\r\n]*{[ \t\r\n]*([^, \t\r\n]+)[ \t\r\n]*,(.*)$')
          if t then
            local e = { type = ascii_lower(t) }
            bib_fields(body, e)
            entries[k] = e
          end
        end
      end
    end
  end
  return entries
end

-- Citation suffix as bst prints a \citep[post] note: page labels dropped (GB/T pages carry
-- no "p."), anything else kept as written ("第2章", "chap. 3"). Returns text and whether it is a page.
local function postnote(suffix)
  local s = str(suffix):gsub('\194\160', ' ')  -- pandoc puts nbsp after "pp."
  -- ASCII whitespace only: Lua's %s can match UTF-8 continuation bytes (0x85, 0xA0; 章 = E7 AB A0)
  s = s:gsub('^[ \t\r\n]*,?[ \t\r\n]*', ''):gsub('[ \t\r\n]*$', '')
  if s == '' then return nil end
  local p = s:gsub('^[Pp]+%.[ \t]*', ''):gsub('^pages?[ \t]+', '')
  p = p:gsub('^页[ \t]*', ''):gsub('^第[ \t]*(.-)[ \t]*页$', '%1'):gsub('[ \t]*页$', '')  -- 页 50 / 第50页 / 50页
  p = p:gsub('–', '-')
  if p:match('^%d[%d%-, ]*$') then return p, true end
  return s, false
end

-- In-text author as bst format.lab.name: "{vv~}{ll}", CJK given names appended ("张三");
-- "等"/"et al." after the first of 2+ names; no author -> 佚名/Anon (the CSL's anonymous term).
local function intext_author(r)
  if not r then return nil end
  local names = r.author or r.editor
  if not names or #names == 0 then return r.language and '佚名' or 'Anon' end
  local n = names[1]
  local name = n.literal or n.family
  if not name then return nil end
  local von = n['dropping-particle'] or n['non-dropping-particle']
  if von then name = von .. ' ' .. name end
  if n.given and has_cjk(name) and has_cjk(n.given) then name = name .. n.given end
  if #names > 1 then name = name .. (r.language and ' 等' or ' et al.') end
  return name
end

-- Chinese text takes no space around a citation ("再生产 [@a] 认为" -> "再生产[@a]认为").
-- xeCJK drops such spaces in PDF; HTML and Word would keep them, so drop them here.
-- CJK text plus the punctuation Chinese shares with English (——“”‘’…); not for language detection.
local function cjk_side(cp)
  return is_cjk_cp(cp) or (cp ~= nil and ((cp >= 0x2014 and cp <= 0x201F) or cp == 0x2026))
end
-- First/last code point of an inline; looks into Link/Span/Emph/... (link-citations wraps names in links).
local function edge_cp(el, last)
  if not el or el.t == 'Space' or el.t == 'SoftBreak' or el.t == 'LineBreak' then return nil end
  local text = el.t == 'Str' and el.text or (el.content and pandoc.utils.stringify(el)) or ''
  local cp
  for _, c in utf8.codes(text) do
    cp = c
    if not last then break end
  end
  return cp
end
-- A narrative cite opens with the author's name; keep the space before a Latin name
-- ("英文叙述 Smith et al.（2020）"), as xeCJK puts CJK-Latin glue there in PDF.
-- Order: needs refs after Pandoc()'s loop (r.language is then 'zh' or nil), and must run
-- before gbt_cites, which rewrites AuthorInText cites into plain text + SuppressAuthor.
local function trim_cite_spaces(doc, refs, style)
  local latin = {}
  for _, r in ipairs(refs) do latin[r.id] = not r.language end
  local function opens_latin(c)
    local ct = c.citations[1]
    return ct and ct.mode == 'AuthorInText' and latin[ct.id]
  end
  return doc:walk({
    Inlines = function(ils)
      local out = pandoc.Inlines({})
      for i, el in ipairs(ils) do
        local drop = false
        if el.t == 'Space' or el.t == 'SoftBreak' then
          local prev, nxt = ils[i - 1], ils[i + 1]
          local ct = nxt and nxt.t == 'Cite' and nxt.citations[1]
          -- Explicit prose author plus year: `Lareau [-@x]` -> `Lareau（2011）`.
          local year_only = style == 'authoryear' and ct and ct.mode == 'SuppressAuthor'
            and #ct.prefix == 0 and edge_cp(prev, true) ~= nil
          drop = year_only or (nxt and nxt.t == 'Cite' and not opens_latin(nxt) and cjk_side(edge_cp(prev, true)))
              or (prev and prev.t == 'Cite' and cjk_side(edge_cp(nxt, false)))
        end
        if not drop then out:insert(el) end
      end
      return out
    end,
  })
end

-- GB/T 7714 citation forms the CSL cannot express (bst \citet and \citep[post] placement):
--   @key            -> Author + citation with author suppressed: "Boobier（2020）", "Boobier[1]"
--   [@key, 42]      -> postnote as a superscript after the closing bracket: "（Boobier，2020）⁴²", "[1]⁴²"
--   [@a, 5; @b, 7]  -> one citation each, as bst would print \citep[5]{a}\citep[7]{b}
--   [见 @key]       -> numeric: prefix outside the superscript, "见[1]"
-- Note style: @key -> Author + normal citation, so the note keeps the full entry (citeproc
-- would move the author list into the prose, and drop the name on "同N" repeats).
-- Note style keeps citeproc's locator handling but normalizes the suffix: under lang: zh
-- citeproc only knows "页", so a page becomes a bare number (read as a page locator);
-- anything else ("第2章") follows a full-width comma.
local function note_suffix(ct)
  local post, page = postnote(ct.suffix)
  if post then
    ct.suffix = page and pandoc.Inlines({ pandoc.Str(','), pandoc.Space(), pandoc.Str(post) })
      or pandoc.Inlines({ pandoc.Str(','), pandoc.Space(), pandoc.Str('{' .. post .. '}') })  -- braced: citeproc keeps it as a literal locator
  end
end

local function gbt_cites(doc, refs, style)
  local note, numeric = style == 'note', style == 'numeric'
  local byid = {}
  for _, r in ipairs(refs) do byid[r.id] = r end
  local function one(ct)
    local out = pandoc.Inlines({})
    if ct.mode == 'AuthorInText' then
      local a = intext_author(byid[ct.id])
      if a then out:insert(pandoc.Str(a)); ct.mode = note and 'NormalCitation' or 'SuppressAuthor' end
    end
    local post, page = postnote(ct.suffix)
    if note then
      note_suffix(ct)
      out:insert(pandoc.Cite({}, { ct })); return out
    end
    if numeric and #ct.prefix > 0 then
      out:extend(ct.prefix); ct.prefix = pandoc.Inlines({})
    end
    if post then ct.suffix = pandoc.Inlines({}) end
    out:insert(pandoc.Cite({}, { ct }))
    if post then out:insert(pandoc.Superscript({ pandoc.Str(post) })) end
    return out
  end
  return doc:walk({
    Cite = function(c)
      -- A narrative citation can contain several references: @a [see also @b].
      -- Pull its author into the prose before keeping/splitting the cluster, so
      -- numeric retains the author and note keeps it in the full first note too.
      local narrative = pandoc.Inlines({})
      if #c.citations > 1 then
        for _, ct in ipairs(c.citations) do
          if ct.mode == 'AuthorInText' then
            local a = intext_author(byid[ct.id])
            if a then
              narrative:insert(pandoc.Str(a))
              ct.mode = note and 'NormalCitation' or 'SuppressAuthor'
            end
          end
        end
      end
      local function finish(content)
        if #narrative == 0 then return content end
        local out = pandoc.Inlines(narrative)
        if content.t == 'Cite' then out:insert(content) else out:extend(content) end
        return out
      end
      local split = #c.citations == 1
      for _, ct in ipairs(c.citations) do split = split or postnote(ct.suffix) ~= nil end
      if not split then
        local pre = c.citations[1].prefix
        if not (numeric and #pre > 0) then return #narrative > 0 and finish(c) or nil end
        c.citations[1].prefix = pandoc.Inlines({})  -- [见 @a; @b] -> 见[1,2]
        local out = pandoc.Inlines(pre); out:insert(pandoc.Cite({}, c.citations)); return finish(out)
      end
      if note and #c.citations > 1 then  -- keep one note; only normalize each postnote
        for _, ct in ipairs(c.citations) do note_suffix(ct) end
        return finish(c)
      end
      local out = pandoc.Inlines({})
      for _, ct in ipairs(c.citations) do out:extend(one(ct)) end
      return finish(out)
    end,
  })
end

-- bst/natbib compress: runs of 2+ consecutive numbers become "a-b" with a hyphen, written
-- order kept ("[7-8]", "[1-2,6]", "[6,1,4]"); citeproc gives "[7,8]", "[1–3]".
-- Works on the bracket's inlines, so link-citations (each number a Link) survive.
local function compress(ils)
  local s = pandoc.utils.stringify(ils)
  if not s:match('^%[[%d,%-\226\128\147]+%]$') then return nil end
  local toks = {}  -- { n = number, il = inline or nil }
  local dash = false
  for _, il in ipairs(ils) do
    local t = pandoc.utils.stringify(il)
    if il.t == 'Link' then
      local n = tonumber(t)
      if dash and #toks > 0 then
        for i = toks[#toks].n + 1, n - 1 do toks[#toks + 1] = { n = i } end
      end
      toks[#toks + 1] = { n = n, il = il }; dash = false
    else
      t = t:gsub('\226\128\147', '-')
      for num, d in t:gmatch('(%d*)(%-?)') do
        if num ~= '' then
          local n = tonumber(num)
          if dash and #toks > 0 then
            for i = toks[#toks].n + 1, n - 1 do toks[#toks + 1] = { n = i } end
          end
          toks[#toks + 1] = { n = n }; dash = false
        end
        if d == '-' then dash = true end
      end
    end
  end
  local function show(tk) return tk.il or pandoc.Str(tostring(tk.n)) end
  local out, i = pandoc.Inlines({ pandoc.Str('[') }), 1
  while i <= #toks do
    local j = i
    while toks[j + 1] and toks[j + 1].n == toks[j].n + 1 do j = j + 1 end
    if i > 1 then out:insert(pandoc.Str(',')) end
    out:insert(show(toks[i]))
    if j > i then out:insert(pandoc.Str('-')); out:insert(show(toks[j])) end
    i = j + 1
  end
  out:insert(pandoc.Str(']'))
  return out
end

-- numeric only: run citeproc here so the numbers can be compressed afterwards (every Quarto
-- filter hook runs before its citeproc). Afterwards the citations are plain inlines (Span.citation
-- for HTML, as pandoc marks them) and Quarto's own citeproc pass builds the bibliography as usual
-- (heading, appendix, hover): references are reordered to our numbering with nocite "@*", which
-- makes that pass number them identically. Other styles need no post-citeproc step.
-- ponytail: with `citation-location: margin` Quarto needs real Cites, so compression is skipped.
local CROSSREF = '^%l+%-'  -- @fig-x, @tbl-x, @sec-x...: left for Quarto's crossref
-- citeproc puts a space after a citation prefix ("见 博伯尔"); Chinese takes none.
-- The prefix end is marked before citeproc, so only that space goes ("张三 等" keeps its own).
local PREFIX_END = '\u{E000}'  -- private use, never in real text
local function mark_prefixes(doc)
  return doc:walk({ Cite = function(c)
    for _, ct in ipairs(c.citations) do
      if #ct.prefix > 0 then ct.prefix:insert(pandoc.Str(PREFIX_END)) end
    end
    return c
  end })
end
local function drop_prefix_spaces(ils)
  local out, i = pandoc.Inlines({}), 1
  while i <= #ils do
    local el = ils[i]
    if el.t == 'Str' and el.text:find(PREFIX_END, 1, true) then
      local text = el.text:gsub(PREFIX_END, '')
      if text ~= '' then out:insert(pandoc.Str(text)) end
      local nxt = ils[i + 1]
      if nxt and nxt.t == 'Space' and cjk_side(edge_cp(out[#out], true)) and cjk_side(edge_cp(ils[i + 2], false)) then
        i = i + 1  -- skip the space citeproc added
      end
    else
      out:insert(el)
    end
    i = i + 1
  end
  return out
end

-- Render citations ourselves (Quarto has no hook after its own citeproc), so we can post-process
-- them: numeric compression, prefix spaces. The bibliography is left to Quarto's citeproc via
-- `nocite: "@*"` over the references actually listed, in our numbering order.
-- Margin citations need Quarto's own pass, so they are left alone.
local function run_citeproc(doc, refs, style)
  if pandoc.utils.stringify(doc.meta['citation-location'] or '') == 'margin' then
    return doc
  end
  local known, held = { ['*'] = true }, {}  -- nocite: "@*"
  for _, r in ipairs(refs) do known[r.id] = true end
  local had_refs, refs_div = false, nil
  doc:walk({ Div = function(d) if d.identifier == 'refs' then had_refs, refs_div = true, d end end })
  doc = doc:walk({
    Cite = function(c)
      for _, ct in ipairs(c.citations) do
        if not known[ct.id] and ct.id:match(CROSSREF) then  -- as without the filter: whole Cite to crossref
          held[#held + 1] = c
          return pandoc.Span({}, { ['gbt-held'] = tostring(#held) })
        end
      end
    end,
  })
  -- Only the final citeproc pass should insert an automatic bibliography heading.
  -- Keeping the first pass's heading leaves an empty duplicate chapter in PDF books.
  local reference_title = doc.meta['reference-section-title']
  doc.meta['reference-section-title'] = nil
  doc = pandoc.utils.citeproc(mark_prefixes(doc))
  doc.meta['reference-section-title'] = reference_title
  local order = {}
  local html = FORMAT:match('html') ~= nil
  doc = doc:walk({
    Cite = function(c)
      local ids = {}
      for _, ct in ipairs(c.citations) do ids[#ids + 1] = ct.id end
      local content = c.content:walk({
        Superscript = function(sup)
          local c2 = style == 'numeric' and compress(sup.content)
          if c2 then return pandoc.Superscript(c2) end
        end,
        Inlines = drop_prefix_spaces,
      })
      if not html then return content end
      return pandoc.Span(content, { class = 'citation', ['data-cites'] = table.concat(ids, ' ') })
    end,
    Span = function(sp)
      local i = sp.attributes['gbt-held']
      if i then return held[tonumber(i)] end
    end,
    Div = function(d)
      if d.identifier ~= 'refs' then return nil end
      for _, e in ipairs(d.content) do
        local id = e.identifier and e.identifier:match('^ref%-(.+)$')
        if id then order[#order + 1] = id end
      end
      if had_refs then return refs_div end  -- restore; Quarto's pass fills it
      return {}
    end,
  })
  local byid = {}
  for _, r in ipairs(refs) do byid[r.id] = r end
  local ordered = {}
  for _, id in ipairs(order) do ordered[#ordered + 1] = byid[id] end
  doc.meta.references = ordered
  doc.meta.nocite = pandoc.MetaInlines({ pandoc.Cite({ pandoc.Str('@*') }, { pandoc.Citation('*', 'NormalCitation') }) })
  return doc
end

-- bst `sortify` = purify$ + lowercase: hyphens/ties/whitespace become spaces,
-- other ASCII punctuation goes, bytes >= 128 (CJK etc.) stay.
local function sortify(s)
  return ascii_lower(s:gsub('[-~ \t\r\n\f\v]', ' '):gsub('[^0-9A-Za-z \128-\255]', ''))
end

local LANGID = {
  english = 'en', american = 'en', british = 'en', chinese = 'zh',
  japanese = 'ja', korean = 'ko', russian = 'ru',
}
-- Beyond bst (which maps zh-CN etc. to "other"): BCP 47 codes as Zotero and CSL-JSON write them.
local function lang_of(id)
  id = ascii_lower(id)
  return LANGID[id] or ({ zh = 'zh', ja = 'ja', ko = 'ko', en = 'en', ru = 'ru' })[id:match('^([a-z][a-z])[-_]') or id] or 'other'
end

-- bst set.entry.lang: langid/language field, else detect from the first non-empty field.
-- pandoc's `language` covers CSL-JSON/YAML entries, which have no raw bib fields.
local function entry_lang(raw, r)
  local id = raw.langid or raw.language or (r.language and str(r.language))
  if id and id ~= '' then return lang_of(id) end
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
  -- bst sorts on the year field; biblatex `date`, CSL-JSON/YAML and crossref give only r.issued
  local dp = r.issued and r.issued['date-parts'] and r.issued['date-parts'][1]
  local year = raw.year or (dp and dp[1] and tostring(dp[1])) or ''
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
  -- Only citeproc runs our CSL. natbib/biblatex (cite-method) and Typst's native citations
  -- (Quarto's typst default; quarto.doc.cite_method() is nil there) are left alone.
  local method = PANDOC_WRITER_OPTIONS.cite_method
  if quarto and quarto.doc and quarto.doc.cite_method then method = quarto.doc.cite_method() end
  if method ~= 'citeproc' then
    if FORMAT == 'typst' then
      warning('gbt7714: Typst renders citations natively; set `citeproc: true` under `format: typst` to use GB/T 7714')
    end
    return nil
  end
  local style = ascii_lower(pandoc.utils.stringify(doc.meta.gbt7714 or 'authoryear'))
  if not STYLES[style] then
    fatal('unknown style "' .. style .. '" (use authoryear, numeric or note)')
  end
  -- Chinese convention: the note mark goes before the punctuation ("研究¹。"); pandoc defaults to after
  if style == 'note' and doc.meta['notes-after-punctuation'] == nil then
    doc.meta['notes-after-punctuation'] = false
  end
  -- A user's own CSL gets the data fixes only; the GB/T citation rewrites assume our CSL.
  local own_csl = doc.meta.csl ~= nil
    and not pandoc.utils.stringify(doc.meta.csl):match('gbt7714%-%a+%.csl$')
  if own_csl then
    warning('gbt7714: custom CSL "' .. str(doc.meta.csl) .. '" overrides the bundled style; GB/T citation rewrites are disabled, bibliography data fixes still apply')
  end
  if doc.meta.csl == nil then
    doc.meta.csl = pandoc.path.join({ dir, 'gbt7714-' .. style .. '.csl' })
  end

  local ok, refs = pcall(pandoc.utils.references, doc)
  if not ok then fatal(tostring(refs)) end
  if #refs == 0 then return doc end
  local raw = bib_scan(doc.meta)
  for _, r in ipairs(refs) do
    local e = raw[r.id] or {}
    local elang = entry_lang(e, r)  -- bst set.entry.lang
    local cjk = elang == 'zh' or elang == 'ja' or elang == 'ko'  -- bst is.lang.cjk
    -- Rebuild from the raw bib value when pandoc's reading is lossy:
    --  * \quad, which GB/T titles use between title elements (信息与文献\quad 资源描述), is dropped;
    --  * without an English langid pandoc "unTitlecases" title/booktitle/series by the document
    --    lang, so a Chinese title loses its English capitals (Python -> python). bst keeps them.
    -- ponytail: via the LaTeX reader, so {braced} protection in English \quad titles is lost
    for field, var in pairs({ title = 'title', booktitle = 'container-title', series = 'collection-title' }) do
      local raw_v = e[field .. '_braced']
      local journal = field == 'booktitle' and PERIODICAL_TYPES[r.type]  -- container is the journal
      -- a periodical's title is a journal name: bst keeps its case, pandoc sentence-cases it
      local keep = cjk or raw_v and raw_v:find('\\quad') or (field == 'title' and e.type == 'periodical')
      if raw_v and r[var] and not journal and keep then
        raw_v = raw_v:gsub('\\quad[ \t\r\n]*', '\u{2003}')
        r[var] = pandoc.utils.blocks_to_inlines(pandoc.read(raw_v, 'latex').blocks)
      end
    end
    -- before the holder override below: bst sorts patents by inventors, labels them by holder
    r['gbt-sort'] = bst_sort_key(e, r, elang)
    r.type = BIBTYPE[e.type] or r.type
    -- fields pandoc drops; bst uses holder (patent assignee) in place of the inventors
    if e.holder then
      r.author = {}
      for h in (e.holder .. ' and '):gmatch('(.-)[ \t\r\n]+and[ \t\r\n]+') do table.insert(r.author, { literal = h }) end
    end
    r.scale = r.scale or e.scale
    r.dimensions = r.dimensions or (e.dimensions and e.dimensions:gsub('\\,', '\u{2009}'))
    if e.cstr then  -- bst format.doi: CSTR replaces DOI, and is omitted when the URL contains it
      r.doi = nil
      if not (r.url and str(r.url):find(e.cstr, 1, true)) then r.CSTR = e.cstr end
    end
    if not r.page and e.eid then r.page = e.eid end
    if r.type == 'periodical' then
      -- bst `periodical`: no container; volume/year ranges with full-width punctuation and "—"
      r['container-title'] = nil
      if r.volume then
        r.volume = fullwidth_str(str(r.volume)):gsub('%-', '—')
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
    -- bst article: a journal starting with "arXiv" (check.arxiv.preprint), or no journal but an
    -- eprint, makes the entry a preprint [PP]; the arXiv id after "arXiv:" becomes the URL.
    if e.type == 'article' then
      local j = e.journal or e.journaltitle
      if j and ascii_lower(j):sub(1, 5) == 'arxiv' then
        r.type, r['container-title'] = 'article', nil
        local _, at = ascii_lower(j):find('.*arxiv:')  -- last "arXiv:", as bst scans back from the end
        local id = at and j:sub(at + 1):match('^[^ %[]+')
        if id then r.url = 'https://arxiv.org/abs/' .. id end
      elseif not j and (e.eprint or e.archiveprefix or e.eprinttype) then
        r.type = 'article'
      end
    end
    if r.type == 'article' then
      -- bst format.eprint: source name; it never builds a URL from eprint (entry.eprint is unset),
      -- so drop the one pandoc derives from it
      local src = e.archiveprefix or e.eprinttype
      src = ({ arxiv = 'arXiv', pubmed = 'PubMed' })[src] or src
      if not src and ascii_lower(e.journal or e.journaltitle or ''):sub(1, 5) == 'arxiv' then src = 'arXiv' end
      r.publisher = r.publisher or src
      if e.eprint and not e.url and r.url and str(r.url):find(e.eprint, 1, true) then
        r.url = nil
      end
    end
    local en = elang == 'en'
    if r.type == 'map' and e.booktitle and not r['container-title'] then  -- map in an atlas
      r['container-title'] = fullwidth_str(en and sentence_case_raw(e.booktitle_braced) or e.booktitle)
    end
    r.edition = edition(r.edition, elang)
    if r.volume and not PERIODICAL_TYPES[r.type] then  -- bst format.bvolume (books, maps, ...)
      local v = str(r.volume)
      if v:match('^%d+$') then
        r.volume = elang == 'ko' and ('제 ' .. v .. ' 권')
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
    if r.doi and r.url and str(r.url):find(str(r.doi), 1, true) then
      r.doi = nil
    end
    for _, f in ipairs(FW_FIELDS) do r[f] = fullwidth(r[f]) end
    for _, v in ipairs(NAME_VARS) do
      if r[v] then for i, n in ipairs(r[v]) do r[v][i] = format_name(n) end end
    end
  end
  doc.meta.references = refs
  doc.meta.bibliography = nil
  doc = trim_cite_spaces(doc, refs, not own_csl and style or nil)
  if own_csl then return doc end
  if style == 'note' then  -- `Lareau [-@x]`: the author is in the prose, but the note needs the full entry
    doc = doc:walk({ Cite = function(c)
      for _, ct in ipairs(c.citations) do
        if ct.mode == 'SuppressAuthor' then ct.mode = 'NormalCitation' end
      end
      return c
    end })
  end
  doc = gbt_cites(doc, refs, style)
  doc = run_citeproc(doc, refs, style)
  return doc
end
