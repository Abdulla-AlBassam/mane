# Mane — Claude Code working notes

Read this first when starting a session in this repo. It captures the conventions, commands, and current phase so you don't have to rediscover them.

## What this is

Native macOS ad blocker wrapping Brave's `adblock-rust`. Liquid Glass SwiftUI dashboard plus bundled Safari and Chrome extensions, all powered by the same engine. See `README.md` for the public pitch.

## Build and test commands

```sh
./scripts/fetch-filterlists.sh                  # fetch EasyList + EasyPrivacy
cargo run --example test_blocker --release      # Rust validation harness (8 cases)
./scripts/build-swift-bridge.sh                 # build Rust lib + vendor C header into engine-swift/
swift test --package-path engine-swift          # XCTest suite for the FFI bridge (6 cases)
./scripts/build-rules.sh                        # compile filter lists into safari-ext/rules.json (declarativeNetRequest)
./scripts/build-wasm-engine.sh                  # (currently unused at runtime) compile engine-wasm/ into safari-ext/engine/
./safari-ext/scripts/sync-filters.sh            # copy filter lists into the Safari bundle (not strictly needed once rules.json exists)
xcodebuild -project mac-app/Mane/Mane.xcodeproj -scheme Mane build
```

## Repository layout

- `engine-rs/` — Rust crate wrapping `adblock-rust`, with C ABI exposed in `src/ffi.rs` (Swift consumer)
- `engine-wasm/` — Rust crate wrapping `adblock-rust` with wasm-bindgen for the browser; built into `safari-ext/engine/`
- `engine-swift/` — Swift package wrapping the C ABI (`ManeEngine` class)
- `scripts/` — `fetch-filterlists.sh`, `build-swift-bridge.sh`, `build-wasm-engine.sh`
- `filterlists/` — downloaded lists (gitignored, refetch with the script)
- `target/` — Cargo workspace build output (gitignored)
- `safari-ext/` — Web extension source (manifest, background, popup); `filters/`, `engine/`, and `rules.json` are gitignored regenerated artefacts
- `chrome-ext/` — Chrome MV3 extension, standalone (storage-driven, no native messaging); `filters/`, `rules.json`, and `_metadata/` are gitignored regenerated artefacts
- `mac-app/Mane/Mane.xcodeproj` — Xcode project with the container app (SwiftUI dashboard) and `Mane Extension` target
- `test-extension*.js`, `test-chrome-functional.js` — Playwright harnesses for the Chrome ext; output lives in gitignored `test-output/`

## Talking to Abdulla about this project

Abdulla is the project owner but isn't deep in the day-to-day jargon of Rust, Swift, web extensions, and WASM. When explaining what's happening or what comes next:

- Skip the jargon, or if a term is unavoidable, explain it in a short clause the first time it appears in a response.
- Elaborate on the pieces that actually matter to the project's success (what something does, why it's needed, what could go wrong) rather than the trivial mechanics.
- "WASM" → "a packaging format that lets compiled Rust code run inside a browser"; "FFI" → "the bridge between two languages"; "crate" → "a Rust package"; "MV3" → "the current version of the browser extension format Chrome and Safari both use". Short asides, not lectures.
- Recommend a path forward with the tradeoff in one sentence, rather than dumping a menu of options.

Do not commit to GitHub or push to `origin`. Local commits only, unless Abdulla explicitly says to push.

## Conventions and gotchas

