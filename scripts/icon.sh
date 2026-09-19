#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p dist/SitLess.iconset
swift scripts/icon.swift dist/icon.png
for size in 16 32 128 256 512; do
  sips -z "$size" "$size" dist/icon.png --out "dist/SitLess.iconset/icon_${size}x${size}.png" >/dev/null
  double=$((size * 2))
  sips -z "$double" "$double" dist/icon.png --out "dist/SitLess.iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns dist/SitLess.iconset -o dist/SitLess.icns
