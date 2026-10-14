#!/usr/bin/env python3
"""Capture dark iPad native-view canvases without changing app settings or phone baselines."""
import argparse
import json
from pathlib import Path
import subprocess

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--output", type=Path, required=True)
parser.add_argument("--simulator", default="12EF8F59-ECBB-4A3B-9450-FA76A523DBC3")
parser.add_argument("--derived-data", default="/tmp/SatelliteForecast-iPad-UX-native-20261012")
parser.add_argument("--packages", default="/tmp/SatelliteForecast-iPad-UX-20261012/SourcePackages")
parser.add_argument("--canvases", default="pro-portrait,pro-landscape,mini-portrait,narrow-window")
parser.add_argument("--screens", help="Optional comma-separated screen names for a targeted recapture")
parser.add_argument("--device-kind", choices=["pad", "phone"], default="pad")
parser.add_argument("--additional-test", action="append", default=[], help="Additional focused test identifier")
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
output = args.output.resolve()
output.mkdir(parents=True, exist_ok=True)
plan = root / "SatelliteForecast.xctestplan"
original = plan.read_text()
try:
    data = json.loads(original)
    entries = data["defaultOptions"]["environmentVariableEntries"]
    overrides = {"IPAD_UX_OUTPUT": str(output / "canvases"), "IPAD_UX_CANVASES": args.canvases,
                 "SNAPSHOT_DARK_ONLY": "1", "SNAPSHOT_PLANETARIUM": "1", "IPAD_UX_DEVICE_KIND": args.device_kind}
    if args.screens:
        overrides["IPAD_UX_SCREENS"] = args.screens
    entries[:] = [entry for entry in entries if entry["key"] not in overrides]
    entries.extend({"key": key, "value": value} for key, value in overrides.items())
    plan.write_text(json.dumps(data, indent=2) + "\n")
    subprocess.run(["xcodebuildmcp", "simulator-management", "set-appearance",
                    "--simulator-id", args.simulator, "--mode", "dark"], check=True)
    extra = ["TARGETED_DEVICE_FAMILY=1,2", "-disableAutomaticPackageResolution",
             "-onlyUsePackageVersionsFromResolvedFile", "-skipPackageUpdates",
             "-parallel-testing-enabled", "NO", "-collect-test-diagnostics", "never",
             "-only-testing:SatelliteForecastTests/ScreenSnapshotTests/testIPadUXReview"]
    if args.packages:
        extra += ["-clonedSourcePackagesDirPath", args.packages]
    extra += ["-only-testing:" + name for name in args.additional_test]
    command = ["xcodebuildmcp", "simulator", "test", "--project-path", str(root / "SatelliteForecast.xcodeproj"),
               "--scheme", "SatelliteForecastApp", "--simulator-id", args.simulator,
               "--derived-data-path", args.derived_data, "--json", json.dumps({"extraArgs": extra})]
    log_path = output / ("capture-targeted-tests.log" if args.screens else "capture-tests.log")
    with log_path.open("w") as log:
        result = subprocess.run(command, cwd=root, text=True, stdout=log, stderr=subprocess.STDOUT)
    log_text = log_path.read_text()
    print(log_text[-6000:])
    if result.returncode or "test succeeded" not in log_text.lower():
        raise SystemExit(1)
finally:
    plan.write_text(original)