- The Cargo workspace's `target/` lives at the **repo root**, not under each member crate. Linker paths must reflect this (e.g. `Package.swift` uses `-L../target/release` from inside `engine-swift/`).
- Filter lists are gitignored. New filter sources go in `scripts/fetch-filterlists.sh`, not committed wholesale.
- The cbindgen-generated C header (`engine-rs/include/mane_engine.h`) and its vendored copy in the Swift package are both gitignored. The bridge script regenerates them.
- FFI function bodies must be wrapped in `catch_unwind(AssertUnwindSafe(...))`. A Rust panic crossing the C boundary is undefined behaviour; we catch and return a sentinel (null pointer or false).
- Swift imports C opaque struct pointers (`typedef struct Engine Engine;` → `Engine*`) as `OpaquePointer` directly. Don't wrap with `UnsafePointer<Pointee>` — Swift will complain about type mismatches.
- **Do not use `UserDefaults(suiteName:)` for the dashboard ↔ extension bridge.** macOS CFPreferences rejects the "AnyUser + ByHost + non-system Container" combination that UserDefaults silently uses for App Group suites, so writes look fine but reads return stale data. The bridge uses plain JSON files (`mane-control.json`, `mane-stats.json`) in the App Group container via `FileManager.containerURL(forSecurityApplicationGroupIdentifier:)`.
- App Group identifier is `group.com.albassam.mane`. Both targets carry the `com.apple.security.application-groups` entitlement and the `com.apple.security.app-sandbox` entitlement.
- Apple Developer Program team ID is `K465H4V2A2`. Both targets sign with "Apple Development: Abdulla AlBassam". The local Mac is registered as a development device on the portal; the App Group and both App IDs (`com.albassam.mane`, `com.albassam.mane.Extension`) are registered with the App Groups capability linked.
- British English in user-facing text and most documentation. Code/API names follow whatever convention is established (snake_case in Rust, camelCase in Swift).
- No em dashes anywhere. No AI-isms (no "comprehensive", "robust", "leverage", "seamlessly", "let's…"). No Claude co-author trailers in commits.

## Current phase

**Phase 3 complete on Safari and Chrome.** Both surfaces block ads end-to-end and the dashboard + popups are wired up. Next is Phase 4: tighten the catch rate (specific tracker domains that escape) and start on cosmetic filtering.

Architecture as of `1a4918c`:

- Blocking is dNR-driven on both browsers. `engine-rs/examples/compile_rules.rs` reads `filterlists/`, calls Brave's `FilterSet::into_content_blocking()`, maps each rule to declarativeNetRequest format, writes `safari-ext/rules.json` plus `safari-ext/filterlists-meta.json`. `manifest.json` declares the ruleset. Background scripts don't run the engine at runtime.
- Current ruleset: **122,026 rules** from EasyList + EasyPrivacy + Fanboy's Annoyance + Peter Lowe's list. ~15 MB.
- Safari dashboard ↔ extension bridge: plain JSON files in `~/Library/Group Containers/group.com.albassam.mane/` (see gotcha above). Dashboard polls the control file every 3s for popup-initiated toggles.
- Chrome (`chrome-ext/`): storage-driven, no native messaging. Popup is the only UI surface. Same compiled `rules.json` and `filterlists-meta.json` as Safari.
- Apple Developer Program signing is set up; both targets sandboxed; App Group entitled. "Allow Unsigned Extensions" no longer needed on Safari.

Quick verification:

1. `./scripts/fetch-filterlists.sh && ./scripts/build-rules.sh` (refreshes rules.json + meta).
2. `./safari-ext/scripts/sync-filters.sh && ./chrome-ext/scripts/sync-filters.sh` (copies filter lists into the bundles if needed).
3. Open `mac-app/Mane/Mane.xcodeproj` and ⌘R. The container app launches with the Liquid Glass dashboard.
4. Safari → Settings → Extensions → enable `Mane Extension`.
5. For Chrome: `node test-chrome-functional.js` loads `chrome-ext/` in Playwright Chromium and verifies blocking + toggle end-to-end (assumes `npm install` has run for Playwright).

Known gaps to address next:

- **Catch rate**: api.permutive.com (and `.app`, `cdn.` variants), `cm.g.doubleclick.net`, `stats.g.doubleclick.net`, `www3.doubleclick.net`, `analytics.google.com`, `www.googletagmanager.com` slip through on multiple sites. Need a `filterlists/mane-custom.txt` for the obvious patterns. Per-site allowlists/denylists would help with Forbes-style anti-adblock retry loops.
- **getMatchedRules undercounts**: live Chromium test showed 4–11 matches reported vs 200+ requests actually prevented (diff against baseline). The dashboard's "Today blocked" count uses the same API path, so it likely undercounts on Safari too. Worth confirming and, if true, switching to a different tally mechanism.
- **Cosmetic filtering** (the empty rectangles on sites that lay out around removed banners) is still phase 4. `engine-wasm/` is the planned home for it.
- **No per-site pause** yet. The Safari popup's button was removed because it didn't do anything; needs dynamic dNR rules tracking paused domains.

