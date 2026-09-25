#!/usr/bin/env bash
# =============================================================================
# capture-ios-screenshots.sh — App Store screenshots in one command.  [ios] PHASE 4
# =============================================================================
# Builds the app for the simulator, then for every
#   device (iPhone 6.9", iPad 13") × language (LOCALES) × screen (SCREENSHOT_ROUTES)
# it launches the app with `-demo 1 -route <screen>` and saves a PNG.
#
# Output:  store/screenshots/<locale>/<device>/<NN>-<route>.png
#          e.g. store/screenshots/en-US/iphone-6.9/01-home.png
#
# Those are the RAW shots at exactly the sizes Apple requires. Upload them
# as-is, or add frames/captions first (see "Framing" in README.md).
#
# Tricks copied from Blip's rig:
#   - DEDICATED simulators ("Shots iPhone" / "Shots iPad"), wiped every run,
#     so no other app's popups or data ever show up in a shot.
#   - Status bar forced to 9:41, full battery, full signal (Apple's look).
#   - Alternates dark / light mode so the set shows both are supported.
#   - The app's language is switched with -AppleLanguages per locale.
#
# Usage (macOS with Xcode):
#   ./Tools/capture-ios-screenshots.sh              # everything
#   ./Tools/capture-ios-screenshots.sh iphone       # one device
#
# Requirements in the APP: the -demo and -route hooks in
# Shared/Sources/LaunchOptions.swift. No hooks = empty screenshots.
# =============================================================================
set -euo pipefail
cd "$(dirname "$0")/.."
# shellcheck disable=SC1091
source ./ship.config

ONLY="${1:-}"
BUNDLE_ID="$BUNDLE_ID_PREFIX.$APP_NAME"
OUT="store/screenshots"
SETTLE_SECONDS="${SETTLE_SECONDS:-3}"   # wait after launch for animations to finish

# Device key | simulator name we create | device type (name as Xcode lists it).
# TODO(phase-4): if Xcode says a device type doesn't exist, run
#   xcrun simctl list devicetypes
# and use the newest "Pro Max" iPhone and 13-inch iPad Pro names you see.
# Apple's required sizes: iPhone 6.9" (1320×2868) and iPad 13" (2064×2752).
DEVICES=(
  "iphone-6.9|Shots iPhone|iPhone 17 Pro Max"
  "ipad-13|Shots iPad|iPad Pro 13-inch (M5)"
)
# Remove the iPad line if your app is iPhone-only (TARGETED_DEVICE_FAMILY "1").

# --- 1. Build once for the simulator ------------------------------------------
echo "→ Building $APP_NAME for the simulator"
command -v xcodegen >/dev/null && xcodegen generate --quiet
xcodebuild build \
  -scheme "$APP_NAME" \
  -destination "generic/platform=iOS Simulator" \
  -derivedDataPath .build/shots \
  -quiet
APP_PATH=$(find .build/shots/Build/Products -name "$APP_NAME.app" -path "*iphonesimulator*" | head -1)
[[ -d "$APP_PATH" ]] || { echo "✗ built app not found"; exit 1; }

# --- helpers --------------------------------------------------------------------
# Find our dedicated simulator by name, or create it on the newest iOS runtime.
sim_udid() {
  local name="$1" type="$2" udid
  udid=$(xcrun simctl list devices -j | python3 -c "
import json, sys
for devs in json.load(sys.stdin)['devices'].values():
    for d in devs:
        if d['name'] == sys.argv[1] and d.get('isAvailable', True):
            print(d['udid']); break
" "$name" | head -1)
  if [[ -z "$udid" ]]; then
    local runtime
    runtime=$(xcrun simctl list runtimes -j | python3 -c "
import json, sys
rs = [r for r in json.load(sys.stdin)['runtimes'] if r['platform'] == 'iOS' and r['isAvailable']]
print(sorted(rs, key=lambda r: [int(x) for x in r['version'].split('.')])[-1]['identifier'])")
    udid=$(xcrun simctl create "$name" "$type" "$runtime")
  fi
  echo "$udid"
}

# "de-DE" → -AppleLanguages (de-DE) -AppleLocale de_DE
locale_args() {
  local loc="$1"
  echo "-AppleLanguages (${loc}) -AppleLocale ${loc//-/_}"
}

# --- 2. Capture ----------------------------------------------------------------
for entry in "${DEVICES[@]}"; do
  IFS='|' read -r key name type <<<"$entry"
  [[ -n "$ONLY" && "$key" != *"$ONLY"* ]] && continue

  echo "→ $key ($type)"
  udid=$(sim_udid "$name" "$type")
  xcrun simctl shutdown "$udid" 2>/dev/null || true
  xcrun simctl erase "$udid"                    # clean slate every run
  xcrun simctl boot "$udid"
  xcrun simctl bootstatus "$udid" -b >/dev/null
  xcrun simctl install "$udid" "$APP_PATH"
  xcrun simctl status_bar "$udid" override \
    --time "9:41" --batteryState charged --batteryLevel 100 \
    --cellularMode active --cellularBars 4 --wifiBars 3

  for loc in $LOCALES; do
    dir="$OUT/$loc/$key"
    mkdir -p "$dir"
    n=0
    for route in $SCREENSHOT_ROUTES; do
      n=$((n + 1))
      # Odd shots dark, even shots light.
      mode=$([[ $((n % 2)) == 1 ]] && echo dark || echo light)
      xcrun simctl ui "$udid" appearance "$mode"

      xcrun simctl terminate "$udid" "$BUNDLE_ID" 2>/dev/null || true
      # shellcheck disable=SC2046
      xcrun simctl launch "$udid" "$BUNDLE_ID" -demo 1 -route "$route" $(locale_args "$loc") >/dev/null
      sleep "$SETTLE_SECONDS"

      file="$dir/$(printf '%02d' $n)-$route.png"
      xcrun simctl io "$udid" screenshot "$file" >/dev/null
      echo "   ✓ $file ($mode)"
    done
  done
  xcrun simctl shutdown "$udid"
done

echo "✓ Screenshots in $OUT/. Review them, then upload (App Store Connect →"
echo "  your version → drag in), or frame them first (README → Framing)."
