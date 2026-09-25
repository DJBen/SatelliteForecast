#!/usr/bin/env python3
"""Render the shared native widget layouts in dark mode and run forecast tests."""
import argparse
import json
from pathlib import Path
import subprocess

parser = argparse.ArgumentParser()
parser.add_argument('--simulator', required=True, help='iPhone 17 Pro Max simulator UDID')
parser.add_argument('--output', required=True, type=Path, help='New screenshot evidence directory')
parser.add_argument('--derived-data', default='/tmp/SatelliteForecast-widget-build')
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
output = args.output.resolve()
output.mkdir(parents=True, exist_ok=True)
plan = root / 'SatelliteForecast.xctestplan'
original = plan.read_text()
try:
    data = json.loads(original)
    entries = data['defaultOptions']['environmentVariableEntries']
    entries[:] = [entry for entry in entries if entry['key'] != 'WIDGET_SCREENSHOT_OUTPUT']
    entries.append({'key': 'WIDGET_SCREENSHOT_OUTPUT', 'value': str(output)})
    plan.write_text(json.dumps(data, indent=2) + '\n')
    subprocess.run(['xcodebuildmcp', 'simulator-management', 'set-appearance',
                    '--simulator-id', args.simulator, '--mode', 'dark'], check=True)
    result = subprocess.run([
        'xcodebuildmcp', 'simulator', 'test', '--project-path', str(root / 'SatelliteForecast.xcodeproj'),
        '--scheme', 'SatelliteForecastApp', '--simulator-id', args.simulator,
        '--derived-data-path', args.derived_data,
        '--json', json.dumps({'extraArgs': [
            '-only-testing:SatelliteForecastTests/ForecastTests',
            '-only-testing:SatelliteForecastTests/ScreenSnapshotTests/testWidgetPreviews',
            '-only-testing:SatelliteForecastTests/ScreenSnapshotTests/testWidgetDateLayout',
            '-only-testing:SatelliteForecastTests/ScreenSnapshotTests/testWidgetLocaleMatrix',
            '-parallel-testing-enabled', 'NO']}),
    ], cwd=root, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    (output / 'tests.log').write_text(result.stdout)
    print(result.stdout)
    if result.returncode or 'test succeeded' not in result.stdout or not (output / 'overview.png').exists():
        raise SystemExit(1)
finally:
    plan.write_text(original)