## Target platform

- macOS 26 (Tahoe) or later — required for Liquid Glass
- Xcode 26 or later
- Rust stable (rustup, `~/.cargo/bin`)
- Node 22 or later (for the browser extensions in phases 3 and 4)

## Distribution

Apple Developer Program membership is available. Signed + notarized builds are the default plan from phase 7, not a "later" concern.

---

## Session: 2026-05-18

### Accomplished
- Verified phase 3c end-to-end on theguardian.com — Safari blocks ads natively via the bundled declarativeNetRequest ruleset. Blocking is real.
- Diagnosed the popup counter showing "0 blocked" while blocking is active.
- Confirmed `cd452df` (phase 3c) is the current tip with a clean tree; no pending commits to make.

### Decisions Made
- Counter fix deferred. The popup relies on `declarativeNetRequest.onRuleMatchedDebug`, which Safari likely doesn't fire, and the background service worker is torn down between requests, so any in-memory tally evaporates regardless. Fixing it properly means moving stats into `chrome.storage.session` (or similar persistent surface) and accepting that Safari may never expose per-rule callbacks. Not worth interrupting the dashboard work for.
- Next-session priority is the SwiftUI Liquid Glass dashboard, not phase 4 (Chrome extension). The container app still shows the converter's default storyboard nag, and the README's pitch hinges on the native dashboard. Network blocking is verified, which was the gate for replacing the nag screen.

### Files Changed
- None — this was a verification and planning session.

### Next Steps
- Replace the container app's converter-default storyboard with the SwiftUI Liquid Glass dashboard. It will need a real stats source, so this work and the counter fix will probably converge.
- Decide later between two routes for stats: persist counts via `chrome.storage.session` from the background worker (browser-side truth), or surface stats from the Rust engine via XPC into the container app (native-side truth). The latter fits the Liquid Glass aesthetic better.
- Phase 4 still on the board: Chrome MV3 extension, cosmetic filtering, element picker.

### Notes/Blockers
- "0 blocked" in the popup is a known follow-up, not a regression. Add it to the existing follow-ups list above the next time the project-overview section is touched.
- Safari accepted the 116,944-rule single ruleset without complaint, so the "may need to chunk" follow-up can be downgraded in priority.
- The compiled `rules.json` is ~15 MB and lives at `safari-ext/rules.json` — gitignored regenerated artefact, rebuilt by `./scripts/build-rules.sh`.

---

## Session: 2026-05-18 (continued)

### Accomplished
- Installed the `rust-analyzer-lsp` Claude Code plugin from the official marketplace. Active on next session start; `rust-analyzer` binary already at `~/.cargo/bin`.
- Locked in the dashboard scope and wrote the full implementation plan to `DASHBOARD_PLAN.md` at the repo root.

### Decisions Made
- Dashboard scope upgraded from "native-only" to "native + live block counts". Triggered by a reference screenshot showing an analytics-style layout (KPI tiles plus charts); empty tiles and empty charts would look broken, so the counter work moves into v1 instead of v2.
- Stats source is the Safari extension via `chrome.storage.local`, surfaced to the container app through `SFSafariExtensionHandler`. The Rust engine still provides rule count and filter list freshness directly via FFI (no IPC for those).
- Project file edits are mine to attempt in code rather than handing UI steps to the user. Faster, with Xcode UI fallback when needed.

### Files Changed
- `CLAUDE.md` — added this entry.
- `DASHBOARD_PLAN.md` — new handover doc with the 7-step plan, visual direction, gotchas, and out-of-scope items.

### Next Steps
- Execute `DASHBOARD_PLAN.md` step 1: strip the converter shell (storyboard, ViewController, Main.html), convert `AppDelegate` to `@main struct ManeApp: App`.
- Investigate whether Safari returns useful results from `chrome.declarativeNetRequest.getMatchedRules()` for static rulesets before building the full Activity card. If it returns empty, the counter design needs a different angle.

### Notes/Blockers
- LSP plugin: confirmed via `claude plugin install rust-analyzer-lsp@claude-plugins-official`. Settings recorded in `~/.claude/plugins/installed_plugins.json`.
- The earlier session's note about deferring the popup counter is now superseded: the counter is part of dashboard v1, not a separate piece of work.

