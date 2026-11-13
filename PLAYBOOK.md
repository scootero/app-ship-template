# PLAYBOOK — idea → Xcode → TestFlight → App Store (ready to submit)

This is the one document to follow, start to finish. It is written so that a person **or an AI coding agent** (Codex, Claude Code, Cursor) can follow it without guessing.

> **Worked example:** [`examples/StatsAttack.md`](examples/StatsAttack.md) is the same steps with real values for a Mac menu bar app.
> **Reference:** `README.md` (how the pieces fit), `SETUP.md` (click-by-click Apple/GitHub screens), `AGENTS.md` (coding rules inside an app repo).

---

## How to read this

Every step is tagged with who does it:

| Tag | Meaning |
| --- | --- |
| **[HUMAN]** | Needs your Apple/GitHub login, a payment, a legal answer, or a judgment call. An AI must **stop and ask** here. |
| **[AI]** | An AI agent (or you) can do it in the terminal / editor. |
| **[AUTO]** | Happens by itself (GitHub Actions, Xcode Cloud). Nothing to do but wait and check. |

Each stage ends with a **✅ Done when** check. Don't move on until it passes.

**Where things live**

| Thing | Location |
| --- | --- |
| The template (this repo, never edited per app) | `github.com/<you>/app-ship-template`, on your Mac at `~/Documents/app-ship-template` |
| Each app | Its own repo made from the template, e.g. `~/Documents/StatsAttack` |
| Apple side | App Store Connect (appstoreconnect.apple.com), developer.apple.com |
| Secrets | GitHub repo secrets + Xcode Cloud environment variables. **Never in git.** |

---

## The whole flow on one screen

```
 A. Create repo      template → new repo → fill ship.config → bootstrap.sh → push
 B. Build            open in Xcode, build with AI, push often  ──► CI tests every push   [AUTO]
 C. TestFlight       one-time Xcode Cloud setup                ──► every push → TestFlight [AUTO]
 D. Listing          store text, privacy page, website, icon, screenshots (all files in the repo)
 E. First upload     API key → dry run → "Cut release" (Submit OFF)
                     ──► version created, ALL text filled, build attached, STOPS           [AUTO]
                     you: questionnaires + screenshots in App Store Connect → Submit       [HUMAN]
 F. Updates          bump version → push → Cut release (Submit on or off, your choice)
```

---

## 0. One-time setup (per Mac and account, not per app)

- [ ] **[HUMAN]** Apple Developer Program membership is active.
- [ ] **[HUMAN]** Find your **Team ID**: developer.apple.com → Account → Membership details. Write it down.
- [ ] **[AI]** Install tools on the Mac:
  ```bash
  xcode-select -p || xcode-select --install     # Xcode itself comes from the Mac App Store
  brew install xcodegen node                     # node 18+ runs the pipeline scripts
  ```
- [ ] **[HUMAN]** In the template repo on GitHub: **Settings → tick "Template repository"** (once).

✅ **Done when:** `xcodegen --version` and `node --version` both print a version, and the template repo shows a green **Use this template** button.

---

## A. Create the app repo (≈15 min)

1. **[HUMAN]** Decide the basics. An AI should ask for these, not invent them:
   - **App name**: letters and numbers only, no spaces (becomes code names). Example: `StatsAttack`
   - **Display name**: what users see. Can have spaces.
   - **Platforms**: `ios`, `mac`, or `ios,mac`
   - **Bundle ID prefix**: reverse domain you own, e.g. `com.scottoliver`. The bundle ID becomes `<prefix>.<AppName>` and is **permanent** once the app exists in App Store Connect.
2. **[HUMAN]** GitHub → template repo → **Use this template** → name it after the app → Create. (Public = free CI minutes and free website.)
3. **[AI]** Clone it and fill `ship.config`:
   ```bash
   cd ~/Documents && git clone https://github.com/<you>/<AppName>.git && cd <AppName>
   # edit ship.config: APP_NAME, DISPLAY_NAME, BUNDLE_ID_PREFIX, TEAM_ID (may be blank for now),
   #   GITHUB_USER, PLATFORMS, LOCALES, SCREENSHOT_ROUTES
   ./Scripts/bootstrap.sh --dry-run    # read the output
   ./Scripts/bootstrap.sh              # replaces placeholders, removes the unused platform, builds the website
   xcodegen generate
   git add -A && git commit -m "Bootstrap <AppName> from app-ship-template" && git push
   ```
