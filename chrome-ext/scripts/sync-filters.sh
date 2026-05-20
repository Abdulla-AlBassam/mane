#!/usr/bin/env bash
# Copy the latest EasyList + EasyPrivacy from the repo's top-level filterlists/
# into safari-ext/filters/ so the Safari extension bundles them as resources.
# Run scripts/fetch-filterlists.sh from the repo root first to refresh them.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ext_dir="$(cd "$here/.." && pwd)"
repo_root="$(cd "$ext_dir/.." && pwd)"
src="$repo_root/filterlists"
dst="$ext_dir/filters"

if [[ ! -f "$src/easylist.txt" || ! -f "$src/easyprivacy.txt" ]]; then
  echo "filter lists missing in $src" >&2
  echo "run ./scripts/fetch-filterlists.sh from the repo root first" >&2
  exit 1
fi

cp "$src/easylist.txt"    "$dst/easylist.txt"
cp "$src/easyprivacy.txt" "$dst/easyprivacy.txt"

echo "synced: $dst/easylist.txt"
echo "synced: $dst/easyprivacy.txt"