---

## Session: 2026-05-19

### Accomplished
- Shipped DASHBOARD_PLAN.md end-to-end: stripped converter shell, linked `engine-swift`, wired the stats bridge, built the Liquid Glass dashboard, verified live on strikeout.im / theguardian.com / rottentomatoes.com (130+ blocks today, real per-domain data).
- `getMatchedRules()` confirmed working on Safari for static rulesets, the largest unknown in the plan.
- Switched `engine-rs` to static-only linking (`crate-type = ["rlib", "staticlib"]`). `libmane_engine.a` is absorbed into Mane.debug.dylib at link time, binary grew from ~600KB to 6.4MB, `otool -L` shows zero external mane_engine references.
- Engine on/off toggle bridge: dashboard writes `~/Library/Containers/com.albassam.mane.Extension/Data/Documents/mane-control.json`, `background.js` polls via `runtime.sendNativeMessage` on each top-level navigation and applies state via `declarativeNetRequest.updateEnabledRulesets`.
- `compile_rules.rs` now emits `safari-ext/filterlists-meta.json` (rule count, skipped count, compiled-at, list mtimes/sizes); bundled into the Mane app, so the dashboard reads rule count and freshness without instantiating the engine at runtime.
- Logo cream background chroma-keyed out via PIL (target rgb 246/241/238, inner 12 / outer 22 thresholds). AppIcon at 7 sizes plus `LargeIcon` regenerated from the transparent source.
- Dashboard v2 redesign: removed wordmark and "Engine live" badge; added master engine toggle (white→green) next to the logo; refresh button + monospaced "Updated" timer + ellipsis "Engine details" button on the right.
- Today + All time became feature cards. Today: big number + 24-hour bar chart with peak indicator. All time: big number + W/M/Y segmented picker + bar chart. Blocks Over Time card removed (redundant).
- Tracker taxonomy + categorisation (`TrackerTaxonomy.swift`, ~80 known trackers across Google / Meta / X / LinkedIn / Amazon / Microsoft / Adobe + major ad networks + analytics platforms). Categories Ads / Analytics / Social / Fingerprint / CDN / Search / Other with tints. Top Blocked Domains card now groups by parent company with category pills; "View all" sheet has By company / By domain toggle, search, and expandable companies.
- Adopted Liquid Glass APIs: `GlassEffectContainer` wraps the header right-side cluster, `GlassCircleButtonStyle` and `GlassPillButtonStyle` on refresh / ellipsis / close / view-all buttons, cards keep `glassEffect(in: .rect)` with `regularMaterial` fallback.
- Popup "undefined blocked" fixed: service worker returns `{ready:false, blocked:0}` while warming up.

### Decisions Made
- **Container app unsandboxed (`ENABLE_APP_SANDBOX = NO`).** App Groups need a development cert and `security find-identity` shows none installed. Unsandboxed Mane reads the extension's sandbox container directly. Migrate to App Group + `UserDefaults(suiteName:)` once signing is set up.
- **Static linking, not dylib install_name patching.** The engine only runs at build time (the dNR ruleset does the blocking at runtime); no need for dynamic loading. Static archive is simpler than patching install_name plus bundling Frameworks.
- **Group blocked traffic by parent company in the main view, drill into raw domains via the sheet.** "Google: 47 blocks" reads more meaningfully than eight technical hostnames; categories use tinted pills.
- **Modern Safari Web Extensions don't expose `messageReceivedFromContainingApp`.** That's pre-MV3. Replacement is JS-pushes-to-native via `runtime.sendNativeMessage`; the extension polls the native handler for the control state.

