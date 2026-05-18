#!/usr/bin/env bash
# Compile EasyList + EasyPrivacy into safari-ext/rules.json, the
# declarativeNetRequest ruleset that Safari and Chrome load directly.
# Run after ./scripts/fetch-filterlists.sh has populated filterlists/.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PATH="$HOME/.cargo/bin:$PATH"

echo "[1/1] cargo run --example compile_rules --release"
(cd "$ROOT" && cargo run --example compile_rules --release)
