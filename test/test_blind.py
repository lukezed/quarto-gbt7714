"""Render real Quarto outputs and inspect visible content and DOCX metadata."""
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import zipfile
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
assert shutil.which('quarto'), 'These integration checks require Quarto.'
FORMATS = ['html', 'docx']
if '--pdf' in sys.argv:
    assert all(shutil.which(tool) for tool in ('xelatex', 'pdfinfo', 'pdftotext'))
    FORMATS.append('pdf')

PRIVATE = (
    'PrivateAuthor923', 'PrivateInstitute923', 'private923@example.org',
    'PrivateNote923', 'PrivateStudent923', 'PrivateCourse923',
    'PrivateInstructor923', 'PrivateAcknowledgment923', 'PrivateFunding923',
)


def fixture(blind):
    setting = '' if blind is None else f'blind: {str(blind).lower()}\n'
    return f'''---
title: PublicTitle923
paper-style: {'manuscript' if '--manuscript' in sys.argv else 'student'}
format:
  gbt7714-paper-docx:
    reference-doc: _extensions/gbt7714-paper/{'manuscript' if '--manuscript' in sys.argv else 'paper'}-reference.docx
{setting}author:
  - name: PrivateAuthor923
    email: private923@example.org
    orcid: 0000-0002-1825-0097
    affiliations:
      - name: PrivateInstitute923
author-note: PrivateNote923
student-id: PrivateStudent923
course: PrivateCourse923
instructor: PrivateInstructor923
abstract: PublicAbstract923
funding: PrivateFunding923
references:
  - id: self
    type: article-journal
    author:
      - family: PublicSelfCitation923
    title: PublicReference923
    issued:
      date-parts: [[2024]]
---

PublicBody923 [@self].

::: {{.nonblind}}
PrivateAcknowledgment923
:::

::: {{.author-only}}
PrivateNote923
:::
'''


with tempfile.TemporaryDirectory(prefix='quarto-blind-') as tmp:
    directory = Path(tmp)
    shutil.copytree(ROOT / '_extensions', directory / '_extensions')
    for blind in (True, False, None):
        source = directory / 'paper.qmd'
        source.write_text(fixture(blind))
        for fmt in FORMATS:
            result = subprocess.run(
                ['quarto', 'render', str(source), '--to', f'gbt7714-paper-{fmt}', '--quiet'],
                text=True, capture_output=True,
            )
            assert result.returncode == 0, result.stdout + result.stderr
            output = directory / f'paper.{fmt}'
            if fmt == 'docx':
                # Include core properties, custom properties, headers, footers,
                # comments and all other XML parts, not just document.xml.
                with zipfile.ZipFile(output) as archive:
                    for name in archive.namelist():
                        if name.endswith(('.xml', '.rels')):
                            ET.fromstring(archive.read(name))
                    content = '\n'.join(
                        archive.read(name).decode('utf-8')
                        for name in archive.namelist() if name.endswith('.xml')
                    )
            elif fmt == 'pdf':
                if '--manuscript' in sys.argv:
                    pages = subprocess.check_output(['pdftotext', str(output), '-'], text=True).split('\f')
                    assert 'PublicTitle923' in pages[0] and 'PublicAbstract923' not in pages[0]
                    assert 'PublicAbstract923' in pages[1] and 'PublicBody923' not in pages[1]
                    assert 'PublicTitle923' in pages[2] and 'PublicBody923' in pages[2]
                content = '\n'.join(subprocess.run(
                    command, text=True, capture_output=True, check=True,
                ).stdout for command in (
                    ['pdftotext', str(output), '-'], ['pdfinfo', str(output)],
                ))
            else:
                content = output.read_text()
            for public in ('PublicTitle923', 'PublicAbstract923', 'PublicBody923',
                           'PublicSelfCitation923', 'PublicReference923'):
                # Citation styles can apply sentence case to reference titles.
                assert public.casefold() in content.casefold(), (blind, fmt, public)
            if blind:
                for private in PRIVATE + ('0000-0002-1825-0097',):
                    assert private not in content, (fmt, private)
            else:
                # The default and explicit false preserve the author and marked
                # blocks. Other metadata fields depend on the format template.
                for private in ('PrivateAuthor923', 'PrivateAcknowledgment923',
                                'PrivateNote923'):
                    assert private in content, (blind, fmt, private)

print(f'blind: ok (Quarto {", ".join(FORMATS)}, true/false/default, citations preserved)')
