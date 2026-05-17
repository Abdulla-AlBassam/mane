#!/usr/bin/env bash
# Download the filter lists Mane consumes. Cached in filterlists/, not committed.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/filterlists"
mkdir -p "$OUT"

fetch() {
    local name="$1"
    local url="$2"
    local target="$OUT/$name"
    echo "Fetching $name"
    curl -fsSL "$url" -o "$target"
    local rules
    rules=$(grep -cv '^!\|^$' "$target" || true)
    local size
    size=$(du -h "$target" | cut -f1)
    echo "  -> $target  ($rules non-comment lines, $size)"
}

fetch easylist.txt    https://easylist.to/easylist/easylist.txt
fetch easyprivacy.txt https://easylist.to/easylist/easyprivacy.txt

echo
echo "Done."
