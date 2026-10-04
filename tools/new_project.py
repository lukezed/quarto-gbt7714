"""Create a self-contained writing project from the templates shipped in this repo.

Usage: python3 tools/new_project.py student|manuscript|journal /path/to/new-project
"""
import argparse
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('style', choices=('student', 'manuscript', 'journal'))
    parser.add_argument('destination', type=Path)
    args = parser.parse_args()
    dest = args.destination.expanduser().absolute()
    if dest.exists():
        parser.error(f'destination already exists: {dest}; choose a new directory')
    source = ROOT / 'templates' / args.style
    shutil.copytree(source, dest, ignore=shutil.ignore_patterns('_output*', '.quarto', '_extensions'))
    for extension in ('gbt7714', 'gbt7714-paper'):
        shutil.copytree(ROOT / '_extensions' / extension, dest / '_extensions' / extension)
    print(f'Created {args.style} project: {dest}')
    print('Open that directory and run: quarto render')
    print('Anonymous output: quarto render --profile blind')


if __name__ == '__main__':
    main()
