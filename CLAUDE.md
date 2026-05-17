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
```

## Repository layout

- `engine-rs/` — Rust crate wrapping `adblock-rust`, with C ABI exposed in `src/ffi.rs`
- `engine-swift/` — Swift package wrapping the C ABI (`ManeEngine` class)
- `scripts/` — `fetch-filterlists.sh` and `build-swift-bridge.sh`
- `filterlists/` — downloaded lists (gitignored, refetch with the script)
- `target/` — Cargo workspace build output (gitignored)
- `mac-app/` — Xcode project (planned phase 3, not yet created)
- `safari-ext/`, `chrome-ext/` — browser extensions (phases 3 and 4)

## Conventions and gotchas

- The Cargo workspace's `target/` lives at the **repo root**, not under each member crate. Linker paths must reflect this (e.g. `Package.swift` uses `-L../target/release` from inside `engine-swift/`).
- Filter lists are gitignored. New filter sources go in `scripts/fetch-filterlists.sh`, not committed wholesale.
- The cbindgen-generated C header (`engine-rs/include/mane_engine.h`) and its vendored copy in the Swift package are both gitignored. The bridge script regenerates them.
- FFI function bodies must be wrapped in `catch_unwind(AssertUnwindSafe(...))`. A Rust panic crossing the C boundary is undefined behaviour; we catch and return a sentinel (null pointer or false).
- Swift imports C opaque struct pointers (`typedef struct Engine Engine;` → `Engine*`) as `OpaquePointer` directly. Don't wrap with `UnsafePointer<Pointee>` — Swift will complain about type mismatches.
- British English in user-facing text and most documentation. Code/API names follow whatever convention is established (snake_case in Rust, camelCase in Swift).
- No em dashes anywhere. No AI-isms (no "comprehensive", "robust", "leverage", "seamlessly", "let's…"). No Claude co-author trailers in commits.

## Current phase

**Phase 2 complete** (Swift FFI bridge with XCTest coverage, pushed to `origin/main` on https://github.com/Abdulla-AlBassam/Mane).

**Next: Phase 3** — Safari Web Extension. Scaffold `mac-app/Mane.xcodeproj` with a Safari Web Extension target. The JS extension uses Brave's `adblock-rs` npm package plus bundled filter lists, registers a `browser.webRequest.onBeforeRequest` blocker. Manual verification on a real ad-heavy site through "Allow Unsigned Extensions" in Safari → Develop.

## Target platform

- macOS 26 (Tahoe) or later — required for Liquid Glass
- Xcode 26 or later
- Rust stable (rustup, `~/.cargo/bin`)
- Node 22 or later (for the browser extensions in phases 3 and 4)

## Distribution

Apple Developer Program membership is available. Signed + notarized builds are the default plan from phase 7, not a "later" concern.
