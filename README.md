# App Ship Template

A starter repo for iOS and/or Mac apps that takes you from **code → TestFlight → App Store** with as little clicking as possible. The structure is adapted from [Blip](https://github.com/blaineam/Blip) (MIT), without the app-specific parts and the private tools it relies on.

> **You don't need all of this on day one.** It's built in phases. Phase 1 + 2 alone (project-as-code + push-to-TestFlight) is most of the value. Every other phase is optional and marked.

---

## How it works

```
 you edit code ──► git push main ──┬──► GitHub Actions  ci.yml        tests pass? ✓/✗
                                   └──► Xcode Cloud     post-clone    build ──► TestFlight 📱

 "Cut release" button ──► tag v1.2.0 ──┬──► apple-store.yml ──► asc-submit.mjs ──► App Review ──► App Store
                                       └──► release-mac.yml ──► notarized DMG on GitHub   [mac, optional]

 on your Mac, when you want:  Tools/capture-*-screenshots.sh ──► store/screenshots/ ──► upload
                              edit store/metadata/*.md ──► pushed to App Store Connect on release

 push to docs/ ──► GitHub Pages website (support + privacy URLs)
```

| Loop | Trigger | Runs on | Result |
| --- | --- | --- | --- |
| Develop | you edit | your Mac | `xcodegen generate`, build, run |
| Push | push to `main` | GitHub + Xcode Cloud | tests, TestFlight build |
| Release | Cut release button | GitHub → Apple API | store version created + submitted |
| Marketing | you run a script | your Mac | screenshots, listing text |
| Website | push to `docs/` | GitHub Pages | landing, support, privacy pages |

---

## Quick start

```bash
# 1. Make your repo from this template (GitHub: "Use this template"), clone it.
# 2. Fill in the ONE config file:
open ship.config                 # app name, bundle ID, team ID, platforms
# 3. Stamp your values into every file + remove the platform you don't build:
./Scripts/bootstrap.sh --dry-run # preview
./Scripts/bootstrap.sh
# 4. Open it:
brew install xcodegen            # once per Mac
xcodegen generate && open *.xcodeproj
```

Then follow **[SETUP.md](SETUP.md)** for the one-time Apple / GitHub clicks.

---

## Phases: turn on what you need

| Phase | What you get | Files | Worth it when |
| --- | --- | --- | --- |
| **1. Foundation** [core] | Project as YAML, no `.xcodeproj` conflicts; demo + route hooks; tests | `ship.config`, `project.yml`, `Shared/`, `iOS/`, `Mac/`, `Tests/`, `Scripts/bootstrap.sh` | Always |
| **2. Push → TestFlight** [core] | Every push lands on your phone | `ci_scripts/ci_post_clone.sh`, `.github/workflows/ci.yml` + Xcode Cloud setup | Always |
| **3. Tag → App Store** | One button submits for review with What's New in every language | `store/metadata/`, `Scripts/asc-submit.mjs`, `Scripts/bump-version.sh`, `cut-release.yml`, `apple-store.yml`, `store-metadata.yml`, `docs/privacy.html` | Once you're releasing regularly |
| **4. Marketing assets** | Screenshots for every device/language in one command; icon from code | `Tools/capture-*-screenshots.sh`, `Scripts/generate-icon.swift`, `Shared/Sources/DemoData.swift` | When you have screens worth showing / languages > 1 |
| **5. Extras** | Website, Mac DMG + Homebrew, coverage gate | `docs/`, `Scripts/build-dmg.sh`, `release-mac.yml`, `Casks/`, `Scripts/coverage-check.sh` | When you need them |

**Not using a phase?** Delete its files. Nothing in an earlier phase depends on a later one.

---

## File map

```
ship.config                  [core] the ONLY app-specific values
project.yml                  [core] XcodeGen spec (your Xcode project, as text)
AGENTS.md                    [core] rules for AI agents (merge into your own template)
Shared/Sources/              [core] shared code + LaunchOptions (HOOKs) + DemoData
iOS/  Mac/                   [ios]/[mac] app targets
Tests/                       [core] unit tests, run by ci.yml
ci_scripts/ci_post_clone.sh  [core] Xcode Cloud: install XcodeGen, generate project
.github/workflows/
  ci.yml                     [core] test on push/PR
  cut-release.yml            [ph3]  "Ship it" button → tag → starts the two below
  apple-store.yml            [ph3]  tag → asc-submit.mjs → App Review
  store-metadata.yml         [ph3]  store text edits → App Store Connect
  release-mac.yml            [mac]  tag → notarized DMG → GitHub Release
Scripts/                     things CI or you run
  bootstrap.sh               run once: fill placeholders, strip unused platform
  bump-version.sh            change version (project.yml + CHANGELOG)
  asc-submit.mjs             App Store Connect API: build → version → text → submit
  generate-icon.swift        icon from code (optional)
  coverage-check.sh          fail if test coverage drops (optional)
  build-dmg.sh               Mac DMG, signed + notarized (optional)
Tools/                       things only you run, on a Mac with simulators
  capture-ios-screenshots.sh
  capture-mac-screenshots.sh
store/metadata/<locale>.md   App Store listing text per language
store/screenshots/           captured PNGs
docs/                        website: index.html, privacy.html (GitHub Pages)
Casks/app.rb                 Homebrew (Mac DMG apps only)
```

---

## Markers

Every file starts with a header that says what the file does, why it exists, its tag (`[core]` `[ios]` `[mac]` `[opt]`) and its phase. Inside the files:

| Marker | Meaning |
| --- | --- |
| `TODO(setup)` | Fill in before the first build |
| `TODO(phase-N)` | Fill in when you turn on phase N |
| `OPTIONAL` | Delete if you don't need it |
| `HOOK:` | Code the automation depends on, so keep it |
| `__APP_NAME__` etc. | Placeholder that `bootstrap.sh` replaces |

```bash
grep -rn "TODO(setup)" --exclude-dir=.git .     # what's left before first build
grep -rn "TODO(phase-3)" --exclude-dir=.git .   # what phase 3 needs
```

Placeholders: `__APP_NAME__`, `__DISPLAY_NAME__`, `__BUNDLE_ID_PREFIX__`, `__TEAM_ID__`, `__GITHUB_USER__`, `__IOS_MIN__`, `__MACOS_MIN__`.

---

## Daily use

```bash
git pull && xcodegen generate     # after pulling someone's project.yml change
# ...code...
git push                          # → tests + TestFlight build (~15–30 min)

# Releasing:
./Scripts/bump-version.sh minor   # 1.1.0 → 1.2.0
#   edit store/metadata/*.md  "## whats_new"  +  CHANGELOG.md
git commit -am "Release 1.2.0" && git push     # wait for TestFlight build, test it
# GitHub → Actions → "Cut release" → Run workflow
```

---

## Framing screenshots (phase 4, your choice)

The capture scripts produce **raw** screenshots at Apple's exact sizes. Raw is fine to upload. For frames and captions, pick one of these:

- **fastlane frameit** (`brew install fastlane`, then `fastlane frameit` in the folder): adds device frames and captions from a config file.
- A design tool (Figma, Canva, etc.) with a screenshot template.
- Later: a small script that composites captions. Blip uses a private tool for this, so there's nothing to copy.

## Later (not included)

These pieces of Blip's setup depended on private tools, so they aren't included here. Add them when you need them:

- **Screenshot upload by API.** For now, drag the PNGs into App Store Connect by hand, or use fastlane `deliver`.
- **Name/subtitle sync.** These live on "App Info" and rarely change, so set them by hand.
- **Localized website** (`docs/i18n/*.json`) and **portfolio auto-sync**.
- **Unsandboxed helper app** for system-level Mac features. Only needed for tools like Blip.

---

## Credits

Pipeline ideas from [blaineam/Blip](https://github.com/blaineam/Blip) (MIT). All scripts here were rewritten generically for this template. `LICENSE` covers the template itself. Replace it with your own license, or remove it, for closed-source apps.
