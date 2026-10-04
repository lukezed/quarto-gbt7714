"""Build _extensions/gbt7714/gbt7714-reference.docx from pandoc's default reference.docx.

Changes: Bibliography style gets a hanging indent (pandoc's docx writer ignores the CSL
hanging-indent setting), and body text defaults to Times New Roman + 宋体.
Usage: python3 tools/make_reference_docx.py
"""
import os, re, subprocess, tempfile, zipfile

OUT = os.path.join(os.path.dirname(__file__), '..', '_extensions', 'gbt7714', 'gbt7714-reference.docx')

with tempfile.TemporaryDirectory() as d:
    src = os.path.join(d, 'ref.docx')
    subprocess.run(['quarto', 'pandoc', '-o', src, '--print-default-data-file', 'reference.docx'], check=True)
    with zipfile.ZipFile(src) as z:
        files = {n: z.read(n) for n in z.namelist()}

styles = files['word/styles.xml'].decode('utf-8')
# hanging indent of 2 CJK characters at 12pt (240 twips each); a tab after [n] lands on it
styles = re.sub(r'(<w:style w:type="paragraph" w:styleId="Bibliography">.*?)<w:pPr />',
                r'\1<w:pPr><w:spacing w:after="60" /><w:ind w:left="480" w:hanging="480" /></w:pPr>',
                styles, count=1, flags=re.S)
styles = styles.replace(
    '<w:rFonts w:asciiTheme="minorHAnsi" w:eastAsiaTheme="minorEastAsia" w:hAnsiTheme="minorHAnsi" w:cstheme="minorBidi" />',
    '<w:rFonts w:ascii="Times New Roman" w:eastAsia="宋体" w:hAnsi="Times New Roman" w:cstheme="minorBidi" />', 1)
assert 'w:hanging="480"' in styles and 'w:eastAsia="宋体"' in styles
files['word/styles.xml'] = styles.encode('utf-8')

with zipfile.ZipFile(OUT, 'w', zipfile.ZIP_DEFLATED) as z:
    for n, b in files.items():
        z.writestr(n, b)
print('wrote', os.path.normpath(OUT))
