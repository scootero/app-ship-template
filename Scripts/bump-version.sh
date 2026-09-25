#!/usr/bin/env bash
# =============================================================================
# bump-version.sh — change the app version in its ONE place.     [core] PHASE 3
# =============================================================================
# The version lives in project.yml (MARKETING_VERSION). This script edits it,
# adds a CHANGELOG heading, and reminds you to fill in What's New.
#
# Usage:   ./Scripts/bump-version.sh 1.2.0
#          ./Scripts/bump-version.sh patch|minor|major
#
# Then:    commit + push, and press "Cut release" in GitHub Actions
#          (or: git tag v1.2.0 && git push --tags).
# =============================================================================
set -euo pipefail
cd "$(dirname "$0")/.."

current=$(perl -ne 'print $1 if /MARKETING_VERSION:\s*"?([0-9.]+)"?/' project.yml)
[[ -n "$current" ]] || { echo "✗ MARKETING_VERSION not found in project.yml"; exit 1; }

IFS=. read -r MAJ MIN PAT <<<"$current"
case "${1:-}" in
  patch) new="$MAJ.$MIN.$((PAT + 1))" ;;
  minor) new="$MAJ.$((MIN + 1)).0" ;;
  major) new="$((MAJ + 1)).0.0" ;;
  [0-9]*.[0-9]*.[0-9]*) new="$1" ;;
  *) echo "usage: $0 <X.Y.Z|patch|minor|major>   (current: $current)"; exit 1 ;;
esac

perl -pi -e "s/MARKETING_VERSION:\s*\"?[0-9.]+\"?/MARKETING_VERSION: \"$new\"/" project.yml

# Newest entry goes at the top of CHANGELOG.md, under the title line.
if ! grep -q "^## $new" CHANGELOG.md; then
  # Insert above the first existing "## " entry (below the header comment).
  perl -0pi -e "s/^## /## $new — $(date +%Y-%m-%d)\n\n- TODO: what changed\n\n## /m" CHANGELOG.md
fi

echo "✓ $current → $new"
echo "  TODO: update the '## whats_new' section in store/metadata/*.md"
echo "  TODO: fill in CHANGELOG.md, commit, then cut the release."
