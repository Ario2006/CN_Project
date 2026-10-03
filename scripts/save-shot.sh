#!/usr/bin/env bash
# Move your newest macOS screenshot into the evidence folder with the right name.
# usage (from repo root): scripts/save-shot.sh evidence/02_DNS/02_DNS_dig_app.png
set -euo pipefail
DEST="${1:?usage: save-shot.sh <dest.png>}"
DIR="${SHOT_DIR:-$HOME/Desktop}"
LATEST="$(ls -t "$DIR"/Screenshot*.png 2>/dev/null | head -1 || true)"
[ -n "$LATEST" ] || { echo "No Screenshot*.png found in $DIR (set SHOT_DIR=...)"; exit 1; }
mkdir -p "$(dirname "$DEST")"
mv "$LATEST" "$DEST"
echo "Saved: $DEST"
