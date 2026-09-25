#!/bin/sh
# =============================================================================
# ci_post_clone.sh — Xcode Cloud hook.                          [core] PHASE 2
# =============================================================================
# Xcode Cloud (Apple's build service, configured in App Store Connect) looks
# for a folder named EXACTLY `ci_scripts` next to the .xcodeproj and runs
# scripts with these exact names at fixed moments:
#
#   ci_post_clone.sh      right after cloning the repo        ← this file
#   ci_pre_xcodebuild.sh  just before the build                (optional)
#   ci_post_xcodebuild.sh just after the build                 (optional)
#
# Our .xcodeproj isn't in git (XcodeGen makes it), so this script's main job
# is: install XcodeGen → generate the project → Xcode Cloud builds it.
#
# MUST be executable:  chmod +x ci_scripts/*.sh   (bootstrap/git keep the bit)
#
# Useful Xcode Cloud env vars: CI_PRIMARY_REPOSITORY_PATH, CI_BUILD_NUMBER,
# CI_WORKFLOW, CI_TAG, CI_BRANCH, CI_COMMIT.
# Docs: https://developer.apple.com/documentation/xcode/writing-custom-build-scripts
# =============================================================================
set -eu

REPO="${CI_PRIMARY_REPOSITORY_PATH:-$(pwd)}"
cd "$REPO"

# --- Skip docs-only commits (saves your free Xcode Cloud hours) --------------
# If EVERY changed file is docs/store text/screenshots, there's nothing new to
# build. Exiting non-zero is the only way to stop an Xcode Cloud run early,
# so a "failed" run with the banner below is a deliberate skip, not a bug.
#
# Better: ALSO set the workflow's Start Condition → "Files and Folders" in
# App Store Connect to ignore docs/ and store/. This is the backup.
if git rev-parse HEAD~1 >/dev/null 2>&1; then
  CHANGED=$(git diff --name-only HEAD~1 HEAD || true)
  RELEVANT=$(printf '%s\n' "$CHANGED" | grep -vE '^(docs|store)/|\.md$' || true)
  if [ -n "$CHANGED" ] && [ -z "$RELEVANT" ]; then
    echo "=============================================================="
    echo "  BUILD SKIPPED ON PURPOSE — only docs/store files changed:"
    printf '%s\n' "$CHANGED" | sed 's/^/    /'
    echo "=============================================================="
    exit 1
  fi
fi

# --- Generate the Xcode project ----------------------------------------------
echo "→ Installing XcodeGen"
brew install xcodegen

echo "→ Generating Xcode project from project.yml"
xcodegen generate

# --- OPTIONAL: secrets ------------------------------------------------------
# Never commit API keys. Add them in App Store Connect → Xcode Cloud → your
# workflow → Environment → Secret variables, then write them into a file the
# app reads at build time. FitUp example (RevenueCat / Supabase):
#
# cat > Shared/Sources/Secrets.generated.swift <<EOF
# enum Secrets {
#     static let revenueCatKey = "${REVENUECAT_API_KEY}"
#     static let supabaseURL   = "${SUPABASE_URL}"
#     static let supabaseAnon  = "${SUPABASE_ANON_KEY}"
# }
# EOF
# (Shared/Sources/Secrets.generated.swift is already in .gitignore. Keep your
#  own copy locally with your dev keys so Xcode builds on your Mac too.)

echo "✓ Post-clone complete"