4. **[AUTO]** GitHub Actions runs **CI**.

✅ **Done when:** `grep -rn "__APP_NAME__" --exclude-dir=.git . | grep -v -E "README|SETUP|PLAYBOOK|bootstrap"` prints nothing, the `.xcodeproj` opens and runs the placeholder app, and CI is green on GitHub.

---

## B. Build the app in Xcode with AI (days → weeks)

**Open it:** `xcodegen generate && open *.xcodeproj`. Pick the scheme (`<AppName>` for iOS, `<AppName>Mac` for Mac) and press **Run**.

**Working with an AI agent:** open the app folder in Codex / Claude Code / Cursor. It reads `AGENTS.md` automatically. Give it one feature at a time and push after each one.

**Rules the AI must follow** (the full list is in `AGENTS.md`):

1. Never edit the `.xcodeproj`. Change `project.yml`, then run `xcodegen generate`. New `.swift` files inside existing source folders need no YAML change.
2. Packages, capabilities, entitlements, permissions text → `project.yml` only.
3. Logic in `Shared/Sources` with tests in `Tests/`. UI in `iOS/Sources` or `Mac/Sources`.
4. **Keep the two hooks working** (`Shared/Sources/LaunchOptions.swift`):
   - `-demo 1` fills every screen with realistic fake data (`DemoData.swift`), no network/login/permissions.
   - `-route <name>` opens that screen directly. Every screen worth a screenshot gets a case in `AppRoute` **and** a name in `SCREENSHOT_ROUTES` in `ship.config`.
5. Secrets (API keys) never go in git. See `ci_scripts/ci_post_clone.sh` for the pattern.
6. Build + test before every commit:
   ```bash
   xcodegen generate
   xcodebuild test -scheme <AppName>Mac -destination 'platform=macOS'                       # Mac
   xcodebuild test -scheme <AppName> -destination 'platform=iOS Simulator,name=iPhone 16'   # iOS
   ```

**Platform notes**

- *Mac menu bar app*: in `Mac/Sources/MacApp.swift` switch `WindowGroup` to the `MenuBarExtra` block, and set `INFOPLIST_KEY_LSUIElement: YES` in `project.yml` (no Dock icon).
- *Mac App Store = sandboxed*: no fan speeds, temperatures, SMC or other apps' process details. Decide early: **App Store** (sandbox limits) or **direct download** (DMG, no limits, `release-mac.yml`).
- *iOS permissions*: every permission prompt needs a usage string (`INFOPLIST_KEY_NS…UsageDescription` in `project.yml`) or Apple rejects the build.

✅ **Done when:** the app does what you want, tests pass locally and in CI, and launching with `-demo 1 -route <each route>` shows a good-looking screen for every route.

---

## C. Every push → TestFlight (≈30 min, once per app)

1. **[HUMAN]** developer.apple.com → Identifiers → **+** → App ID with the exact bundle ID `<prefix>.<AppName>`.
2. **[HUMAN]** App Store Connect → Apps → **+ New App**: platform(s), name (must be unique on the store), bundle ID from step 1, SKU = app name.
3. **[AI]** Set the team: `DEVELOPMENT_TEAM: "<TEAMID>"` in `project.yml` (and `TEAM_ID` in `ship.config`). Commit + push.
4. **[HUMAN]** In Xcode: **Integrate → Create Workflow** (Xcode Cloud). Grant GitHub access when asked.
   - Start condition: branch `main`. Exclude `docs/`, `store/`, `*.md`.
   - Action: **Archive** → your platform → Distribution: **TestFlight (Internal Testing Only)**.
   - Post-action: add yourself as an internal tester.
5. **[HUMAN]** If the app uses API keys: Xcode Cloud workflow → Environment → secret variables, and uncomment the `Secrets.generated.swift` block in `ci_scripts/ci_post_clone.sh` **[AI]**.
6. **[AI]** Push any commit.

✅ **Done when:** 15–30 min after a push, the build appears in TestFlight (App Store Connect → TestFlight, and the TestFlight app on your device for iOS).

