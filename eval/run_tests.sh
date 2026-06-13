#!/usr/bin/env bash
#
# Runs the SatellitePasses test suite and prints a pass/fail summary.
#
#   ./eval/run_tests.sh           # native `swift test` (macOS or Linux)
#   ./eval/run_tests.sh --linux   # inside swift:5.9-jammy via Docker/OrbStack (arm64)
#
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG="$(mktemp)"

if [[ "${1:-}" == "--linux" ]]; then
    export PATH="$PATH:/Applications/OrbStack.app/Contents/MacOS/xbin"
    docker run --rm --platform linux/arm64 -e SWIFT_BACKTRACE=enable=no \
        -v "$ROOT/Frameworks":/work -w /work/SatellitePasses \
        swift:5.9-jammy swift test 2>&1 | tee "$LOG"
    status=${PIPESTATUS[0]}
else
    ( cd "$ROOT/Frameworks/SatellitePasses" && swift test ) 2>&1 | tee "$LOG"
    status=${PIPESTATUS[0]}
fi

echo
echo "──────────────────────────────────────────────────────────────"
echo "Per-test results:"
# Handles both macOS ("-[Suite method]") and Linux ("Suite.method") XCTest formats.
awk '/Test Case/ && /passed|failed/ && !/expected failure/ {
        status = (/failed/ ? "FAIL" : "pass")
        m = ""
        for (i = 1; i <= NF; i++) if ($i ~ /test[A-Za-z0-9_]+/) { m = $i; gsub(/[^A-Za-z0-9_]/, "", m) }
        if (m != "") printf "  %-50s %s\n", m, status
    }' "$LOG" | sort -u
echo "──────────────────────────────────────────────────────────────"
if [[ $status -eq 0 ]]; then
    echo "RESULT: ✅ all tests passed"
else
    echo "RESULT: ❌ test suite has failures (exit $status) — keep fixing the source"
fi
rm -f "$LOG"
exit $status
