#!/usr/bin/env python3
"""Capture localized App Store slots with pinned orbit/time/motion fixtures."""
import argparse
import json
import subprocess
import time
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LOCALES = {'en-US': ('en', 'US'), 'fr-FR': ('fr', 'FR'), 'es-ES': ('es', 'ES'),
           'pt-BR': ('pt-BR', 'BR'), 'ru': ('ru', 'RU'), 'ja': ('ja', 'JP'),
           'ko': ('ko', 'KR'), 'zh-Hans': ('zh-Hans', 'CN')}
SCREENS = ['01-forecast', '02-pass-chart', '03-pass-list', '04-satellites']
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--locales', nargs='+', choices=LOCALES, default=list(LOCALES))
parser.add_argument('--screens', nargs='+', choices=SCREENS, default=SCREENS)
parser.add_argument('--simulator', default='5D6FFD0C-6B24-4F95-8E94-B7F3EBD22FDB')
parser.add_argument('--output', type=Path, default=ROOT / 'Documentation/AppStore/1.7.0/screenshots')
args = parser.parse_args()
args.output = args.output.resolve()
args.output.mkdir(parents=True, exist_ok=True)
plan = ROOT / 'SatelliteForecast.xctestplan'
original = plan.read_text()
try:
    for locale in args.locales:
        data = json.loads(original)
        language, region = LOCALES[locale]
        data['defaultOptions']['language'] = language
        data['defaultOptions']['region'] = region
        data['defaultOptions']['environmentVariableEntries'] += [
            {'key': 'STORE_SCREENSHOT_LOCALE', 'value': locale},
            {'key': 'STORE_SCREENSHOT_SCREENS', 'value': ','.join(args.screens)},
            {'key': 'STORE_SCREENSHOT_OUTPUT', 'value': str(args.output)}]
        plan.write_text(json.dumps(data, indent=2) + '\n')
        subprocess.run(['xcrun', 'simctl', 'status_bar', args.simulator, 'override', '--time', '9:41',
                        '--dataNetwork', 'wifi', '--wifiMode', 'active', '--wifiBars', '3',
                        '--batteryState', 'discharging', '--batteryLevel', '100'], check=True)
        extra = ['-disableAutomaticPackageResolution', '-onlyUsePackageVersionsFromResolvedFile', '-skipPackageUpdates',
                 '-only-testing:SatelliteForecastTests/ScreenSnapshotTests/testAppStoreScreenshots']
        folder = args.output / locale
        folder.mkdir(exist_ok=True)
        ready = folder / 'capture-ready.txt'
        done = folder / 'capture-done.txt'
        ready.unlink(missing_ok=True)
        done.unlink(missing_ok=True)
        captured = []
        log_path = args.output / (locale + '.log')
        with log_path.open('w') as log:
            process = subprocess.Popen(['xcodebuildmcp', 'simulator', 'test', '--project-path', str(ROOT / 'SatelliteForecast.xcodeproj'),
                                     '--scheme', 'SatelliteForecastApp', '--simulator-id', args.simulator,
                                     '--derived-data-path', '/tmp/SatelliteForecast-build', '--json', json.dumps({'extraArgs': extra})],
                                    cwd=ROOT, stdout=log, stderr=subprocess.STDOUT)
            try:
                while process.poll() is None:
                    if ready.exists():
                        name = ready.read_text().strip()
                        if name not in args.screens:
                            raise RuntimeError(f'Unexpected screenshot name: {name}')
                        path = folder / (name + '.png')
                        subprocess.run(['xcrun', 'simctl', 'io', args.simulator, 'screenshot', str(path)], check=True, capture_output=True)
                        png = path.read_bytes()
                        if png[:8] != b'\x89PNG\r\n\x1a\n' or struct.unpack('>II', png[16:24]) != (1320, 2868):
                            raise RuntimeError(f'{path}: wrong image dimensions')
                        ready.unlink()
                        captured.append(name)
                        done.write_text(name)
                    time.sleep(0.2)
            finally:
                if process.poll() is None:
                    process.terminate()
                    process.wait()
        output = log_path.read_text()
        if process.returncode or 'Test Run test failed' in output or 'TEST FAILED' in output:
            raise RuntimeError(f'{locale} capture failed; inspect {log_path}')
        if captured != [name for name in SCREENS if name in args.screens]:
            raise RuntimeError(f'{locale}: incomplete capture sequence: {captured}')
        print(f'{locale}: captured {len(captured)} screens', flush=True)
finally:
    plan.write_text(original)
    subprocess.run(['xcrun', 'simctl', 'status_bar', args.simulator, 'clear'], check=False)
