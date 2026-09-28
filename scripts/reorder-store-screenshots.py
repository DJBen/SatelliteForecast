#!/usr/bin/env python3
"""Upload each locale's six screenshots in the store order recorded in slot-order.json.

The replace script uploads in filename order. When the store order differs (2.0.0 leads
with the widget slot), use this script instead: it copies the slot PNGs into a temporary
directory named by position, replaces the locale's APP_IPHONE_67 set, and verifies that
the remote checksums come back in the requested order and COMPLETE. Locales whose remote
set already matches are skipped. Only PREPARE_FOR_SUBMISSION and DEVELOPER_REJECTED drafts are touched.
"""
import argparse
import hashlib
import json
import pathlib
import shutil
import subprocess
import tempfile
import time

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--release-dir', type=pathlib.Path, required=True)
parser.add_argument('--locales', nargs='+')
parser.add_argument('--apply', action='store_true')
args = parser.parse_args()
root = args.release_dir.resolve()
inv = json.loads((root / 'existing-inventory.json').read_text())
order = json.loads((root / 'slot-order.json').read_text())
shots = root / 'screenshots'


def asc(*a):
    r = subprocess.run(['asc', *a], capture_output=True, text=True)
    if r.returncode:
        raise RuntimeError(f'asc {a[0]} {a[1]}: {r.stderr[:300]} {r.stdout[:300]}')
    return json.loads(r.stdout)


def remote(loc):
    s = asc('screenshots', 'list', '--version-localization', inv['locales'][loc]['localizationId'])
    sets = [x for x in s['sets'] if x['set']['attributes']['screenshotDisplayType'] == inv['displayType']]
    if not sets:
        return []
    return [(x['attributes'].get('sourceFileChecksum'), x['attributes'].get('assetDeliveryState', {}).get('state'))
            for x in sets[0]['screenshots']]


version = asc('versions', 'view', '--version-id', inv['versionId'])
data = version.get('data', version)
state = data.get('state', data.get('attributes', {}).get('appStoreState'))
if state not in {'PREPARE_FOR_SUBMISSION', 'DEVELOPER_REJECTED'}:
    raise RuntimeError(f'Version is {state}, not an editable draft')

results = {}
for loc in inv['locales']:
    if args.locales and loc not in args.locales:
        continue
    want = [hashlib.md5((shots / loc / f'{slot}.png').read_bytes()).hexdigest() for slot in order]
    current = remote(loc)
    if [c for c, _ in current] == want and all(st == 'COMPLETE' for _, st in current):
        print(f'{loc}: already matches', flush=True)
        continue
    print(f'{loc}: {"replacing" if args.apply else "would replace"} {len(order)} images in store order', flush=True)
    if not args.apply:
        continue
    with tempfile.TemporaryDirectory() as tmp:
        for i, slot in enumerate(order, 1):
            shutil.copy(shots / loc / f'{slot}.png', pathlib.Path(tmp) / f'{i}-{slot}.png')
        results[loc] = asc('screenshots', 'upload', '--version-localization', inv['locales'][loc]['localizationId'],
                           '--path', tmp, '--device-type', inv['displayType'], '--replace')
    for _ in range(40):
        current = remote(loc)
        if [c for c, _ in current] == want and all(st == 'COMPLETE' for _, st in current):
            break
        if any(st == 'FAILED' for _, st in current):
            raise RuntimeError(f'{loc}: Apple rejected an image')
        time.sleep(3)
    else:
        raise RuntimeError(f'{loc}: order or processing not verified')
    print(f'{loc}: verified {len(order)} images, order and checksums', flush=True)
if results:
    results_path = root / 'reorder-results.json'
    previous = json.loads(results_path.read_text()) if results_path.exists() else {}
    previous.update(results)
    results_path.write_text(json.dumps(previous, indent=1) + '\n')
