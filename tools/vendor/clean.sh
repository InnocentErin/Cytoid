#!/usr/bin/env bash
# Remove the local Assets/Vendor/ tree (licensed payloads are not in git).
set -eu

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
VENDOR_DIR="$ROOT/Assets/Vendor"

if [ -d "$VENDOR_DIR" ]; then
  rm -rf "$VENDOR_DIR"
  echo "Removed $VENDOR_DIR"
else
  echo "Nothing to clean: $VENDOR_DIR does not exist"
fi

for meta in "$ROOT/Assets/Vendor.meta" "$ROOT/Assets/vendor.meta"; do
  if [ -f "$meta" ]; then
    rm -f "$meta"
    echo "Removed $meta"
  fi
done