*If Xcode Cloud fails at "post-clone":* `git ls-files -s ci_scripts` must show `100755`. Fix: `git add --chmod=+x ci_scripts/*.sh`, commit, push.

---

## D. Prepare the listing (≈1–2 h, mostly writing)

All of this is files in the repo, so an AI can draft it and you edit.

| Step | Who | File / command | Notes |
| --- | --- | --- | --- |
| Store text | **[AI]** drafts, **[HUMAN]** approves | `store/metadata/en-US.md` | Fields: name, subtitle, promotional_text, keywords, description, support_url, marketing_url, privacy_url, copyright, whats_new. Limits are at the top of the file. Lines still starting with `TODO` are **not** sent to Apple. |
| Privacy policy | **[AI]** drafts, **[HUMAN]** confirms it's true | `docs/privacy.html` | Must match what the app really collects **and** your App Privacy answers in step E. |
| Website | **[AI]** | `ship.config` → `SUPPORT_EMAIL`; then `node Scripts/build-site.mjs && open docs/index.html` | Built from the store text. Design lives in `docs/site-template.html`. |
| Turn on website | **[HUMAN]** | GitHub repo → Settings → Pages → Source: **GitHub Actions** | Publishes to `https://<you>.github.io/<AppName>/`. This gives Apple the **support** and **privacy** URLs. |
| Icon | **[AI]** | `swift Scripts/generate-icon.swift` (edit colors at the top) | Or drop in a designed 1024×1024 PNG. |
| Screenshots | **[AI]** on the Mac | iOS: `./Tools/capture-ios-screenshots.sh` · Mac: `./Tools/capture-mac-screenshots.sh` | Output: `store/screenshots/<locale>/<device>/`. Mac window shots need placing on a 1280×800 / 1440×900 / 2560×1600 / 2880×1800 canvas before upload. |

✅ **Done when:** `grep -n "TODO" store/metadata/en-US.md docs/privacy.html` shows nothing you care about, the website URL loads in a browser, and the screenshots look right.

---

## E. First push to App Store Connect — fill everything, DON'T submit

The pipeline creates the version, fills every text field, attaches the TestFlight build, and **stops**. You then answer Apple's questionnaires and press Submit yourself.

### E1. API key (once per Apple account; reuse for every app)

1. **[HUMAN]** App Store Connect → Users and Access → **Integrations** → App Store Connect API → Team Keys → **+**. Name `CI`, access **App Manager**. Download the `.p8` (**only downloadable once**) to `~/.appstoreconnect/private_keys/`. Note the **Key ID** and **Issuer ID**.
2. **[HUMAN]** In the **app's** GitHub repo → Settings → Secrets and variables → Actions → add:
   - `ASC_API_KEY_ID` · `ASC_API_ISSUER_ID` · `ASC_API_KEY_P8` (the whole file text, BEGIN/END lines included)

### E2. Dry run from the Mac (changes nothing)

**[AI]**
```bash
export ASC_API_KEY_ID=<id> ASC_API_ISSUER_ID=<issuer> \
       ASC_API_KEY_PATH=~/.appstoreconnect/private_keys/AuthKey_<id>.p8
node Scripts/asc-submit.mjs --version <X.Y.Z from project.yml> --platform MAC_OS --dry-run   # or IOS
```
Read the output: it should find the app, find (or wait for) the build, and list every field it *would* write.

### E3. The real first run

