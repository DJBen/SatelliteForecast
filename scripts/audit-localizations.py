#!/usr/bin/env python3
"""Check app translation coverage and printf arguments. Run on macOS (uses plutil)."""
import collections
import json
from pathlib import Path
import plistlib
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
LOCALES = ('en', 'fr', 'es', 'pt-BR', 'ru', 'zh-Hans', 'ja', 'ko')
errors = []

def table(path):
    content = path.read_text()
    keys = re.findall(r'^"((?:[^"\\]|\\.)*)"\s*=', content, re.M)
    for key, count in collections.Counter(keys).items():
        if count != 1:
            errors.append(f'{path}: duplicate key {key}')
    return json.loads(subprocess.check_output(['plutil', '-convert', 'json', '-o', '-', str(path)]))

def arguments(value):
    # Positional arguments may move in translation, but type and count must match.
    return collections.Counter(re.findall(r'%(?:\d+\$)?[-+ #0]*\d*(?:\.\d+)?(lld|llu|ld|lu|d|u|f|g|@)', value.replace('%%', '')))

for target in ('Impl', 'Public'):
    source = ROOT / f'Frameworks/SatelliteForecast/{target}/Sources'
    resources = source / 'Resources'
    tables = {locale: table(resources / f'{locale}.lproj/Localizable.strings') for locale in LOCALES}
    expected = set(tables['en'])
    plural_keys = set()
    for locale in LOCALES:
        path = resources / f'{locale}.lproj/Localizable.stringsdict'
        if path.exists():
            plural = plistlib.loads(path.read_bytes())
            if not plural_keys:
                plural_keys = set(plural)
            if set(plural) != plural_keys:
                errors.append(f'{locale}: plural keys differ')
            for key, entry in plural.items():
                for name, rule in entry.items():
                    if isinstance(rule, dict) and 'other' not in rule:
                        errors.append(f'{locale}/{key}/{name}: missing other plural form')
        if set(tables[locale]) != expected:
            errors.append(f'{target}/{locale}: keys differ: {set(tables[locale]) ^ expected}')
        for key, value in tables[locale].items():
            if not value or arguments(value) != arguments(tables['en'].get(key, '')):
                errors.append(f'{target}/{locale}/{key}: empty translation or mismatched format arguments')
    for path in source.rglob('*.swift'):
        if '/Debug/' in str(path):
            continue
        text = path.read_text()
        if 'bundle: .main' in text:
            errors.append(f'{path}: package localization must use its own bundle')
        for match in re.finditer(r'(?:Text|Label|Button|Toggle|ProgressView|ContentUnavailableView|NSLocalizedString|AppLocalization\.(?:text|format)|accessibilityLabel|accessibilityHint)\(\s*"([^"\n]*)"', text):
            key = match[1]
            if key in ('', 'N', '3D') or '\\(' in key:
                continue  # Invariant symbols, or dynamic content checked manually.
            if key not in expected | plural_keys:
                errors.append(f'{path}: missing key {key!r}')
    print(f'{target}: {len(expected)} strings across {len(LOCALES)} locales')

catalog = json.loads((ROOT / 'SatelliteForecastApp/InfoPlist.xcstrings').read_text())
for key, entry in catalog['strings'].items():
    if entry.get('shouldTranslate') is False:
        continue
    if set(entry.get('localizations', {})) != set(LOCALES):
        errors.append(f'InfoPlist/{key}: incomplete translations')
for error in errors:
    print(error)
raise SystemExit(bool(errors))
