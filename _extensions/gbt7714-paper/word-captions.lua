-- Preserve Word caption styles after Quarto generates its layout.
function Pandoc(doc)
  if quarto.doc.is_format('docx') and
      pandoc.utils.stringify(doc.meta['paper-style'] or '') == 'manuscript' then
    -- Quarto inserts paragraph properties as a raw inline in figure/table
    -- captions. Let the writer emit a single pPr using the reference style.
    return doc:walk({Para = function(para)
      local caption = false
      para.content = para.content:filter(function(inline)
        if inline.t == 'RawInline' and inline.format == 'openxml' and
            inline.text:match('<w:pPr>') and inline.text:match('ImageCaption') then
          caption = true
          return false
        end
        return true
      end)
      if caption then
        return pandoc.Div({para}, pandoc.Attr('', {}, {['custom-style'] = 'ImageCaption'}))
      end
    end})
  end
  return doc
end
