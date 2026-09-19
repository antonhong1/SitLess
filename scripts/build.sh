#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release
app="$PWD/dist/SitLess.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
if [ ! -f dist/SitLess.icns ]; then bash scripts/icon.sh; fi
cp dist/SitLess.icns "$app/Contents/Resources/SitLess.icns"
cp .build/release/SitLess "$app/Contents/MacOS/SitLess"
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>SitLess</string>
<key>CFBundleIdentifier</key><string>app.sitless.mac</string>
<key>CFBundleIconFile</key><string>SitLess</string>
<key>CFBundleName</key><string>SitLess</string>
<key>CFBundleDisplayName</key><string>SitLess</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.0.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign - --identifier app.sitless.mac \
  --requirements '=designated => identifier "app.sitless.mac"' "$app"
codesign --verify --deep --strict "$app"
printf 'Built %s\n' "$app"
