"""Optional pypinyin bridge: JSON in/out, one process per document.

Surname readings adapted from TomBener/quarto-chinese's sort-bib.py (MIT).
Source: https://github.com/TomBener/quarto-chinese/blob/a600c7ccb9b1847d72d5dba3110f11a2f2a5cc77/_extensions/sort-bib.py
See LICENSE-quarto-chinese.txt. Names in the document are never modified.
"""
import json
import sys

try:
    from pypinyin import Style, lazy_pinyin
except ImportError:
    sys.exit('pypinyin is required for gbt7714-sort: pinyin; install with: python -m pip install pypinyin')

SURNAMES = {
    '葛': 'ge3', '阚': 'kan4', '区': 'ou1', '朴': 'piao2', '覃': 'qin2',
    '仇': 'qiu2', '任': 'ren2', '单': 'shan4', '解': 'xie4', '燕': 'yan1',
    '尉': 'yu4', '乐': 'yue4', '曾': 'zeng1', '查': 'zha1',
}


def transliterate(text, surname=False):
    if not text:
        return text
    # A structured family field can contain a full unsplit Chinese name.
    # Literal names may be institutions, so don't apply surname exceptions there.
    if surname and text[0] in SURNAMES:
        syllables = [SURNAMES[text[0]]] + lazy_pinyin(text[1:], style=Style.TONE3)
    else:
        syllables = lazy_pinyin(text, style=Style.TONE3)
    return ' '.join(syllables)


def main():
    # Explicit UTF-8 also works with Windows console/default code pages.
    requests = json.loads(sys.stdin.buffer.read().decode('utf-8'))
    result = {}
    for item in requests:
        for role in ('author', 'editor'):
            for name in item.get(role, []):
                for field, value in name.items():
                    name[field] = transliterate(value, surname=(field == 'family'))
        if item.get('organization'):
            item['organization'] = transliterate(item['organization'])
        result[item['id']] = item
    sys.stdout.buffer.write(json.dumps(result, ensure_ascii=False).encode('utf-8'))


if __name__ == '__main__':
    main()
