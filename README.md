# Mane

A native macOS ad blocker. Wraps Brave's `adblock-rust` engine in a Liquid Glass dashboard, with bundled extensions for Safari and Chrome.

VERY MUCH IN-PROD, TREAD CAREFULLY.
## Why this exists

Existing Mac adblockers split into two camps. Browser extensions like uBlock Origin block ads well but run only inside the browser, with no system view. Native Mac apps like 1Blocker or AdGuard Mini are constrained by Apple's Content Blocker API (50,000 rule cap, no DOM access, no scriptlet injection) and can't beat extensions on sites that actively detect ad blockers.

Mane combines both: extensions for Safari and Chrome running the same Brave engine that powers the Brave browser, plus a native macOS dashboard that owns the rule sets, the analytics, and the configuration. One engine, three surfaces.

## Architecture

```
┌─────────────────────────────────────────┐
│       macOS Dashboard (SwiftUI)         │
│       Liquid Glass, analytics,          │
│       settings, filter management       │
└──────────────┬──────────────────────────┘
               │  native messaging
       ┌───────┴───────┐
       │               │
┌──────▼─────┐   ┌─────▼──────┐
│ Safari Web │   │   Chrome   │
│ Extension  │   │  Extension │
│ (bundled)  │   │   (MV3)    │
└──────┬─────┘   └─────┬──────┘
       │               │
       └───────┬───────┘
               │
        ┌──────▼──────┐
        │  adblock-   │  shared engine
        │    rust     │  Swift via FFI · extensions via WASM
        └─────────────┘
```

## Requirements

- macOS 26 (Tahoe) or later
- Xcode 26 or later
- Rust toolchain (`rustup`)
- Node 22 or later (for the browser extensions)

## Status

Alpha. Phase 1 (Rust engine validated against EasyList + EasyPrivacy), phase 2 (Swift FFI bridge with XCTest coverage), and phase 3 (Safari Web Extension with the engine compiled to WASM) are code-complete. The extension is built, the engine is bundled, and first-run verification in Safari is the next manual step. The Chrome extension and the SwiftUI dashboard are not yet built.

## Build & validate

```sh
# fetch the filter lists (cached locally, not committed)
./scripts/fetch-filterlists.sh

# Rust engine — 8 cases through adblock-rust directly
cargo run --example test_blocker --release

# Swift FFI bridge — same engine called from Swift via the C ABI
./scripts/build-swift-bridge.sh
swift test --package-path engine-swift
```

Both runs cover the same shape of cases: known ad and tracker URLs (Google Tag Manager, DoubleClick, Google Analytics, Scorecard) get blocked, and known content URLs (BBC assets, GitHub, Wikipedia) pass through.

## Repository layout

```
Mane/
├── Cargo.toml                  workspace root
├── engine-rs/                  Rust engine wrapper
│   ├── Cargo.toml
│   ├── build.rs                runs cbindgen to emit the C header
│   ├── cbindgen.toml
│   ├── src/lib.rs
│   ├── src/ffi.rs              C ABI for native consumers (Swift, etc.)
│   └── examples/test_blocker.rs
├── engine-swift/               Swift package wrapping the C ABI
│   ├── Package.swift
│   ├── Sources/CManeEngine/    module map + generated C header
│   ├── Sources/ManeEngine/     Swift wrapper class
│   └── Tests/ManeEngineTests/
├── engine-wasm/                Rust crate, compiled to WASM for the browser
│   ├── Cargo.toml
│   └── src/lib.rs              wasm-bindgen wrapper around adblock-rust
├── scripts/
│   ├── fetch-filterlists.sh
│   ├── build-swift-bridge.sh   builds the Rust lib, vendors the header
│   └── build-wasm-engine.sh    runs wasm-pack, drops output in safari-ext/engine/
├── filterlists/                downloaded lists, not committed
├── safari-ext/                 web extension source (MV3)
│   ├── manifest.json
│   ├── background.js           service worker, request listener, real engine
│   ├── popup/                  toolbar popup
│   ├── engine/                 compiled WASM + JS glue, not committed
│   ├── filters/                synced from filterlists/, not committed
│   └── scripts/sync-filters.sh
└── mac-app/Mane/               Xcode project
    ├── Mane.xcodeproj
    ├── Mane/                   container app target
    └── Mane Extension/         Safari Web Extension target
```

The Chrome extension (phase 4) will live in `chrome-ext/`. The SwiftUI dashboard replaces the placeholder container app inside `mac-app/Mane/Mane/` in a later phase.

## Licensing

Mane is MIT-licensed. See [LICENSE](LICENSE).

The bundled engine, [`adblock-rust`](https://github.com/brave/adblock-rust), is MPL-2.0 (Mozilla Public License 2.0) and remains under its original licence. Filter lists ([EasyList](https://easylist.to), EasyPrivacy) are dual-licensed by their maintainers under GPL-3.0 and CC-BY-SA 3.0.
