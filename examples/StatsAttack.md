# Worked example — StatsAttack (a Mac menu bar system monitor)

This is `PLAYBOOK.md` followed for a real app: **StatsAttack**, a better version of [Blip](https://github.com/blaineam/Blip). Use it as a model for the next app, or hand it to an AI agent together with `PLAYBOOK.md`.

**Status:** stages 0 and A are done. B (building the menu bar UI) is next.

---

## The decisions (stage A, step 1)

| Setting | Value | Why |
| --- | --- | --- |
| `APP_NAME` | `StatsAttack` | Code-safe, no spaces |
| `DISPLAY_NAME` | `StatsAttack` | Same as the code name |
| `PLATFORMS` | `mac` | Menu bar apps are Mac-only |
| `BUNDLE_ID_PREFIX` | `com.scottoliver` | → bundle ID `com.scottoliver.StatsAttack` (permanent once the app exists in App Store Connect) |
| `TEAM_ID` | blank for now | Fine for running on this Mac. Set before TestFlight (stage C3). |
| `GITHUB_USER` | `scootero` | Website + repo links |
| `LOCALES` | `en-US` | One language to start |
| `SCREENSHOT_ROUTES` | `overview cpu memory network` | The screens that sell a system monitor |

## What was run (stage A)

```bash
cd ~/Documents
git clone ~/Documents/app-ship-template StatsAttack     # or "Use this template" on GitHub, then clone
cd StatsAttack
# edited ship.config with the values above
./Scripts/bootstrap.sh
#   ! TEAM_ID is blank: fine for the simulator/this Mac...
#   → Bootstrapping StatsAttack (com.scottoliver.StatsAttack) for: mac
#   delete iOS, Tools/capture-ios-screenshots.sh
#   ✓ docs/index.html built
```

Then `AppRoute` in `Shared/Sources/LaunchOptions.swift` was changed to match the screenshot routes:

```swift
public enum AppRoute: String, CaseIterable, Sendable {
    case overview
    case cpu
    case memory
    case network
}
```

A first draft of the store listing went into `store/metadata/en-US.md`: subtitle "Mac stats in your menu bar", keywords, a description of CPU / memory / disk / network / battery, the `scootero.github.io/StatsAttack` URLs, and copyright "2026 Scott Oliver". It's marked as a draft to update once the app is built.

To publish, if not done yet (**[HUMAN]**, needs your GitHub login):
```bash
# GitHub: create an EMPTY repo named StatsAttack (no README), then:
cd ~/Documents/StatsAttack
git remote add origin https://github.com/scootero/StatsAttack.git
git push -u origin main
```

---

## Next: stage B — build it

**Decide first: App Store or direct download?** The Mac App Store requires the sandbox, which blocks fan speeds, temperatures, SMC sensors and per-process detail for other apps. Blip handles this with a separate unsandboxed helper app. For StatsAttack:

| Option | You get | You give up |
| --- | --- | --- |
| **Direct download (recommended first)** | Everything: fans, temps, top processes | App Store discovery; uses the DMG + Homebrew path (`build-dmg.sh`, `release-mac.yml`) |
| App Store | Store listing, reviews, updates via the store | Sandbox-blocked stats, unless a helper app is added later |

Both can ship from this one repo later.

**Build order** (one AI prompt each, push after each):

1. **Menu bar shell.** In `Mac/Sources/MacApp.swift`, switch to `MenuBarExtra(... ) { ... }.menuBarExtraStyle(.window)`. In `project.yml`, set `INFOPLIST_KEY_LSUIElement: YES`. The menu bar shows a compact CPU/MEM readout; clicking opens the dropdown.
2. **Metrics engine** in `Shared/Sources/` (testable): CPU (host_processor_info), memory (host_statistics64, memory pressure), disk (volume capacity + I/O rates), network (interface byte counters → rates), battery (IOKit power sources). Poll every 2 s with async/await. Unit tests for the rate math.
3. **Dropdown UI:** sections for overview, CPU, memory, network, each a view reachable via `AppRoute`.
4. **Demo data** in `DemoData.swift`: fixed, realistic numbers for every section, so `-demo 1 -route cpu` renders a full, good-looking CPU panel.
5. **Settings:** refresh interval, which metrics show in the menu bar, launch at login.

**Prompt to hand an AI for step 1:**
> Follow `AGENTS.md`. Turn StatsAttack into a menu bar app: use `MenuBarExtra` with `.window` style in `Mac/Sources/MacApp.swift`, set `INFOPLIST_KEY_LSUIElement: YES` in `project.yml`, show "CPU 12% · MEM 48%" style text in the bar from `DemoData` for now, and a dropdown with Overview / CPU / Memory / Network sections driven by `AppRoute` (respect `-route`). Run `xcodegen generate`, build the `StatsAttackMac` scheme, run tests, commit.

---

## Stages C → E for this app, with its real values

- **C. TestFlight:**
  - developer.apple.com: register the App ID `com.scottoliver.StatsAttack`.
  - App Store Connect: New App → **macOS**, name "StatsAttack" (if taken, e.g. "StatsAttack – Mac Stats").
  - Set `DEVELOPMENT_TEAM` in `project.yml`.
  - Xcode Cloud workflow: Archive → **macOS** → TestFlight.
- **D. Listing:**
  - Update the drafted `store/metadata/en-US.md` to match what shipped.
  - Privacy page: "StatsAttack reads system statistics locally; nothing leaves your Mac."
  - Turn on Pages.
  - Icon: `swift Scripts/generate-icon.swift S`.
  - Screenshots: `./Tools/capture-mac-screenshots.sh`, then place each on a 2880×1800 canvas. A menu bar dropdown isn't a normal window, so a full-screen capture may work better (see that script's header).
- **E. First upload:**
  ```bash
  node Scripts/asc-submit.mjs --version 1.0.0 --platform MAC_OS --dry-run
  ```
  Then Actions → **Cut release** with Submit **off**. In App Store Connect, finish App Privacy ("Data Not Collected" if that's true), age rating, category (Utilities or Developer Tools), pricing, screenshots, and review contact. Then submit.
- **Direct-download path instead of, or as well as, the store:**
  - Create a Developer ID certificate and add the `DEVELOPER_ID_P12` secrets.
  - Cut release → `release-mac.yml` publishes a notarized DMG.
  - Set `DOWNLOAD_URL` in `ship.config` so the website shows "Download for Mac".
