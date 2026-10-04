"""Check the rendered manuscript's Word styles and caption paragraph properties.

Usage: python3 test/test_manuscript_typography.py path/to/paper.docx
Render templates/manuscript with tools/new_project.py before running this check.
"""
import sys
from zipfile import ZipFile
import xml.etree.ElementTree as ET

W = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'
NS = {'w': W}
with ZipFile(sys.argv[1]) as archive:
    document = ET.fromstring(archive.read('word/document.xml'))
    styles = ET.fromstring(archive.read('word/styles.xml'))

def style(name):
    return styles.find(f"w:style[@w:styleId='{name}']", NS)

def value(element, name):
    return element.get('{' + W + '}' + name)

for para in document.findall('.//w:p', NS):
    assert len(para.findall('w:pPr', NS)) <= 1, 'Duplicate paragraph properties'
for name in ('BodyText', 'FirstParagraph'):
    spacing = style(name).find('w:pPr/w:spacing', NS)
    assert value(spacing, 'line') == '500'
    assert value(spacing, 'before') == value(spacing, 'after') == '0'
    assert value(style(name).find('w:pPr/w:ind', NS), 'firstLine') == '480'
for name, size in [('Heading1', '32'), ('Heading2', '30'), ('Heading3', '28'), ('Bibliography', '21')]:
    assert value(style(name).find('w:rPr/w:sz', NS), 'val') == size
captions = document.findall(".//w:pPr/w:pStyle[@w:val='ImageCaption']", NS)
assert len(captions) >= 2, 'Expected both figure and table captions'
assert value(style('ImageCaption').find('w:pPr/w:jc', NS), 'val') == 'center'
assert value(style('ImageCaption').find('w:rPr/w:sz', NS), 'val') == '21'
print('manuscript: body, headings, bibliography, captions and OOXML properties ok')
