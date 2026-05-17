# Mane

A native macOS ad blocker. Wraps Brave's `adblock-rust` engine in a Liquid Glass dashboard, with bundled extensions for Safari and Chrome.

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

Alpha, foundation only. Phase 1 (the Rust engine validated against EasyList) is the current scope. The Mac app, Safari extension, and Chrome extension are not built yet.

## Build & validate

```sh
# fetch the filter lists (cached locally, not committed)
./scripts/fetch-filterlists.sh

# build the engine and run the validation harness
cargo run --example test_blocker --release
```

A successful run prints PASS for known ad URLs (Google Tag Manager, DoubleClick, Google Analytics, Scorecard) and PASS for known content URLs (BBC assets, GitHub, Wikipedia) being allowed through.

## Repository layout

```
Mane/
├── Cargo.toml           workspace root
├── engine-rs/           Rust engine wrapper
│   ├── src/lib.rs
│   └── examples/test_blocker.rs
├── scripts/
│   └── fetch-filterlists.sh
└── filterlists/         downloaded lists, not committed
```

Future packages (added in later phases): `engine-swift/` for the FFI bridge, `mac-app/` for the SwiftUI dashboard, `safari-ext/` and `chrome-ext/` for the browser extensions.

## Licensing

Mane is MIT-licensed. See [LICENSE](LICENSE).

The bundled engine, [`adblock-rust`](https://github.com/brave/adblock-rust), is MPL-2.0 (Mozilla Public License 2.0) and remains under its original licence. Filter lists ([EasyList](https://easylist.to), EasyPrivacy) are dual-licensed by their maintainers under GPL-3.0 and CC-BY-SA 3.0.
