#!/usr/bin/env bash
# Build the Rust static library (with its cbindgen-generated header)
# and copy the header into the Swift package so swift build/test can link.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "[1/2] cargo build --release -p mane-engine"
(
    cd "$ROOT"
    export PATH="$HOME/.cargo/bin:$PATH"
    cargo build --release -p mane-engine
)

HEADER_SRC="$ROOT/engine-rs/include/mane_engine.h"
HEADER_DST="$ROOT/engine-swift/Sources/CManeEngine/mane_engine.h"

if [ ! -f "$HEADER_SRC" ]; then
    echo "Header missing at $HEADER_SRC — did cbindgen run?" >&2
    exit 1
fi

echo "[2/2] copy header -> $HEADER_DST"
mkdir -p "$(dirname "$HEADER_DST")"
cp "$HEADER_SRC" "$HEADER_DST"

echo
echo "Done."
echo "Static lib: $ROOT/target/release/libmane_engine.a"
echo "Run tests:  swift test --package-path $ROOT/engine-swift"
