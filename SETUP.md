# SETUP.md — one-time clicks

The parts that can't live in the repo. Do each section when you turn on its phase.

---

## Phase 1 — Foundation (≈15 min)

- [ ] Apple Developer Program membership active
- [ ] Find your **Team ID**: developer.apple.com → Account → Membership details → put it in `ship.config`
- [ ] Fill every `TODO(setup)` in `ship.config`
- [ ] `brew install xcodegen`
- [ ] `./Scripts/bootstrap.sh --dry-run`, check it, then `./Scripts/bootstrap.sh`
- [ ] `open *.xcodeproj`, then pick a simulator and press Run
- [ ] Try the hooks: Scheme → Edit Scheme → Run → Arguments → add `-demo 1` and `-route detail`
- [ ] Push to a new GitHub repo

## Phase 2 — Push → TestFlight (≈30 min)

**Create the app record**

- [ ] App Store Connect → Apps → **+** → New App
  - Platforms: whatever you build (tick both for a universal iOS + Mac purchase)
  - Bundle ID: must equal `BUNDLE_ID_PREFIX.APP_NAME` from `ship.config`. Register it first under developer.apple.com → Identifiers if it's not listed.
  - SKU: anything unique, for example the app name

**Connect Xcode Cloud** (done from Xcode on your Mac)

- [ ] `xcodegen generate`, then open the project in Xcode
- [ ] Xcode → Integrate menu (or the Report navigator's Cloud tab) → **Create Workflow**
- [ ] Grant Xcode Cloud access to your GitHub repo when it asks
- [ ] Workflow settings:
  - **Start condition:** Branch changes → `main`. Also exclude files and folders `docs/`, `store/` and `*.md` so text edits don't cost build hours.
  - **Action:** Archive → iOS (and/or macOS) → Distribution: **TestFlight (Internal Testing only)**
  - **Post-action:** TestFlight Internal Testing → add yourself
- [ ] Push a commit. In 15–30 min the build shows up in the TestFlight app on your phone.
- [ ] If the build fails at "post-clone": check that `ci_scripts/ci_post_clone.sh` is executable (`git ls-files -s ci_scripts` should show `100755`). Fix with `chmod +x ci_scripts/*.sh && git add --chmod=+x ci_scripts/*.sh`.

**Secrets (if the app has API keys, like RevenueCat or Supabase)**

- [ ] Xcode Cloud workflow → Environment → add each key as a **secret** variable
- [ ] Uncomment the `Secrets.generated.swift` block in `ci_scripts/ci_post_clone.sh`
- [ ] Keep a local `Shared/Sources/Secrets.generated.swift` with your dev keys (it's gitignored)

**Swift packages?** Once you add any, Xcode Cloud needs `Package.resolved` committed. Uncomment the exception block in `.gitignore`.

## Phase 3 — Tag → App Store (≈20 min)

**App Store Connect API key**

- [ ] App Store Connect → Users and Access → **Integrations** → App Store Connect API → Team Keys → **+**
  - Name: `CI`, Access: **App Manager**
  - Download the `.p8` file. **You can only download it once.** Save it to `~/.appstoreconnect/private_keys/`
  - Copy the **Key ID** and the **Issuer ID** (shown above the list)
- [ ] GitHub repo → Settings → Secrets and variables → Actions → New repository secret:
  - `ASC_API_KEY_ID` = the Key ID
  - `ASC_API_ISSUER_ID` = the Issuer ID
  - `ASC_API_KEY_P8` = the full text of the `.p8` file, including the `-----BEGIN PRIVATE KEY-----` lines

**First release** (App Store Connect needs some things filled in by hand once)

- [ ] App Information: name, subtitle, category, age rating, content rights
- [ ] App Privacy: the data questionnaire, plus the Privacy Policy URL (`docs/privacy.html` once Pages is on)
- [ ] Pricing and Availability
- [ ] Screenshots uploaded for each required device size
- [ ] App Review Information: contact details, and a demo account if the app has login
- [ ] Test the script without changing anything:
  ```bash
  export ASC_API_KEY_ID=… ASC_API_ISSUER_ID=… ASC_API_KEY_PATH=~/.appstoreconnect/private_keys/AuthKey_….p8
  node Scripts/asc-submit.mjs --version 0.1.0 --platform IOS --dry-run
  ```
- [ ] First real run: Actions → Cut release → untick **Submit**. Check the result in App Store Connect, then submit by hand. Once that works, leave Submit ticked from then on.

## Phase 4 — Marketing (≈20 min)

- [ ] Replace `AppRoute` cases + `SCREENSHOT_ROUTES` with your real screens
- [ ] Make `DemoData` tell a story on each screen
- [ ] `./Tools/capture-ios-screenshots.sh`. If a device type isn't found, run `xcrun simctl list devicetypes` and update `DEVICES` at the top of the script.
- [ ] Optional: `swift Scripts/generate-icon.swift`

## Phase 5 — Extras

- [ ] **Website:** repo Settings → Pages → Deploy from branch → `main` / `/docs`
- [ ] **Coverage gate:** raise `MIN_COVERAGE` in `Scripts/coverage-check.sh`, uncomment the step in `ci.yml`
- [ ] **Mac DMG** (outside the App Store only):
  - Create a Developer ID Application certificate
  - Export it as `.p12` → secrets `DEVELOPER_ID_P12` (base64) and `DEVELOPER_ID_P12_PASSWORD`
- [ ] **Homebrew:** see the header of `Casks/app.rb`

## App Groups / widgets (when you add a widget)

A widget sharing data with the app needs an **App Group** (`group.<bundle id>`):

- [ ] developer.apple.com → Identifiers → App Groups → **+**
- [ ] Enable it on both the app and the widget identifiers
- [ ] Add it to both targets' entitlements in `project.yml`

Automatic signing in Xcode usually handles the profiles from there. Blip needed a script (`mint-dev-profiles.mjs`) only because its Mac had no Xcode account signed in.
