#!/usr/bin/env python3
"""Verify Live Activity resource parity, duplicate keys and format arguments."""
from pathlib import Path
import collections
import json
import re
import subprocess

root = Path(__file__).resolve().parents[1]
resources = root / 'Frameworks/SatelliteForecast/WidgetSupport/Resources'
languages = ['en', 'es', 'fr', 'pt-BR', 'ru', 'zh-Hans', 'ja', 'ko']
tables = {}
for language in languages:
    path = resources / f'{language}.lproj/Localizable.strings'
    keys = re.findall(r'^"([^"]+)"\s*=', path.read_text(), re.M)
    assert all(count == 1 for count in collections.Counter(keys).values()), f'Duplicate keys: {language}'
    tables[language] = json.loads(subprocess.check_output(['plutil', '-convert', 'json', '-o', '-', str(path)]))
expected = tables['en']
def arguments(text):
    return collections.Counter(re.findall(r'%(?:\d+\$)?(?:lld|llu|ld|lu|d|u|f|g|@)', text.replace('%%', '')))
for language, table in tables.items():
    assert set(table) == set(expected), f'Key mismatch: {language}'
    for key, value in expected.items():
        assert table[key].strip(), (language, key)
        assert arguments(value) == arguments(table[key]), f'Format mismatch: {language}/{key}'
print(f'PASS: {sum(k.startswith("live.") for k in expected)} Live Activity keys in all {len(languages)} locales; widget key parity, duplicate and format checks passed.')
