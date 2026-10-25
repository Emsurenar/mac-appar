#!/usr/bin/env python3
"""Fails if a user-facing string in Sources/ has no translation in every Resources/<lang>.lproj."""
import glob
import re
import sys
from pathlib import Path

root = Path(__file__).resolve().parent.parent
source = "\n".join(p.read_text(encoding="utf-8") for p in sorted((root / "Sources").glob("*.swift")))

keys = set(re.findall(r'\bL\("((?:[^"\\]|\\.)*)"', source))
for title, text in re.findall(r'Exercise\(\.\w+, \.\w+, "((?:[^"\\]|\\.)*)", "((?:[^"\\]|\\.)*)"\)', source):
    keys.update([title, text])
cheers = re.search(r"let cheers = \[(.*?)\]", source)
if cheers:
    keys.update(re.findall(r'"((?:[^"\\]|\\.)*)"', cheers.group(1)))

entry = re.compile(r'^\s*"((?:[^"\\]|\\.)*)"\s*=\s*"((?:[^"\\]|\\.)*)"\s*;', re.M)
failed = False
for strings in sorted(root.glob("Resources/*.lproj/Localizable.strings")):
    lang = strings.parent.name.split(".")[0]
    if lang == "en":
        continue  # English is the source language
    table = dict(entry.findall(strings.read_text(encoding="utf-8")))
    missing = sorted(keys - table.keys())
    unused = sorted(table.keys() - keys)
    for key in missing:
        print(f'{lang}: missing translation for "{key}"')
    for key in unused:
        print(f'{lang}: unused translation "{key}"')
    for key in keys & table.keys():
        if key.count("%") != table[key].count("%"):
            print(f'{lang}: placeholder mismatch in "{key}"')
            failed = True
    failed = failed or bool(missing)

if "--list" in sys.argv:
    print("\n".join(sorted(keys)))
sys.exit(1 if failed else 0)
