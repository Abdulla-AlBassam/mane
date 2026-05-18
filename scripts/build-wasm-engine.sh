#!/usr/bin/env bash
# Build the engine-wasm crate into safari-ext/engine/ so the Safari Web
# Extension can load it at runtime.
#
# Output layout (gitignored, regenerated on each run):
#   safari-ext/engine/mane_engine_wasm.js         - JS glue (loads + exposes Engine)
#   safari-ext/engine/mane_engine_wasm_bg.wasm    - compiled engine (~2.2MB)
#   safari-ext/engine/mane_engine_wasm.d.ts       - TypeScript declarations
#   safari-ext/engine/mane_engine_wasm_bg.wasm.d.ts
#   safari-ext/engine/package.json                - wasm-pack metadata

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PATH="$HOME/.cargo/bin:$PATH"

if ! command -v wasm-pack >/dev/null 2>&1; then
    echo "wasm-pack not found." >&2
    echo "Install with: curl https://rustwasm.github.io/wasm-pack/installer/init.sh -sSf | sh" >&2
    exit 1
fi

echo "[1/1] wasm-pack build engine-wasm --target web --release"
(
    cd "$ROOT"
    wasm-pack build engine-wasm \
        --target web \
        --out-dir ../safari-ext/engine \
        --release
)

echo
echo "Done."
echo "Output: $ROOT/safari-ext/engine/"
