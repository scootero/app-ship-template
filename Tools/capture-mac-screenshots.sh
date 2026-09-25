#!/usr/bin/env bash
# =============================================================================
# capture-mac-screenshots.sh — Mac App Store screenshots.       [mac] PHASE 4
# =============================================================================
# Simpler than Blip's version. Blip hides the Dock, desktop icons and other
# menu-bar apps, swaps the wallpaper, captures, then restores everything. That's
# great for menu-bar apps, but a lot of script. This version:
#   builds the Mac app → launches it with -demo 1 -route <screen> →
#   captures ONLY the app's window (no shadow) → quits.
#
# Output: store/screenshots/<locale>/mac/<NN>-<route>.png
#
# Apple accepts Mac screenshots at 1280×800, 1440×900, 2560×1600 or 2880×1800.
# A window-only capture is NOT one of those sizes, so place it on a background
# canvas of one of those sizes before uploading (see "Framing" in README.md).
# TODO(phase-4): if you want full-screen shots instead, swap `screencapture -l`
# for `screencapture -x` and clean up your desktop first.
#
# First run: macOS will ask to give Terminal "Screen Recording" permission.
# (System Settings → Privacy & Security → Screen Recording.)
# =============================================================================
set -euo pipefail
cd "$(dirname "$0")/.."
# shellcheck disable=SC1091
source ./ship.config

SCHEME="${APP_NAME}Mac"
OUT="store/screenshots"

echo "→ Building $SCHEME"
command -v xcodegen >/dev/null && xcodegen generate --quiet
xcodebuild build -scheme "$SCHEME" -destination "platform=macOS" \
  -derivedDataPath .build/shots-mac CODE_SIGNING_ALLOWED=NO -quiet
APP=$(find .build/shots-mac/Build/Products -maxdepth 2 -name "$APP_NAME.app" | head -1)
[[ -d "$APP" ]] || { echo "✗ built app not found"; exit 1; }

# Tiny Swift helper: print the window ID of the app's frontmost window.
WINID_SWIFT="$(mktemp -d)/winid.swift"
cat > "$WINID_SWIFT" <<'SWIFT'
import CoreGraphics
let owner = CommandLine.arguments[1]
let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
if let w = list.first(where: { ($0[kCGWindowOwnerName as String] as? String) == owner && ($0[kCGWindowLayer as String] as? Int) == 0 }) {
    print(w[kCGWindowNumber as String] as! Int)
}
SWIFT

for loc in $LOCALES; do
  dir="$OUT/$loc/mac"; mkdir -p "$dir"; n=0
  for route in $SCREENSHOT_ROUTES; do
    n=$((n + 1))
    pkill -x "$APP_NAME" 2>/dev/null || true
    # shellcheck disable=SC2046
    open -n "$APP" --args -demo 1 -route "$route" -AppleLanguages "($loc)"
    sleep 3
    wid=$(swift "$WINID_SWIFT" "$APP_NAME")
    [[ -n "$wid" ]] || { echo "✗ no window found for $APP_NAME (menu-bar app? see header)"; exit 1; }
    file="$dir/$(printf '%02d' $n)-$route.png"
    screencapture -o -l "$wid" "$file"
    echo "   ✓ $file"
  done
done
pkill -x "$APP_NAME" 2>/dev/null || true
rm -f "$WINID_SWIFT"
echo "✓ Mac screenshots in $OUT/*/mac/"
