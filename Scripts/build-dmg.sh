#!/usr/bin/env bash
# =============================================================================
# build-dmg.sh — Mac app as a downloadable .dmg (outside the App Store).  [mac] PHASE 5
# =============================================================================
# ONLY needed if you distribute the Mac app yourself (website, GitHub Releases,
# Homebrew). App Store builds come from Xcode Cloud instead. Delete otherwise.
#
# Steps: build Release → sign with Developer ID → make DMG → notarize (Apple
# scans it) → staple (attach Apple's approval so it opens offline).
#
# Usage:
#   ./Scripts/build-dmg.sh                  # full: sign + notarize
#   ./Scripts/build-dmg.sh --skip-notarize  # quick local test DMG
#
# Needs (for signing + notarizing):
#   - "Developer ID Application" certificate in your keychain
#     (developer.apple.com → Certificates → + → Developer ID Application)
#   - A notarytool profile, created once:
#       xcrun notarytool store-credentials notary \
#         --key ~/.appstoreconnect/private_keys/AuthKey_XXXX.p8 --key-id XXXX --issuer <uuid>
#
# Output: dist/<APP_NAME>.dmg
# =============================================================================
set -euo pipefail
cd "$(dirname "$0")/.."
# shellcheck disable=SC1091
source ./ship.config

SKIP_NOTARIZE=0; [[ "${1:-}" == "--skip-notarize" ]] && SKIP_NOTARIZE=1
NOTARY_PROFILE="${NOTARY_PROFILE:-notary}"
SCHEME="${APP_NAME}Mac"
DERIVED=".build/dmg"
mkdir -p dist

command -v xcodegen >/dev/null && xcodegen generate --quiet

echo "→ Building $SCHEME (Release)"
SIGN_ARGS=(CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="Developer ID Application" DEVELOPMENT_TEAM="$TEAM_ID" OTHER_CODE_SIGN_FLAGS=--timestamp)
[[ $SKIP_NOTARIZE == 1 ]] && SIGN_ARGS=(CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO)
xcodebuild build -scheme "$SCHEME" -configuration Release -destination "platform=macOS" \
  -derivedDataPath "$DERIVED" "${SIGN_ARGS[@]}" -quiet
APP="$DERIVED/Build/Products/Release/$APP_NAME.app"

echo "→ Creating DMG"
STAGE=$(mktemp -d)
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"      # the "drag here" shortcut
DMG="dist/$APP_NAME.dmg"
rm -f "$DMG"
hdiutil create -volname "$DISPLAY_NAME" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
# OPTIONAL: pretty DMG window with background art → `brew install create-dmg`
# and use it here instead of hdiutil (Blip draws its background in Swift).

if [[ $SKIP_NOTARIZE == 0 ]]; then
  echo "→ Notarizing (usually 1–10 min)"
  xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$DMG"
fi
echo "✓ $DMG"
