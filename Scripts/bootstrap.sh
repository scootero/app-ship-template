#!/usr/bin/env bash
# =============================================================================
# bootstrap.sh — turn the template into YOUR app. Run once.     [core] PHASE 1
# =============================================================================
# What it does:
#   1. Reads ship.config.
#   2. Replaces every __PLACEHOLDER__ in the repo with your values.
#   3. Removes the platform you're not building (iOS or Mac folders, targets,
#      schemes) based on PLATFORMS.
#   4. Creates a store/metadata/<locale>.md for each locale.
#   5. Runs `xcodegen generate` if XcodeGen is installed.
#
# Usage:   ./Scripts/bootstrap.sh            (from the repo root)
#          ./Scripts/bootstrap.sh --dry-run  (show what would change)
#
# Safe to read, not safe to run twice: after it runs, the placeholders are
# gone. It writes .bootstrapped as a marker and refuses to run again.
#
# Uses perl for find/replace because macOS `sed -i` and Linux `sed -i` take
# different arguments; perl behaves the same on both.
# =============================================================================
set -euo pipefail
cd "$(dirname "$0")/.."

DRY_RUN=0
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=1

if [[ -f .bootstrapped ]]; then
  echo "✗ Already bootstrapped (delete .bootstrapped to force — placeholders are already replaced)."
  exit 1
fi

# shellcheck disable=SC1091
source ./ship.config

# --- 1. Validate -------------------------------------------------------------
fail() { echo "✗ ship.config: $1" >&2; exit 1; }
[[ "$APP_NAME" =~ ^[A-Za-z][A-Za-z0-9]*$ ]] || fail "APP_NAME must be letters/numbers, no spaces (got '$APP_NAME')"
[[ "$APP_NAME" != "MyApp" ]]               || fail "APP_NAME is still the default 'MyApp'"
[[ "$BUNDLE_ID_PREFIX" != "com.example" ]]  || fail "BUNDLE_ID_PREFIX is still 'com.example'"
[[ "$TEAM_ID" =~ ^[A-Z0-9]{10}$ ]]          || fail "TEAM_ID must be 10 uppercase letters/numbers"
[[ "$TEAM_ID" != "ABCDE12345" ]]            || fail "TEAM_ID is still the placeholder"
[[ "$PLATFORMS" =~ ^(ios|mac|ios,mac|mac,ios)$ ]] || fail "PLATFORMS must be ios, mac, or ios,mac"

has_platform() { [[ ",$PLATFORMS," == *",$1,"* ]]; }

echo "→ Bootstrapping $DISPLAY_NAME ($BUNDLE_ID_PREFIX.$APP_NAME) for: $PLATFORMS"
[[ $DRY_RUN == 1 ]] && echo "  (dry run — nothing will be written)"

# --- 2. Replace placeholders -------------------------------------------------
# Files that DOCUMENT the placeholders keep them.
SKIP_REGEX='^\./(\.git/|Scripts/bootstrap\.sh$|README\.md$|SETUP\.md$)'

# Exported so perl can read them from %ENV (avoids quoting problems).
export APP_NAME DISPLAY_NAME BUNDLE_ID_PREFIX TEAM_ID GITHUB_USER IOS_MIN MACOS_MIN

files=$(grep -rlI --exclude-dir=.git '__[A-Z_]*__' . | grep -Ev "$SKIP_REGEX" || true)
for f in $files; do
  echo "  replace  $f"
  [[ $DRY_RUN == 1 ]] && continue
  perl -pi -e '
    s/__APP_NAME__/$ENV{APP_NAME}/g;
    s/__DISPLAY_NAME__/$ENV{DISPLAY_NAME}/g;
    s/__BUNDLE_ID_PREFIX__/$ENV{BUNDLE_ID_PREFIX}/g;
    s/__TEAM_ID__/$ENV{TEAM_ID}/g;
    s/__GITHUB_USER__/$ENV{GITHUB_USER}/g;
    s/__IOS_MIN__/$ENV{IOS_MIN}/g;
    s/__MACOS_MIN__/$ENV{MACOS_MIN}/g;
  ' "$f"
done

# --- 3. Remove the platform you're not building --------------------------------
# Deletes lines between "# >>> <platform>" and "# <<< <platform>" in project.yml.
strip_block() {
  local platform="$1"
  echo "  remove   $platform targets/schemes from project.yml"
  [[ $DRY_RUN == 1 ]] && return
  perl -0pi -e "s/^# >>> $platform\n.*?^# <<< $platform\n//gms" project.yml
}
remove_path() {
  echo "  delete   $1"
  [[ $DRY_RUN == 1 ]] || rm -rf "$1"
}

if ! has_platform ios; then
  strip_block ios
  remove_path iOS
  remove_path Tools/capture-ios-screenshots.sh
fi
if ! has_platform mac; then
  strip_block mac
  remove_path Mac
  remove_path Tools/capture-mac-screenshots.sh
  remove_path Scripts/build-dmg.sh
  remove_path .github/workflows/release-mac.yml
  remove_path Casks
fi
# Remaining markers are just comments now; strip them for tidiness.
[[ $DRY_RUN == 1 ]] || perl -ni -e 'print unless /^# (>>>|<<<) (ios|mac)$/' project.yml

# --- 4. Store metadata per locale --------------------------------------------
for loc in $LOCALES; do
  target="store/metadata/$loc.md"
  if [[ ! -f "$target" ]]; then
    echo "  create   $target (copied from en-US.md — translate it)"
    [[ $DRY_RUN == 1 ]] || cp store/metadata/en-US.md "$target"
  fi
done

[[ $DRY_RUN == 1 ]] && { echo "✓ Dry run complete."; exit 0; }
date > .bootstrapped

# --- 5. Generate the Xcode project -------------------------------------------
if command -v xcodegen >/dev/null; then
  xcodegen generate
  echo "✓ Done. Open $APP_NAME.xcodeproj"
else
  echo "✓ Placeholders replaced. Now: brew install xcodegen && xcodegen generate"
fi
echo "  Next: work through SETUP.md, then commit."
