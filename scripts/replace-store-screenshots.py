#!/usr/bin/env python3
"""Validate reviewed App Store captures; replace only the inventoried draft slots with --apply."""
import argparse
import hashlib
import json
import struct
import subprocess
import time
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--release-dir', type=Path, default=Path(__file__).resolve().parents[1] / 'Documentation/AppStore/1.7.0')
parser.add_argument('--apply', action='store_true')
args = parser.parse_args()
root = args.release_dir.resolve()
manifest = json.loads((root / 'existing-inventory.json').read_text())

def asc(*arguments):
    result = subprocess.run(['asc', *arguments], capture_output=True, text=True, check=True)
    return json.loads(result.stdout)

def screenshots(entry):
    result = asc('screenshots', 'list', '--version-localization', entry['localizationId'])
    sets = [s for s in result['sets'] if s['set']['attributes']['screenshotDisplayType'] == manifest['displayType']]
    if len(sets) != 1:
        raise RuntimeError('Expected one existing screenshot set')
    return sets[0]['screenshots']

version = asc('versions', 'view', '--version-id', manifest['versionId'])
# Replacements must never target an already released version.
version_data = version.get('data', version)
if version_data.get('state', version_data.get('attributes', {}).get('appStoreState')) != 'PREPARE_FOR_SUBMISSION':
    raise RuntimeError('Version is no longer a prepare-for-submission draft')

plans = []
for locale, entry in manifest['locales'].items():
    folder = root / 'screenshots' / locale
    files = sorted(folder.glob('*.png'))
    if [p.stem for p in files] != [s['slot'] for s in entry['screenshots']]:
        raise RuntimeError(f'{locale}: screenshot count/order mismatch')
    for p in files:
        png = p.read_bytes()
        if png[:8] != b'\x89PNG\r\n\x1a\n' or struct.unpack('>II', png[16:24]) != (manifest['width'], manifest['height']):
            raise RuntimeError(f'{p}: invalid PNG or dimensions')
    checksums = [hashlib.md5(p.read_bytes()).hexdigest() for p in files]
    current = screenshots(entry)
    if [s['attributes'].get('sourceFileChecksum') for s in current] == checksums:
        if any(s['attributes'].get('assetDeliveryState', {}).get('state') != 'COMPLETE' for s in current):
            raise RuntimeError(f'{locale}: matching screenshots have not finished processing')
        print(f'{locale}: already matches', flush=True)
        continue
    if [s['id'] for s in current] != [s['id'] for s in entry['screenshots']]:
        raise RuntimeError(f'{locale}: remote screenshots changed since inventory; re-inspect before replacing')
    plans.append((locale, entry, folder, checksums))
    print(f'{locale}: replace 4 {manifest["displayType"]} images', flush=True)

if not args.apply:
    print('Validation complete. No App Store assets changed. Pass --apply after visual review.')
    raise SystemExit(0)

results_path = root / 'upload-results.json'
results = json.loads(results_path.read_text()) if results_path.exists() else {}
for locale, entry, folder, checksums in plans:
    result = asc('screenshots', 'upload', '--version-localization', entry['localizationId'], '--path', str(folder),
                 '--device-type', manifest['displayType'], '--replace')
    results[locale] = result
    results_path.write_text(json.dumps(results, indent=2) + '\n')
    for attempt in range(30):
        current = screenshots(entry)
        states = [s['attributes'].get('assetDeliveryState', {}).get('state') for s in current]
        actual = [s['attributes'].get('sourceFileChecksum') for s in current]
        if len(current) == 4 and states == ['COMPLETE'] * 4 and actual == checksums:
            break
        if any(state == 'FAILED' for state in states):
            raise RuntimeError(f'{locale}: Apple rejected an image: {states}')
        time.sleep(2)
    else:
        raise RuntimeError(f'{locale}: image processing or checksum verification incomplete')
    print(f'{locale}: verified all 4 uploads, order, and checksums', flush=True)
