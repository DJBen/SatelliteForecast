#!/usr/bin/env python3
"""Native dark-mode localization matrix plus ActivityKit lifecycle checks."""
import argparse
import json
from pathlib import Path
import subprocess
parser = argparse.ArgumentParser()
parser.add_argument('--output', required=True, type=Path)
parser.add_argument('--simulator', required=True)
parser.add_argument('--derived-data', default='/tmp/SatelliteForecast-live-build')
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
output = args.output.resolve()
output.mkdir(parents=True, exist_ok=False)
plan = root / 'SatelliteForecast.xctestplan'
original = plan.read_text()
try:
    data = json.loads(original)
    data['defaultOptions']['environmentVariableEntries'].append({'key':'LIVE_ACTIVITY_OUTPUT','value':str(output)})
    plan.write_text(json.dumps(data, indent=2)+'\n')
    subprocess.run(['xcodebuildmcp','simulator-management','set-appearance','--simulator-id',args.simulator,'--mode','dark'],check=True)
    selectors = ['testLiveActivityStatesAndLocales','testLiveActivityLocaleMatrix','testLiveActivitySystemLifecycle']
    extra = ['-only-testing:SatelliteForecastTests/ScreenSnapshotTests/'+s for s in selectors]
    extra += ['-only-testing:SatelliteForecastTests/NativeArchitectureTests','-parallel-testing-enabled','NO']
    result = subprocess.run(['xcodebuildmcp','simulator','test','--project-path',str(root/'SatelliteForecast.xcodeproj'),
        '--scheme','SatelliteForecastApp','--simulator-id',args.simulator,'--derived-data-path',args.derived_data,
        '--json',json.dumps({'extraArgs':extra})],cwd=root,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
    (output/'tests.log').write_text(result.stdout)
    print(result.stdout)
    if result.returncode or 'test succeeded' not in result.stdout or not (output/'summary.txt').exists():
        raise SystemExit(1)
finally:
    plan.write_text(original)