1. **[AI]** Make sure the version in `project.yml` (`MARKETING_VERSION`) is what you want to ship (e.g. `1.0.0`) and that Xcode Cloud already put a build with that version in TestFlight. If not: `./Scripts/bump-version.sh 1.0.0`, commit, push, wait for TestFlight.
2. **[HUMAN]** GitHub → Actions → **Cut release** → Run workflow → leave **Submit OFF** (the default).
3. **[AUTO]** It tags `v1.0.0`, then `apple-store.yml` runs `asc-submit.mjs`, which:
   - finds the app and waits for the build to finish processing
   - creates the App Store version `1.0.0`
   - fills **App Information**: name, subtitle, privacy policy URL
   - fills **the version**: description, keywords, promotional text, support + marketing URLs, copyright (What's New is skipped on a first version, as Apple requires)
   - attaches the build
   - **stops**. Nothing is sent for review.

### E4. What only you can do in App Store Connect (then submit)

**[HUMAN]** Open the app in App Store Connect and complete:

- [ ] **App Privacy**: the data-collection questionnaire (must match `docs/privacy.html`)
- [ ] **Age rating** questionnaire
- [ ] **Category** (primary / secondary) and **Content rights**
- [ ] **Pricing and Availability**
- [ ] **Screenshots**: drag in from `store/screenshots/…` for each required size
- [ ] **App Review Information**: contact name/phone/email; a demo account if the app has a login; notes for the reviewer
- [ ] Check the filled text and attached build look right
- [ ] **Add for Review** → **Submit**

✅ **Done when:** the version status reads *Waiting for Review*.

After approval: paste the App Store link into `APP_STORE_URL` in `ship.config` and push. The website button switches from "Coming soon" to "Download on the App Store".

---

## F. Every update after that

**[AI]**
```bash
./Scripts/bump-version.sh minor          # 1.0.0 → 1.1.0 (edits project.yml + CHANGELOG.md)
# write "## whats_new" in store/metadata/*.md and the CHANGELOG entry
git commit -am "Release 1.1.0" && git push     # → CI + TestFlight build
```
**[HUMAN]** Test the TestFlight build, then Actions → **Cut release** (Submit ON to go straight to review, or OFF to review first).

Text-only fixes between releases (typo, promotional text): edit `store/metadata/*.md` and push. `store-metadata.yml` syncs it to the version being prepared.

---

## Troubleshooting

| Symptom | Cause → fix |
| --- | --- |
| CI red right after creating the repo | Placeholders still there → run `./Scripts/bootstrap.sh`. |
| Xcode says a file/setting vanished | Someone edited the project in Xcode's UI → put it in `project.yml`, `xcodegen generate`. |
| Xcode Cloud fails at post-clone | `ci_scripts/*.sh` not executable → `git add --chmod=+x ci_scripts/*.sh`. |
| Xcode Cloud can't resolve packages | Commit `Package.resolved` → uncomment the exception block in `.gitignore`. |
| `asc-submit`: 401 | Wrong Key ID / Issuer ID / key text, or key lacks App Manager access. |
| `asc-submit`: "No App Store Connect app with bundle ID" | Bundle ID in `ship.config` ≠ the app record, or the app record doesn't exist yet (step C2). |
| `asc-submit`: timed out waiting for build | No TestFlight build with that exact version → check Xcode Cloud, or bump the version and push. |
| `asc-submit`: "Version X is already READY_FOR_SALE" | That version shipped → `./Scripts/bump-version.sh patch`. |
| Tag vs version mismatch error | Tag `vX.Y.Z` must equal `MARKETING_VERSION` in `project.yml`. |
| Name rejected | Store names are unique across the App Store → change `## name`. |
| Website 404 | Pages source not set to **GitHub Actions**, or `pages.yml` hasn't run yet (Actions tab). |

---

## Copy-paste prompts for an AI agent

**Start a new app** (run in the template folder or an empty folder):
> Read `PLAYBOOK.md` in app-ship-template. Do stage A for a new app. Ask me for: app name, display name, platforms, bundle ID prefix, GitHub username. Do every [AI] step, stop at each [HUMAN] step and tell me exactly what to click. Finish with the stage A "Done when" check.

**Build a feature** (run in the app repo):
> Follow `AGENTS.md`. Add <feature>. Keep the `-demo` and `-route` hooks working, add demo data and a route if it's a new screen, add tests for any logic in `Shared/`, run `xcodegen generate` and the tests, then commit.

**Prepare the listing:**
> Do `PLAYBOOK.md` stage D. Draft `store/metadata/en-US.md` and `docs/privacy.html` from what the app actually does (read the code). Respect the character limits. Build the site and capture screenshots. Show me the drafts before committing.

**First App Store upload:**
> Do `PLAYBOOK.md` stage E up to E3. Run the dry run first and show me its output. Do not use `--submit`. Then give me the E4 checklist for my app.

**Pre-release check:**
> Before I cut a release: confirm `MARKETING_VERSION` matches the latest TestFlight build, there are no `TODO`s in `store/metadata/*.md`, `whats_new` is written, the CHANGELOG entry exists, and CI is green.
