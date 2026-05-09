#!/usr/bin/env bash
# Wrap the SwiftPM-built OptuneApp executable in a minimal .app bundle so
# macOS treats it as a menu bar agent (LSUIElement) rather than a foreground app.

set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG="${1:-release}"
BUILD_DIR=".build/$( [ "$CONFIG" = "release" ] && echo release || echo debug )"
APP_NAME="OptuneApp.app"
APP_DIR=".build/$APP_NAME"

if [[ ! -x "$BUILD_DIR/OptuneApp" ]]; then
  echo "Build first: swift build -c $CONFIG" >&2
  exit 1
fi

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

cp "$BUILD_DIR/OptuneApp" "$APP_DIR/Contents/MacOS/OptuneApp"

cat > "$APP_DIR/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Optune</string>
  <key>CFBundleDisplayName</key><string>Optune</string>
  <key>CFBundleExecutable</key><string>OptuneApp</string>
  <key>CFBundleIdentifier</key><string>com.sanjays2402.optune</string>
  <key>CFBundleVersion</key><string>0.1.0</string>
  <key>CFBundleShortVersionString</key><string>0.1.0</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>LSMinimumSystemVersion</key><string>15.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHumanReadableCopyright</key><string>© 2026 Sanjay Santhanam — GPL-3.0-or-later</string>
</dict>
</plist>
PLIST

echo "Bundled $APP_DIR"
