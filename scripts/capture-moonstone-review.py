#!/usr/bin/env python3
"""Capture native dark-only palette evidence without replacing historical baselines."""
import argparse
import json
from pathlib import Path
import subprocess

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--output', type=Path, required=True)
parser.add_argument('--simulator', default='0D39CA43-2212-46F4-AE51-A38A3DDDB9BC')
parser.add_argument('--derived-data', default='/tmp/SatelliteForecast-moonstone-build')
parser.add_argument('--extended', action='store_true', help='Capture the secondary dark snapshot baselines')
parser.add_argument('--planetarium', action='store_true', help='Include the live Metal view; GPU diagnostics may delay Xcode teardown')
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
output = args.output.resolve()
output.mkdir(parents=True, exist_ok=True)
plan = root / 'SatelliteForecast.xctestplan'
original = plan.read_text()
try:
    data = json.loads(original)
    entries = data['defaultOptions']['environmentVariableEntries']
    overrides = {'SNAPSHOT_RECORD': 'after', 'SNAPSHOT_DARK_ONLY': '1', 'SNAPSHOT_OUTPUT': str(output / 'app'),
                 'WIDGET_SCREENSHOT_OUTPUT': str(output / 'widgets'),
                 'SNAPSHOT_PLANETARIUM': '1' if args.planetarium else '0'}
    entries[:] = [entry for entry in entries if entry['key'] not in overrides]
    entries.extend({'key': key, 'value': value} for key, value in overrides.items())
    plan.write_text(json.dumps(data, indent=2) + '\n')
    subprocess.run(['xcodebuildmcp', 'simulator-management', 'set-appearance',
                    '--simulator-id', args.simulator, '--mode', 'dark'], check=True)
    tests = ['testAllScreensLightAndDark', 'testObservationHomeDarkReview',
             'testFloatingTabScreens', 'testWidgetPreviews', 'testWidgetDateLayout']
    if args.extended:
        tests = ['testGeographicLocalizationGallery', 'testPassListLayoutReview',
                 'testHomeDiscovery', 'testPassDiscoveryGlow', 'testFirstVisiblePassVideo',
                 'testAtmosphereScreens', 'testAtmospherePassPath', 'testDaytimeMoonScreens',
                 'testMoonPhaseScreens']
    result = subprocess.run([
        'xcodebuildmcp', 'simulator', 'test', '--project-path', str(root / 'SatelliteForecast.xcodeproj'),
        '--scheme', 'SatelliteForecastApp', '--simulator-id', args.simulator,
        '--derived-data-path', args.derived_data,
        '--json', json.dumps({'extraArgs': ['-disableAutomaticPackageResolution',
            '-onlyUsePackageVersionsFromResolvedFile', '-skipPackageUpdates',
            '-parallel-testing-enabled', 'NO', '-collect-test-diagnostics', 'never'] + [
                '-only-testing:SatelliteForecastTests/ScreenSnapshotTests/' + test for test in tests]}),
    ], cwd=root, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    (output / 'tests.log').write_text(result.stdout)
    print(result.stdout)
    if result.returncode or 'test succeeded' not in result.stdout.lower():
        raise SystemExit(1)
finally:
    plan.write_text(original)
