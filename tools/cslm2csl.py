"""Convert zotero-chinese bilingual CSL-M styles into plain CSL 1.0 that pandoc citeproc accepts.

CSL-M picks a layout per item locale (<layout locale="en">). Plain CSL cannot, so we:
  * duplicate every macro as <name>-en, with localized terms/labels replaced by English literals;
  * merge the two layouts into one: <if variable="language"> zh branch, <else> en branch.
The Lua filter sets `language` only on CJK entries, so its presence means "Chinese".
Et al.: zh entries use term "et-al" (zh-CN: 等); en entries use "and others", overridden to "et al.".
Usage: python3 tools/cslm2csl.py in.csl out.csl
"""
import copy, re, sys
import xml.etree.ElementTree as ET

NS = 'http://purl.org/net/xbiblio/csl'
ET.register_namespace('', NS)
q = lambda t: f'{{{NS}}}{t}'

# English literals for the few localized terms these styles use (en-US defaults).
EN_TERMS = {('anonymous', 'short'): 'Anon', ('anonymous', 'long'): 'Anonymous',
            ('no date', 'short'): 'n.d.', ('no date', 'long'): 'no date'}
EN_LABELS = {'edition': ' ed.', 'volume': 'v.', 'version': 'v.', 'locator': ''}

def en_copy(el):
    el = copy.deepcopy(el)
    for parent in el.iter():
        for i, c in enumerate(list(parent)):
            tag = c.tag.split('}')[1]
            if tag == 'text' and 'macro' in c.attrib:
                c.set('macro', c.get('macro') + '-en')
            elif tag == 'text' and 'term' in c.attrib:
                key = (c.get('term'), c.get('form', 'long'))
                if key in EN_TERMS:
                    a = {k: v for k, v in c.attrib.items() if k not in ('term', 'form', 'plural')}
                    a['value'] = EN_TERMS[key]
                    c.attrib.clear(); c.attrib.update(a)
            elif tag == 'label' and c.get('variable') in EN_LABELS:
                a = {k: v for k, v in c.attrib.items() if k not in ('variable', 'form', 'plural')}
                a['value'] = EN_LABELS[c.get('variable')]
                n = ET.Element(q('text'), a); n.tail = c.tail
                parent.remove(c); parent.insert(i, n)
            elif tag == 'et-al':
                c.set('term', 'and others')
    for names in el.iter(q('names')):
        if names.find(q('et-al')) is None and names.find(q('name')) is not None:
            names.insert(list(names).index(names.find(q('name'))) + 1, ET.Element(q('et-al'), {'term': 'and others'}))
    return el

def zh_etal(el):
    for e in el.iter(q('et-al')):
        e.set('term', 'et-al')
    for names in el.iter(q('names')):
        if names.find(q('et-al')) is None and names.find(q('name')) is not None:
            names.insert(list(names).index(names.find(q('name'))) + 1, ET.Element(q('et-al'), {'term': 'et-al'}))

def merge(parent, tag):
    sec = parent.find(q(tag))
    if sec is None: return
    lays = sec.findall(q('layout'))
    en = [l for l in lays if l.get('locale') == 'en']
    zh = [l for l in lays if l.get('locale') is None]
    if not en: return
    en, zh = en[0], zh[0]
    sec.remove(en)
    # Keep a shared leading element (the citation number) outside <choose>:
    # second-field-align treats the layout's first child as the left margin.
    shared = []
    while (len(en) and len(zh) and zh[0].get('variable') == 'citation-number'
           and ET.tostring(en[0]) == ET.tostring(zh[0])):
        shared.append(zh[0]); zh.remove(zh[0]); en.remove(en[0])
    def body(l):
        g = ET.Element(q('group'))
        g.extend(list(l))
        return g
    choose = ET.Element(q('choose'))
    i = ET.SubElement(choose, q('if'), {'variable': 'language'}); i.append(body(zh))
    e = ET.SubElement(choose, q('else')); e.append(en_copy(body(en)))
    # outer affixes/delimiter come from the zh layout (shared by both in practice)
    for c in list(zh): zh.remove(c)
    zh.extend(shared)
    zh.append(choose)

def main(src, dst):
    s = open(src, encoding='utf-8').read()
    root = ET.fromstring(s)
    for loc in root.findall(q('locale')):
        if loc.get('{http://www.w3.org/XML/1998/namespace}lang') == 'zh':
            terms = loc.find(q('terms'))
            # zh entries use "et-al" (等, from zh-CN); en entries use "and others", repurposed here
            for t in terms.findall(q('term')):
                if t.get('name') == 'and others': terms.remove(t)
            ET.SubElement(terms, q('term'), {'name': 'and others'}).text = 'et al.'
            for t in terms.findall(q('term')):
                if t.get('name') == 'volume' and '%s' in (t.text or ''):  # CSL-M term pattern
                    t.text = t.text.replace('%s', '')  # ponytail: "第卷" ceiling; numbered form handled by bst diff later
        for t in loc.iter(q('term')):
            if t.get('name') == 'citation-range-delimiter':  # CSL-M only
                loc.find(q('terms')).remove(t)
    macros = root.findall(q('macro'))
    for m in macros:
        zh_etal(m)
        m2 = en_copy(m); m2.set('name', m.get('name') + '-en')
        root.insert(list(root).index(m) + 1, m2)
    for tag in ('citation', 'bibliography'):  # zh layouts only; en ones are rewritten by merge()
        for lay in root.iter(q(tag)):
            for l in lay.findall(q('layout')):
                if l.get('locale') is None: zh_etal(l)
    merge(root, 'citation'); merge(root, 'bibliography')
    ET.ElementTree(root).write(dst, encoding='utf-8', xml_declaration=True)

if __name__ == '__main__':
    main(*sys.argv[1:3])
