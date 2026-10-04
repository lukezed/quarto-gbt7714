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
    if name in ('ImageCaption', 'Compact'):
        # Quarto uses Compact for images and ImageCaption for captions.
        # Keep images with captions, and captions with following tables.
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
# Dedicated manuscript styles leave the compact student/journal Word layouts intact.
for name in ('ManuscriptTitle', 'ManuscriptAuthor', 'ManuscriptHeading', 'ManuscriptAbstract', 'ManuscriptBody'):
    style = ET.SubElement(styles, '{' + W + '}style', {'{' + W + '}type': 'paragraph', '{' + W + '}styleId': name})
    child(style, 'name', val=name)
    child(style, 'basedOn', val='BodyText')
    props = child(style, 'pPr')
    child(props, 'spacing', before=0, after=0, line=500, lineRule='exact')
    child(props, 'ind', firstLine=0)
    child(props, 'widowControl')
    run = child(style, 'rPr')
    child(run, 'sz', val=24)
    child(run, 'szCs', val=24)
    if name in ('ManuscriptTitle', 'ManuscriptAuthor', 'ManuscriptHeading'):
        child(props, 'jc', val='center')
    if name in ('ManuscriptTitle', 'ManuscriptHeading'):
        child(run, 'b')
        child(props, 'keepNext')
        child(props, 'spacing', before=1440 if name == 'ManuscriptTitle' else 0, after=240)
    if name == 'ManuscriptBody':
        # Preserve 25pt text spacing while allowing tall display equations.
        child(props, 'spacing', line=500, lineRule='atLeast')
        child(props, 'ind', firstLine=480)

files['word/styles.xml'] = ET.tostring(styles, encoding='utf-8', xml_declaration=True)
document = ET.fromstring(files['word/document.xml'])
section = document.find('w:body/w:sectPr', NS)
child(section, 'pgSz', w=11906, h=16838)
child(section, 'pgMar', top=1440, right=1440, bottom=1440, left=1440, header=720, footer=720, gutter=0)
# Standard page field in the right header, including the title page.
R = 'http://schemas.openxmlformats.org/package/2006/relationships'
ET.register_namespace('', R)
rels = ET.fromstring(files['word/_rels/document.xml.rels'])
rid = 'rIdPaperPageHeader'
ET.SubElement(rels, '{' + R + '}Relationship', {
    'Id': rid, 'Type': 'http://schemas.openxmlformats.org/officeDocument/2006/relationships/header',
    'Target': 'paper-header.xml'})
files['word/_rels/document.xml.rels'] = ET.tostring(rels, encoding='utf-8', xml_declaration=True)
for old in list(section.findall('w:headerReference', NS)):
    section.remove(old)
header_ref = ET.Element('{' + W + '}headerReference', {
    '{' + W + '}type': 'default',
    '{http://schemas.openxmlformats.org/officeDocument/2006/relationships}id': rid})
section.insert(0, header_ref)
files['word/paper-header.xml'] = (
    '<w:hdr xmlns:w="' + W + '"><w:p><w:pPr><w:jc w:val="right"/>'
    '<w:spacing w:before="0" w:after="0"/></w:pPr>'
    '<w:fldSimple w:instr="PAGE"><w:r><w:t>1</w:t></w:r></w:fldSimple></w:p></w:hdr>'
).encode()
content_types = ET.fromstring(files['[Content_Types].xml'])
ET.SubElement(content_types, '{http://schemas.openxmlformats.org/package/2006/content-types}Override', {
    'PartName': '/word/paper-header.xml',
    'ContentType': 'application/vnd.openxmlformats-officedocument.wordprocessingml.header+xml'})
files['[Content_Types].xml'] = ET.tostring(content_types, encoding='utf-8', xml_declaration=True)

files['word/document.xml'] = ET.tostring(document, encoding='utf-8', xml_declaration=True)
out = ROOT / '_extensions/gbt7714-paper/paper-reference.docx'
with ZipFile(out, 'w', ZIP_DEFLATED) as archive:
    for name, data in files.items():
        archive.writestr(name, data)
print(out)
