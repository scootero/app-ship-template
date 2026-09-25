#!/usr/bin/env bash
# =============================================================================
# coverage-check.sh — "tests must not get worse" gate.          [opt] PHASE 5
# =============================================================================
# Runs the unit tests with coverage, reads the % with xccov, and FAILS if it's
# below MIN_COVERAGE. This is a "ratchet": raise MIN_COVERAGE as you add tests,
# never lower it. Blip runs this before every App Store upload.
#
# Usage:   ./Scripts/coverage-check.sh           (macOS only — needs Xcode)
#
# Start MIN_COVERAGE at 0 and raise it once you have real tests. A number that's
# too high on day one just teaches you to skip the gate.
# =============================================================================
set -euo pipefail
cd "$(dirname "$0")/.."
# shellcheck disable=SC1091
source ./ship.config

MIN_COVERAGE="${MIN_COVERAGE:-0}"   # TODO(phase-5): raise as tests grow, e.g. 40

# Test whichever platform the repo builds; iOS wins if both.
if [[ ",$PLATFORMS," == *",ios,"* ]]; then
  SCHEME="$APP_NAME"
  DEST="platform=iOS Simulator,name=${TEST_SIMULATOR:-iPhone 16}"   # TODO(setup): a simulator you have installed
else
  SCHEME="${APP_NAME}Mac"
  DEST="platform=macOS"
fi

RESULT=".build/coverage.xcresult"
rm -rf "$RESULT"
command -v xcodegen >/dev/null && xcodegen generate --quiet

xcodebuild test \
  -scheme "$SCHEME" \
  -destination "$DEST" \
  -enableCodeCoverage YES \
  -resultBundlePath "$RESULT" \
  -quiet

# lineCoverage for the app target only (not the test bundle), as a percentage.
PCT=$(xcrun xccov view --report --json "$RESULT" | python3 -c "
import json, sys
r = json.load(sys.stdin)
t = [t for t in r['targets'] if not t['name'].endswith('.xctest')]
cov = sum(x['coveredLines'] for x in t); exe = sum(x['executableLines'] for x in t)
print(round(100 * cov / exe, 1) if exe else 0)
")

echo "Coverage: ${PCT}%  (minimum ${MIN_COVERAGE}%)"
python3 -c "import sys; sys.exit(0 if $PCT >= $MIN_COVERAGE else 1)" \
  || { echo "✗ Coverage dropped below the ratchet."; exit 1; }
echo "✓ Coverage gate passed."
