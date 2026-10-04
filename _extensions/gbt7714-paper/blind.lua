-- Run at pre-ast so Quarto cannot build title blocks from identifying metadata.
-- This is explicit anonymization: prose, references and image contents are not
-- inspected. Mark acknowledgments or other private blocks .nonblind/.author-only.
local identity_keys = {
  'author', 'authors', 'author-meta', 'author-short', 'author-note',
  'author-notes', 'affiliation', 'affiliations', 'institute', 'institutes',
  'by-author', 'by-affiliation', 'email', 'orcid', 'address',
  'corresponding-author', 'correspondence', 'thanks', 'acknowledgments',
  'acknowledgements', 'funding', 'student-id', 'course', 'instructor',
  'pdfauthor', 'citation-author', 'citation_author',
}

local function private_block(el)
  if el.classes:includes('nonblind') or el.classes:includes('author-only') then
    return {}
  end
end

function Pandoc(doc)
  if doc.meta.blind ~= true then
    return doc
  end
  for _, key in ipairs(identity_keys) do
    doc.meta[key] = nil
  end
  return doc:walk({ Div = private_block, Span = private_block })
end
