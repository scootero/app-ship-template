<!--
=============================================================================
store/metadata/en-US.md — your App Store listing, as a file.   [core] PHASE 3
=============================================================================
WHY: the listing lives in git, so AI can draft and revise it, you get history,
and Scripts/asc-submit.mjs pushes it to App Store Connect on every release.
One file per language: en-US.md, de-DE.md, ... (file name = App Store locale).

FORMAT: each "## key" starts a field. Keep the keys exactly as written.
Everything inside these comment blocks is ignored by the script.

WHO READS WHAT:
  name, subtitle   → NOT pushed by the script (they live on "App Info" and
                     rarely change). Set them once by hand in App Store Connect.
                     Kept here so the whole listing is in one place.
  everything else  → pushed by asc-submit.mjs (release or --metadata-only).

LIMITS (Apple rejects anything longer):
  name 30 · subtitle 30 · promotional_text 170 · keywords 100 (comma-separated,
  no spaces needed) · description 4000 · whats_new 4000
=============================================================================
-->

## name
__DISPLAY_NAME__

## subtitle
<!-- TODO(phase-3): ≤30 chars. The second most important search field after name. -->
Your one-line promise here

## promotional_text
<!-- Can change ANY time without a new app version. Good for "New: ..." -->
TODO: One or two sentences about what's new or what's great right now.

## keywords
<!-- ≤100 chars total, comma-separated. Don't repeat words already in the name/subtitle. -->
todo,keyword,list

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

## whats_new
<!-- Update this every release (bump-version.sh reminds you). Ignored on 1.0. -->
• First release.
