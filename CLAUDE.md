# Mane — Claude Code working notes

Read this first when starting a session in this repo. Captures conventions, commands, and current state so you don't have to rediscover them.

## What this is

Native macOS ad blocker wrapping Brave's `adblock-rust`. SwiftUI Liquid Glass dashboard plus bundled Safari and Chrome extensions, all driven by a shared declarativeNetRequest ruleset. See `README.md` for the public pitch.

## Build and test commands

```sh
./scripts/fetch-filterlists.sh                  # EasyList + EasyPrivacy + Fanboy's Annoyance + Peter Lowe's list
./scripts/build-rules.sh                        # compile filter lists -> safari-ext/rules.json + filterlists-meta.json
cargo run --example test_blocker --release      # Rust validation harness (8 cases)
./scripts/build-swift-bridge.sh                 # build Rust lib + vendor C header into engine-swift/
swift test --package-path engine-swift          # XCTest suite for the FFI bridge
./safari-ext/scripts/sync-filters.sh            # copy filter lists into the Safari bundle (only needed before WASM phase 4)
./chrome-ext/scripts/sync-filters.sh            # same for the Chrome bundle
node test-chrome-functional.js                  # Playwright end-to-end test of the Chrome ext (requires `npm install`)
xcodebuild -project mac-app/Mane/Mane.xcodeproj -scheme Mane -allowProvisioningUpdates build
```

## Repository layout

- `engine-rs/` — Rust crate wrapping `adblock-rust`, with C ABI in `src/ffi.rs`
- `engine-wasm/` — Rust crate with `wasm-bindgen`, currently unused at runtime; returns for cosmetic filtering in phase 4
- `engine-swift/` — Swift package wrapping the C ABI (`ManeEngine` class)
- `safari-ext/` — Safari Web Extension source; `filters/`, `engine/`, `rules.json` are gitignored regenerated artefacts
- `chrome-ext/` — Chrome MV3 standalone (storage-driven, no native messaging); `filters/`, `rules.json`, `_metadata/` are gitignored
- `mac-app/Mane/Mane.xcodeproj` — Xcode project: container app (SwiftUI dashboard) and `Mane Extension` target
- `scripts/` — `fetch-filterlists.sh`, `build-rules.sh`, `build-swift-bridge.sh`, `build-wasm-engine.sh`
- `test-extension*.js`, `test-chrome-functional.js` — Playwright harnesses; output in gitignored `test-output/`

## Conventions and gotchas

- The Cargo workspace's `target/` lives at the **repo root**, not under each member crate. Linker paths must reflect this (e.g. `Package.swift` uses `-L../target/release` from inside `engine-swift/`).
- Filter lists are gitignored. New sources go in `scripts/fetch-filterlists.sh` and the `lists` array in `engine-rs/examples/compile_rules.rs`, not committed wholesale.
- The cbindgen-generated C header (`engine-rs/include/mane_engine.h`) and its vendored copy in the Swift package are both gitignored; the bridge script regenerates them.
- FFI function bodies must be wrapped in `catch_unwind(AssertUnwindSafe(...))`. A Rust panic crossing the C boundary is undefined behaviour; we catch and return a sentinel (null pointer or false).
- Swift imports C opaque struct pointers (`typedef struct Engine Engine;` → `Engine*`) as `OpaquePointer` directly. Don't wrap with `UnsafePointer<Pointee>` — Swift will complain about type mismatches.
- **Do not use `UserDefaults(suiteName:)` for the dashboard ↔ extension bridge.** macOS CFPreferences rejects the "AnyUser + ByHost + non-system Container" combination that UserDefaults silently uses for App Group suites, so writes look fine but reads return stale data. The bridge uses plain JSON files (`mane-control.json`, `mane-stats.json`) in the App Group container via `FileManager.containerURL(forSecurityApplicationGroupIdentifier:)`.
- App Group identifier: `group.com.albassam.mane`. Apple Developer Program team: `K465H4V2A2`. Both targets are sandboxed, both carry the App Group entitlement, the local Mac is registered as a development device on the portal, and both App IDs and the App Group are registered with the App Groups capability linked.
- British English in user-facing text and most documentation. Code/API names follow the language's convention (snake_case in Rust, camelCase in Swift).
- No em dashes anywhere. No AI-isms ("comprehensive", "robust", "leverage", "seamlessly", "let's…"). No Claude co-author trailers in commits.

## Current state

Phase 3 complete on Safari and Chrome. Both surfaces block ads end-to-end and the dashboard plus popups are wired up. Phase 4 is closing catch-rate gaps and starting cosmetic filtering.

- Blocking is dNR-driven on both browsers. `engine-rs/examples/compile_rules.rs` reads `filterlists/`, calls Brave's `FilterSet::into_content_blocking()`, maps each rule to declarativeNetRequest format, writes `safari-ext/rules.json` plus `safari-ext/filterlists-meta.json`. Background scripts don't run the engine at runtime.
- Ruleset: **122,026 rules** from EasyList + EasyPrivacy + Fanboy's Annoyance + Peter Lowe's list, ~15 MB.
- Safari dashboard ↔ extension bridge: plain JSON files in `~/Library/Group Containers/group.com.albassam.mane/`. Dashboard polls the control file every 3s for popup-initiated toggles.
- Chrome (`chrome-ext/`): storage-driven, no native messaging. Popup is the only UI surface.
- Apple Developer Program signing is set up. "Allow Unsigned Extensions" is no longer required.

## What's next (Phase 4)

- **Catch rate**: a handful of trackers slip through the four-list set. Build `filterlists/mane-custom.txt` with `||permutive.com^`, `||permutive.app^`, `||cm.g.doubleclick.net^`, `||stats.g.doubleclick.net^`, `||www3.doubleclick.net^`, `||googletagmanager.com^`. Per-site allow/deny rules for Forbes-style anti-adblock retry loops.
- **`getMatchedRules` undercounts**: live Chromium test showed 4–11 matches reported via `getMatchedRules({})` while the request diff showed 200+ requests prevented. The dashboard's "Today blocked" count uses the same API surface and likely undercounts on Safari too. Need to verify and switch to a `webNavigation`-derived tally or `onRuleMatchedDebug` in dev builds.
- **Cosmetic filtering**, **element picker**, **per-site pause**: all phase 4. Cosmetic rules need `engine-wasm/` back online.

## Target platform

- macOS 26 (Tahoe) or later (required for Liquid Glass)
- Xcode 26 or later
- Rust stable (`rustup`)
- Node 22+ for the Chrome extension and Playwright testing

## Distribution

Apple Developer Program signing is in place (team `K465H4V2A2`). Signed and notarized builds are the default plan from phase 7, not a "later" concern.
