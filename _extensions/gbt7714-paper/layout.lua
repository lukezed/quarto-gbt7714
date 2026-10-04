-- Set publication layout before Quarto derives format and title metadata.
local function text(value)
  return value and pandoc.utils.stringify(value) or ''
end

local function append_header(meta, source)
  local headers = meta['header-includes']
  if not headers then headers = pandoc.MetaList({})
  elseif headers.t ~= 'MetaList' then headers = pandoc.MetaList({headers}) end
  headers:insert(pandoc.MetaBlocks({pandoc.RawBlock('latex', source)}))
  meta['header-includes'] = headers
end

local function author_affiliations(meta)
  local found, lines = {}, {}
  local function add(value)
    local label = type(value) == 'table' and value.name and text(value.name) or text(value)
    if type(value) == 'table' and value.department then label = label .. ' · ' .. text(value.department) end
    if label ~= '' and not found[label] then lines[#lines + 1] = label; found[label] = true end
  end
  -- Quarto preserves structured records in `authors` after flattening `author`.
  local authors = meta.authors or meta.author
  if authors and pandoc.utils.type(authors) == 'List' then
    for _, author in ipairs(authors) do
      if type(author) == 'table' then
        local affiliations = author.affiliations or author.affiliation
        if affiliations then
          if pandoc.utils.type(affiliations) == 'List' then
            for _, affiliation in ipairs(affiliations) do add(affiliation) end
          else add(affiliations) end
        end
      end
    end
  end
  local affiliations = meta.affiliations or meta.affiliation
  if affiliations then
    if pandoc.utils.type(affiliations) == 'List' then
      for _, affiliation in ipairs(affiliations) do add(affiliation) end
    else add(affiliations) end
  end
  return lines
end


local function blocks(value)
  if not value then return pandoc.List({}) end
  local kind = pandoc.utils.type(value)
  if kind == 'Blocks' then return value end
  return pandoc.List({pandoc.Para(kind == 'Inlines' and value or {pandoc.Str(text(value))})})
end

local function styled(content, name, class)
  return pandoc.Div(content, pandoc.Attr('', {class or 'paper-front-heading'}, {['custom-style'] = name}))
end

local function manuscript(doc)
  local meta = doc.meta
  local pdf, word = quarto.doc.is_format('pdf'), quarto.doc.is_format('docx')
  local title = blocks(meta.title)
  local abstract = blocks(meta.abstract)
  local prefix = pandoc.List({})
  local function pagebreak()
    if pdf then return pandoc.RawBlock('latex', '\\clearpage') end
    if word then return pandoc.RawBlock('openxml', '<w:p><w:r><w:br w:type="page"/></w:r></w:p>') end
    return pandoc.RawBlock('html', '<div class="paper-pagebreak"></div>')
  end
  if pdf then
    append_header(meta, [[
\usepackage{fancyhdr,caption}
\geometry{a4paper,top=25.4mm,bottom=25.4mm,left=31.7mm,right=31.7mm}
\IfFontExistsTF{Times New Roman}{\setmainfont{Times New Roman}}{\setmainfont{TeX Gyre Termes}}
\AtBeginDocument{\ctexset{
 section={format=\centering\heiti\bfseries\fontsize{16bp}{16bp}\selectfont,beforeskip=25bp,afterskip=18bp,afterindent=true},
 subsection={format=\raggedright\heiti\fontsize{15bp}{15bp}\selectfont,beforeskip=25bp,afterskip=6bp,afterindent=true},
 subsubsection={format=\raggedright\heiti\fontsize{14bp}{14bp}\selectfont,beforeskip=12bp,afterskip=6bp,afterindent=true}
}}
\DeclareCaptionFont{manuscript}{\fontsize{10.5bp}{12.6bp}\selectfont}
\captionsetup{font=manuscript,labelfont=normalfont,justification=centering,singlelinecheck=false,skip=6bp}
\AtBeginEnvironment{CSLReferences}{\fontsize{10.5bp}{20bp}\selectfont\setlength{\parskip}{0pt}\setlength{\cslhangindent}{2em}}
% Set the normal-text baseline explicitly; do not multiply the class baseline.
\makeatletter
\g@addto@macro\normalsize{\fontsize{12bp}{25bp}\selectfont}
\makeatother
\AtBeginDocument{\normalsize\setlength{\parskip}{0pt}}
\pagestyle{fancy}\fancyhf{}\fancyhead[R]{\thepage}
\renewcommand{\headrulewidth}{0pt}
\fancypagestyle{plain}{\fancyhf{}\fancyhead[R]{\thepage}\renewcommand{\headrulewidth}{0pt}}
\makeatletter
\renewcommand{\maketitle}{%
  \thispagestyle{plain}\null\vspace{2cm}
  \begin{center}
  {\heiti\fontsize{16bp}{16bp}\selectfont\bfseries \@title\par}\vspace{1.5\baselineskip}
  {\normalsize \@author\par}\vspace{\baselineskip}
  {\normalsize \@date\par}
  \end{center}\clearpage}
\makeatother
]])
  elseif word then
    prefix:insert(styled(title, 'ManuscriptTitle'))
    if meta.subtitle then prefix:insert(styled(blocks(meta.subtitle), 'ManuscriptAuthor')) end
    local authors = meta.author or {}
    if pandoc.utils.type(authors) ~= 'List' then authors = {authors} end
    for _, author in ipairs(authors) do
      prefix:insert(styled(blocks(type(author) == 'table' and author.name or author), 'ManuscriptAuthor'))
    end
    if meta.date then prefix:insert(styled(blocks(meta.date), 'ManuscriptAuthor')) end
    -- The writer otherwise emits a second title block before these pages.
    meta.title, meta.subtitle, meta.author, meta.date = nil, nil, nil, nil
    prefix:insert(pagebreak())
  end
  local abstract_page = pandoc.List({})
  if #abstract > 0 then
    if pdf then
      abstract_page:insert(pandoc.RawBlock('latex', '\\section*{摘要}'))
    else
      abstract_page:insert(styled({pandoc.Para({pandoc.Strong({pandoc.Str('摘要')})})}, 'ManuscriptHeading'))
    end
    abstract_page:extend(abstract)
  end
  if meta.keywords then
    local values = meta.keywords
    if pandoc.utils.type(values) ~= 'List' then values = {values} end
    local words = {}
    for _, value in ipairs(values) do words[#words + 1] = text(value) end
    abstract_page:insert(pandoc.Para({pandoc.Strong({pandoc.Str('关键词：')}), pandoc.Space(), pandoc.Str(table.concat(words, '；'))}))
  end
  if #abstract_page > 0 then
    prefix:insert(styled(abstract_page, 'ManuscriptAbstract', 'paper-abstract-page'))
    prefix:insert(pagebreak())
  end
  meta.abstract, meta.keywords = nil, nil
  if pdf then
    local latex = pandoc.write(pandoc.Pandoc(title), 'latex')
    prefix:insert(pandoc.RawBlock('latex', '\\begin{center}\\bfseries\n' .. latex .. '\\end{center}'))
  else
    prefix:insert(styled(title, 'ManuscriptHeading'))
  end
  doc.blocks = pandoc.Pandoc(doc.blocks):walk({Header = function(header)
    if header.identifier == '参考文献' or header.identifier == 'references' then
      return {pagebreak(), header}
    end
  end}).blocks
  -- The manuscript reference supplies body styles without overriding captions.
  prefix:extend(doc.blocks)
  doc.blocks = prefix
end

function Pandoc(doc)
  local meta = doc.meta
  local style = text(meta['paper-style'])
  if style == '' then style = 'student' end
  if style ~= 'student' and style ~= 'manuscript' and style ~= 'journal' then
    io.stderr:write('ERROR: paper-style must be student, manuscript, or journal\n')
    os.exit(1)
  end
  meta['paper-style'] = pandoc.MetaString(style)

  if quarto.doc.is_format('html') then
    doc.blocks = pandoc.List({pandoc.Div(doc.blocks,
      pandoc.Attr('', {'paper-body', 'paper-' .. style}))})
  elseif quarto.doc.is_format('pdf') then
    meta.fontsize = pandoc.MetaString(style == 'journal' and '10pt' or '12pt')
    meta.linestretch = pandoc.MetaString(style == 'student' and '1.5' or
      (style == 'manuscript' and '1' or '1.05'))
    local affiliations = author_affiliations(meta)
    if #affiliations > 0 and text(meta.blind) ~= 'true' then
      local latex = pandoc.write(pandoc.Pandoc({pandoc.Plain({pandoc.Str(table.concat(affiliations, '；'))})}), 'latex')
      append_header(meta, '\\makeatletter\n\\AtBeginDocument{\\g@addto@macro\\@author{\\\\[.4em]{\\small ' ..
        latex .. '}}}\n\\makeatother')
    end
    if style == 'journal' then
      local options = meta.classoption or pandoc.MetaList({})
      if options.t ~= 'MetaList' then options = pandoc.MetaList({options}) end
      options:insert(pandoc.MetaString('twocolumn'))
      meta.classoption = options
      append_header(meta, '\\geometry{a4paper,margin=18mm}\\setlength{\\columnsep}{7mm}')
      if meta.abstract then
        local abstract = meta.abstract
        local blocks = pandoc.utils.type(abstract) == 'Blocks' and abstract or
          {pandoc.Para(pandoc.utils.type(abstract) == 'Inlines' and abstract or {pandoc.Str(text(abstract))})}
        local latex = pandoc.write(pandoc.Pandoc(blocks), 'latex')
        append_header(meta, '\\makeatletter\n\\let\\paperoriginalmaketitle\\maketitle\n' ..
          '\\renewcommand{\\maketitle}{\\twocolumn[{\\@twocolumnfalse\\paperoriginalmaketitle\n' ..
          '\\begin{abstract}\n' .. latex .. '\n\\end{abstract}\\vspace{1em}}]}\n\\makeatother')
        -- The stock template would otherwise print the abstract a second time.
        meta.abstract = nil
      end
    end
  elseif quarto.doc.is_format('docx') and text(meta.blind) ~= 'true' then
    local affiliations = author_affiliations(meta)
    if #affiliations > 0 then
      local authors = meta.author or pandoc.MetaList({})
      if pandoc.utils.type(authors) ~= 'List' then authors = pandoc.MetaList({authors}) end
      authors:insert(pandoc.MetaInlines({pandoc.Str(table.concat(affiliations, '；'))}))
      meta.author = authors
    end
  end

  if style == 'manuscript' then manuscript(doc) end

  local prefix = pandoc.List({})
  if style == 'student' and text(meta.blind) ~= 'true' then
    local fields = {{'student-id', '学号'}, {'course', '课程'}, {'instructor', '指导教师'}}
    local blocks = pandoc.List({})
    for _, field in ipairs(fields) do
      local value = meta[field[1]]
      if value and text(value) ~= '' then
        local inlines = pandoc.List({pandoc.Strong({pandoc.Str(field[2] .. '：')}), pandoc.Space()})
        if pandoc.utils.type(value) == 'Inlines' then inlines:extend(value)
        else inlines:insert(pandoc.Str(text(value))) end
        blocks:insert(pandoc.Para(inlines))
      end
    end
    if #blocks > 0 then prefix:insert(pandoc.Div(blocks, pandoc.Attr('', {'paper-student-details'}))) end
  end

  -- PDF and Word templates do not consistently display keyword metadata.
  if not quarto.doc.is_format('html') and meta.keywords then
    local values = meta.keywords
    if pandoc.utils.type(values) ~= 'List' then values = {values} end
    local words = {}
    for _, value in ipairs(values) do words[#words + 1] = text(value) end
    prefix:insert(pandoc.Para({pandoc.Strong({pandoc.Str('关键词：')}),
      pandoc.Space(), pandoc.Str(table.concat(words, '；'))}))
  end
  prefix:extend(doc.blocks)
  doc.blocks = prefix
  return doc
end
