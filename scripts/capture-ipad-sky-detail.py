#!/usr/bin/env python3
"""Capture the opt-in dark native iPad chart-detail comparison."""
import argparse
import json
from pathlib import Path
import subprocess

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--output', type=Path, required=True)
parser.add_argument('--simulator', default='12EF8F59-ECBB-4A3B-9450-FA76A523DBC3')
parser.add_argument('--derived-data', default='/tmp/SatelliteForecast-iPad-UX-native-20261012')
parser.add_argument('--packages', default='/tmp/SatelliteForecast-iPad-UX-20261012/SourcePackages')
parser.add_argument('--selected-only', action='store_true', help='Capture the selected size-adaptive defaults')
parser.add_argument('--additional-test', action='append', default=[], help='Additional focused test identifier')
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
output = args.output.resolve(); output.mkdir(parents=True, exist_ok=True)
plan = root/'SatelliteForecast.xctestplan'; original = plan.read_text()
try:
    data = json.loads(original)
    entries = data['defaultOptions']['environmentVariableEntries']
    entries[:] = [e for e in entries if e['key'] not in ('SKY_DETAIL_OUTPUT', 'SKY_DETAIL_SELECTED_ONLY')]
    entries.append({'key':'SKY_DETAIL_OUTPUT', 'value':str(output/'captures')})
    if args.selected_only:
        entries.append({'key':'SKY_DETAIL_SELECTED_ONLY', 'value':'1'})
    plan.write_text(json.dumps(data, indent=2)+'\n')
    subprocess.run(['xcodebuildmcp','simulator-management','set-appearance','--simulator-id',args.simulator,'--mode','dark'],check=True)
    extra = ['-clonedSourcePackagesDirPath',args.packages,'-disableAutomaticPackageResolution','-onlyUsePackageVersionsFromResolvedFile','-skipPackageUpdates','-parallel-testing-enabled','NO','-collect-test-diagnostics','never','-only-testing:SatelliteForecastTests/ScreenSnapshotTests/testIPadSkyDetailExploration','-only-testing:SatelliteForecastTests/SkyChartDetailTests']
    extra += ['-only-testing:'+name for name in args.additional_test]
    with (output/'capture-tests.log').open('w') as log:
        result = subprocess.run(['xcodebuildmcp','simulator','test','--project-path',str(root/'SatelliteForecast.xcodeproj'),'--scheme','SatelliteForecastApp','--simulator-id',args.simulator,'--derived-data-path',args.derived_data,'--json',json.dumps({'extraArgs':extra})],cwd=root,text=True,stdout=log,stderr=subprocess.STDOUT)
    report = (output/'capture-tests.log').read_text()
    print(report[-7000:])
    if result.returncode or 'test succeeded' not in report.lower():raise SystemExit(1)
finally:
    plan.write_text(original)
