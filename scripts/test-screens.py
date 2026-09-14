#!/usr/bin/env python3
"""Run native screenshot/integration tests; baseline recording is always explicit."""
import argparse
import json
from pathlib import Path
import subprocess

parser = argparse.ArgumentParser()
parser.add_argument('--record', choices=['before', 'after'])
parser.add_argument('--simulator', default='3CAEBBC0-6B7D-449D-B957-74545C74BE01')
parser.add_argument('--derived-data', default='/tmp/SatelliteForecast-build')
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
plan = root / 'SatelliteForecast.xctestplan'
original = plan.read_text()
try:
    data = json.loads(original)
    for entry in data['defaultOptions']['environmentVariableEntries']:
        if entry['key'] == 'SNAPSHOT_RECORD':
            entry['value'] = args.record or ''
    plan.write_text(json.dumps(data, indent=2) + '\n')
    result = subprocess.run([
        'xcodebuildmcp', 'simulator', 'test', '--project-path', str(root / 'SatelliteForecast.xcodeproj'),
        '--scheme', 'SatelliteForecastApp', '--simulator-id', args.simulator,
        '--derived-data-path', args.derived_data,
    ], cwd=root, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    print(result.stdout)
    # The MCP CLI may exit zero even when the underlying test operation fails.
    if result.returncode or 'Test Run test failed' in result.stdout or 'TEST FAILED' in result.stdout:
        raise SystemExit(1)
finally:
    plan.write_text(original)
