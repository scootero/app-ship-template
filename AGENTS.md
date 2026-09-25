# AGENTS.md — rules for AI coding agents in this repo

<!--
Read automatically by Codex, Cursor, Claude Code and friends.
MERGE NOTE: if you use your own AI project template (AGENTS.md, PROJECT_CONSTITUTION,
docs/ source-of-truth files), paste the "Ship pipeline rules" section below into
that AGENTS.md instead of keeping two copies.
-->

## Ship pipeline rules

1. **Never edit the `.xcodeproj`.** It's generated. Change `project.yml`, then run `xcodegen generate`. New `.swift` files in an existing `sources` folder need no YAML change.
2. **Never add packages, targets, capabilities or build settings through Xcode's UI.** They disappear on the next generate. Put them in `project.yml`.
3. **The version lives in one place:** `MARKETING_VERSION` in `project.yml`. Change it only with `./Scripts/bump-version.sh`.
4. **Keep the automation hooks working** (`Shared/Sources/LaunchOptions.swift`):
   - `-demo 1` must show a full, realistic screen using `DemoData`, with no network, login or HealthKit.
   - `-route <name>` must open that screen. When you add a screen worth a screenshot, add it to `AppRoute` and to `SCREENSHOT_ROUTES` in `ship.config`.
   - Under tests (`LaunchOptions.isRunningTests`), skip real startup.
5. **Tests stay hermetic**: no network, no real accounts, no dates from the clock. Put logic in `Shared/` so it's testable.
6. **Secrets never go in git.** Use Xcode Cloud secret env vars → `Secrets.generated.swift` (see `ci_scripts/ci_post_clone.sh`).
7. **Store text is code**: edit `store/metadata/<locale>.md`, respect the character limits at the top of the file.
8. **Where things go**

   | Kind of change | Location |
   | --- | --- |
   | Logic shared by iOS + Mac | `Shared/Sources/` |
   | iOS-only UI | `iOS/Sources/` |
   | Mac-only UI | `Mac/Sources/` |
   | Tests | `Tests/` |
   | Build/release scripts | `Scripts/` (CI + you) · `Tools/` (you, on a Mac) |
   | App Store listing | `store/metadata/` |
   | Website | `docs/` |

## Markers used in this repo

- `TODO(setup)` — fill in before the first build.
- `TODO(phase-N)` — fill in when you turn on phase N (see README).
- `OPTIONAL` — delete if you don't need it.
- `[core] / [ios] / [mac] / [opt]` — in file headers: who needs this file.
- `HOOK:` — code the automation depends on; don't remove.

Find all open items: `grep -rn "TODO(" --exclude-dir=.git .`
