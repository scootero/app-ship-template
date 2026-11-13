<!--
=============================================================================
store/metadata/en-US.md — your App Store listing, as a file.   [core] PHASE 3
=============================================================================
WHY: the listing lives in git, so AI can draft and revise it, you get history,
and Scripts/asc-submit.mjs pushes it to App Store Connect on every release.
One file per language: en-US.md, de-DE.md, ... (file name = App Store locale).

FORMAT: each "## key" starts a field. Keep the keys exactly as written.
Everything inside these comment blocks is ignored by the script.

WHO READS WHAT: Scripts/asc-submit.mjs pushes EVERY field below to App Store
Connect (on a release, or with --metadata-only). Fields still starting with
"TODO" are skipped, so half-finished text never reaches Apple.
  name, subtitle, privacy_url  → "App Information" (shared by all versions)
  everything else              → this version's page
It also feeds the website (Scripts/build-site.mjs).

LIMITS (Apple rejects anything longer):
  name 30 (must be unique on the App Store) · subtitle 30 · promotional_text 170 · keywords 100 (comma-separated,
  no spaces needed) · description 4000 · whats_new 4000
=============================================================================
-->

## name
__DISPLAY_NAME__

## subtitle
<!-- ≤30 chars. The second most important search field after name. -->
TODO: your one-line promise

## promotional_text
<!-- Can change ANY time without a new app version. Good for "New: ..." -->
TODO: One or two sentences about what's new or what's great right now.

## keywords
<!-- ≤100 chars total, comma-separated, no spaces needed. Don't repeat words already in the name/subtitle. -->
TODO: keyword,list

## description
TODO: First 2–3 lines matter most — they show before "more".

What you get:
• Feature one — the benefit, not the mechanism
• Feature two
• Feature three

## support_url
https://__GITHUB_USER__.github.io/__APP_NAME__/

## marketing_url
https://__GITHUB_USER__.github.io/__APP_NAME__/

## privacy_url
<!-- REQUIRED by Apple. docs/privacy.html, published by pages.yml. -->
https://__GITHUB_USER__.github.io/__APP_NAME__/privacy.html

## copyright
<!-- Shown on the store page, e.g. "2026 Scott Oliver". Not per-language: read from the first locale. -->
TODO: 2026 Your Name

## whats_new
<!-- Update this every release (bump-version.sh reminds you). Skipped automatically on the app's first version. -->
• First release.