### Files Changed
- New: `mac-app/Mane/Mane/TrackerTaxonomy.swift`, `Views/{EngineToggle,HeaderBar,TodayCard,AllTimeCard,DomainsCard,AdvancedSheet,DomainsSheet}.swift`, `Mane.entitlements`, `Mane Extension.entitlements`, `safari-ext/filterlists-meta.json` (generated).
- Rewritten: `AppDelegate.swift` (Cocoa to SwiftUI App), `DashboardModel.swift`, `DashboardView.swift`, `safari-ext/background.js`, `Mane Extension/SafariWebExtensionHandler.swift`.
- Modified: `Card.swift`, `KPITile.swift`, `FilterListsCard.swift`, `engine-rs/Cargo.toml`, `engine-rs/examples/compile_rules.rs`, `safari-ext/manifest.json` (added `webNavigation`, `nativeMessaging`), `DASHBOARD_PLAN.md`.
- Deleted: `Views/{BlocksOverTimeChart,TopDomainsChart}.swift`, all converter shell artefacts (`Main.storyboard`, `ViewController.swift`, `Resources/`).
- Heavy `mac-app/Mane/Mane.xcodeproj/project.pbxproj` surgery across the session.
- Assets: AppIcon variants and `LargeIcon` regenerated from the transparent logo source.

### Next Steps
- **Waiting on Abdulla:** Xcode Settings → Accounts → Apple ID, then set the development team on both Mane and Mane Extension targets. Once done, re-enable App Sandbox, add the `group.com.albassam.mane` entitlement, swap the bridge from the Documents file to `UserDefaults(suiteName:)`. About 30 min of follow-up work.
- Chrome MV3 extension (phase 4). Handoff note to the next agent is being written.
- Optional polish: per-domain trend sparklines, first-seen timestamps, click-through detail on company rows beyond the current sheet.

### Notes/Blockers
- macOS Accessibility permission isn't granted for `osascript`; CLI screenshot tooling can't drive `System Events`. The user's manual screenshots are higher quality anyway.
- An old `libmane_engine.dylib` may still exist under `target/release/deps/` from a pre-static-link build; cargo doesn't auto-remove it on `crate-type` changes. Harmless, `rm` if it bothers you.
- The popup still uses the legacy `stats` message and shows the today total. Could be retired once the dashboard owns all user-facing display.

---

## Session: 2026-05-19 to 2026-05-20

### Accomplished
- **Apple Developer Program signing wired up end-to-end.** Set the team (K465H4V2A2) on both targets, registered the Mac as a development device (UDID 00008112-000E193E3AF8201E), registered the App Group `group.com.albassam.mane` on the portal, registered both App IDs (`com.albassam.mane`, `com.albassam.mane.Extension`) with App Groups capability linked. "Allow Unsigned Extensions" is no longer needed.
- **App Sandbox re-enabled on the container app.** `ENABLE_APP_SANDBOX = YES` on both configs; both targets carry the App Group entitlement.
- **Bridge migrated from `UserDefaults(suiteName:)` to file I/O.** First tried the standard App Group UserDefaults pattern; it hit a macOS CFPreferences container restriction (logged: "Using kCFPreferencesAnyUser with a container is only allowed for System Containers"). Writes appeared to succeed but reads silently returned stale data. Switched to plain JSON files in the App Group container via `FileManager.containerURL(forSecurityApplicationGroupIdentifier:)`. Dashboard polls `mane-control.json` every 3s for popup-initiated toggles.
- **Native Liquid Glass dashboard toggle.** Replaced the custom white→green Circle with SwiftUI `Toggle(...).toggleStyle(.switch).tint(.green)`. Picks up Liquid Glass automatically on macOS 26.
- **Safari and Chrome popups both have a working blocking toggle now.** Symmetric UI; Safari routes through `SafariWebExtensionHandler` (new `setControl` message → writes control file), Chrome uses `chrome.storage.local` directly.
- **Chrome MV3 port (`chrome-ext/`)** as a standalone build. Storage-driven, no native messaging, same compiled `rules.json`. Loads cleanly in Chromium 148, verified end-to-end via Playwright (`test-chrome-functional.js`): popup toggle round-trips correctly, ~77% of ad-domain requests blocked on theguardian.com (177 → 40 over a baseline-vs-extension diff).
- **Two new filter lists** added to the compile pipeline: Fanboy's Annoyance and Peter Lowe's list. Total ruleset grew from 116,944 → **122,026 dNR rules**, ~15 MB.
- Autonomous Playwright test report (`TEST_REPORT.md`): documented per-site blocking effectiveness, escaping domains (api.permutive.com et al, doubleclick subdomain inconsistencies), Forbes anti-adblock anomaly (request count goes UP with extension on), and the getMatchedRules undercounting bug.

