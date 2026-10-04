"""Build the writing templates' A4, 12pt, 1.5-spaced Word reference document."""
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
W = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'
ET.register_namespace('w', W)
ET.register_namespace('r', 'http://schemas.openxmlformats.org/officeDocument/2006/relationships')
NS = {'w': W}

def child(parent, name, **attrs):
    element = parent.find('w:' + name, NS)
    if element is None:
        element = ET.SubElement(parent, '{' + W + '}' + name)
    for key, value in attrs.items():
        element.set('{' + W + '}' + key, str(value))
    return element

with ZipFile(ROOT / '_extensions/gbt7714/gbt7714-reference.docx') as archive:
    files = {name: archive.read(name) for name in archive.namelist()}
styles = ET.fromstring(files['word/styles.xml'])
for color in styles.findall('.//w:color', NS):
    color.attrib.clear()
    color.set('{' + W + '}val', '000000')
defaults = styles.find('w:docDefaults/w:rPrDefault/w:rPr', NS)
child(defaults, 'sz', val=24)
child(defaults, 'szCs', val=24)
child(defaults, 'color', val='000000')
for style in styles.findall('w:style', NS):
    name = style.get('{' + W + '}styleId', '')
    if name in ('Normal', 'BodyText', 'FirstParagraph', 'Abstract', 'Bibliography'):
        props = child(style, 'pPr')
        child(props, 'spacing', before=0, after=120, line=360, lineRule='auto')
        child(props, 'widowControl')
    if name == 'ImageCaption':
        # Quarto uses this style for both figure and table captions.
        child(child(style, 'pPr'), 'keepNext')
    if name in ('Author', 'Date'):
        props = child(style, 'rPr')
        child(props, 'b', val=0)
        child(props, 'sz', val=24)
        child(props, 'szCs', val=24)
    if name in ('Title', 'Subtitle') or name.startswith('Heading'):
        props = child(style, 'rPr')
        child(props, 'color', val='000000')
        size = 36 if name == 'Title' else 28 if name == 'Heading1' else 24
        child(props, 'sz', val=size)
        child(props, 'szCs', val=size)
        child(props, 'b')
        pprops = child(style, 'pPr')
        child(pprops, 'keepNext')
        child(pprops, 'spacing', before=180, after=120, line=240, lineRule='auto')
files['word/styles.xml'] = ET.tostring(styles, encoding='utf-8', xml_declaration=True)
document = ET.fromstring(files['word/document.xml'])
section = document.find('w:body/w:sectPr', NS)
child(section, 'pgSz', w=11906, h=16838)
child(section, 'pgMar', top=1440, right=1440, bottom=1440, left=1440, header=720, footer=720, gutter=0)
files['word/document.xml'] = ET.tostring(document, encoding='utf-8', xml_declaration=True)
out = ROOT / '_extensions/gbt7714-paper/paper-reference.docx'
with ZipFile(out, 'w', ZIP_DEFLATED) as archive:
    for name, data in files.items():
        archive.writestr(name, data)
print(out)
