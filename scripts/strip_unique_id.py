#!/usr/bin/env python3
"""
Strip `unique_id=...` lines from .tscn files.
Usage: python scripts/strip_unique_id.py path/to/file.tscn [...]
Exits with code 1 if any file was changed (so hooks can detect modifications).
"""
import sys
import re
import os

pattern = re.compile(r'(?m)^[ \t]*unique_id=[0-9]+[ \t]*\r?\n')

def strip_file(path: str) -> bool:
    try:
        with open(path, 'r', encoding='utf-8') as f:
            data = f.read()
    except Exception:
        return False
    new = pattern.sub('', data)
    if new != data:
        # write with unix newlines to keep files consistent
        with open(path, 'w', encoding='utf-8', newline='\n') as f:
            f.write(new)
        return True
    return False

def main(argv):
    if len(argv) < 2:
        print('Usage: strip_unique_id.py <file1.tscn> [file2.tscn ...]')
        return 0
    changed_any = False
    for p in argv[1:]:
        if os.path.exists(p) and p.lower().endswith('.tscn'):
            if strip_file(p):
                changed_any = True
                print(f'stripped unique_id from: {p}')
    return 1 if changed_any else 0

if __name__ == '__main__':
    sys.exit(main(sys.argv))