### Decisions Made
- **File I/O over UserDefaults for the bridge.** Triggered by the CFPreferences error. The plist exists at `~/Library/Group Containers/group.com.albassam.mane/Library/Preferences/...` but UserDefaults fails to bind to it cleanly from the sandboxed container app. Plain JSON files sidestep the issue entirely.
- **Native Toggle over custom Circle for the dashboard switch.** User explicitly preferred the macOS-native control: cleaner Liquid Glass adoption, consistent with system settings UI, less code to maintain.
- **Diverge `safari-ext/` and `chrome-ext/` rather than unify.** Different platforms have different capabilities (Safari has dashboard, Chrome doesn't) so the popups and background scripts have intentionally different control flows. Worth revisiting if maintenance burden grows.
- **Removed the disabled "Pause on this site" popup button.** It was misleading. Per-site pause needs proper implementation (dynamic dNR rules) and is on the phase 4 list.

### Files Changed
- New: `chrome-ext/` (manifest, background.js, popup/, scripts/sync-filters.sh, filterlists-meta.json), `TEST_REPORT.md`, `CHROME_HANDOFF.md`, `package.json`, `package-lock.json`, `test-extension.js`, `test-extension-v2.js`, `test-chrome-functional.js`.
- Modified: `safari-ext/background.js` (added `setEnabled` handler), `safari-ext/popup/popup.html` + `.js` (added working toggle), `mac-app/Mane/Mane Extension/SafariWebExtensionHandler.swift` (added `setControl` case + `writeControl` helper), `mac-app/Mane/Mane/DashboardModel.swift` (bridge migrated to file I/O, added `controlPollTask` for reverse sync), `mac-app/Mane/Mane/Views/EngineToggle.swift` (custom Circle → native `Toggle(.switch)`), `mac-app/Mane/Mane/Mane.entitlements` (added app-sandbox + App Group), `mac-app/Mane/Mane Extension/Mane Extension.entitlements` (added App Group), `mac-app/Mane/Mane.xcodeproj/project.pbxproj` (ENABLE_APP_SANDBOX = YES), `scripts/fetch-filterlists.sh`, `engine-rs/examples/compile_rules.rs`, `.gitignore`, `~/.claude/CLAUDE.md` (Personal facts section recording paid Developer Program membership + team ID).
- Pushed to `origin/main` as commit `1a4918c`.

### Next Steps
- **Phase 4 catch rate.** Build `filterlists/mane-custom.txt` with the specific patterns we know slip through: `||permutive.com^`, `||permutive.app^`, `||cm.g.doubleclick.net^`, `||stats.g.doubleclick.net^`, `||www3.doubleclick.net^`, `||googletagmanager.com^`. Hook into `scripts/fetch-filterlists.sh` and the compiler's `lists` array. Rerun the Playwright test to confirm the gaps close.
- **Investigate getMatchedRules undercounting.** Live Chromium test showed only 4–11 matches reported via `getMatchedRules({})` while the request diff showed 200+ requests prevented. The Safari dashboard's "Today blocked" count uses the same API surface and likely undercounts. Need to verify on Safari, and if confirmed, switch to a `webNavigation`-derived domain-by-domain estimate or persist counts via the dNR `onRuleMatchedDebug` (unreliable but consistent in dev builds).
- **Forbes anti-adblock investigation.** Request count went UP from 184 (no extension) to 294 (with extension), suggesting a retry/fallback loop. Open in Safari with Web Inspector, see what's firing. May need a per-site allowlist for certain analytics if their content gates on it.
- **Per-site pause + element picker + cosmetic filtering** are still on the long-term list, all rely on `engine-wasm/` coming back online for cosmetic rules.

### Notes/Blockers
- The Chrome ext's `getMatchedRules` API requires `declarativeNetRequestFeedback` permission and only returns matches for tabs the extension can currently see, with the per-call result capped well below the real count. Anything more accurate needs a different tally path.
- Playwright Chromium runs windowed (`headless: false`) when an extension is loaded; the test script is fine to run but pops a browser window. Headless mode doesn't support extensions in stock Chromium yet.
- The dashboard's `print("[Mane] toggle -> …")` log line is intentional debug output, useful when verifying the bridge. Can be removed once we're confident the bridge is solid for a few sessions.
