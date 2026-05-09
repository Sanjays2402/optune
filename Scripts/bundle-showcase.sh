#!/usr/bin/env bash
# Wrap the SwiftPM-built OptuneShowcase executable in a minimal .app bundle so
# macOS treats it as a regular foreground app — needed for window focus & screenshots.

set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG="${1:-release}"
BUILD_DIR=".build/$( [ "$CONFIG" = "release" ] && echo release || echo debug )"
APP_NAME="OptuneShowcase.app"
APP_DIR=".build/$APP_NAME"

if [[ ! -x "$BUILD_DIR/OptuneShowcase" ]]; then
  echo "Build first: swift build -c $CONFIG --product OptuneShowcase" >&2
  exit 1
fi

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

cp "$BUILD_DIR/OptuneShowcase" "$APP_DIR/Contents/MacOS/OptuneShowcase"

cat > "$APP_DIR/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>OptuneShowcase</string>
  <key>CFBundleDisplayName</key><string>Optune Showcase</string>
  <key>CFBundleExecutable</key><string>OptuneShowcase</string>
  <key>CFBundleIdentifier</key><string>com.sanjays2402.optune.showcase</string>
  <key>CFBundleVersion</key><string>0.1.0</string>
  <key>CFBundleShortVersionString</key><string>0.1.0</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>LSMinimumSystemVersion</key><string>15.0</string>
  <key>NSHumanReadableCopyright</key><string>© 2026 Sanjay Santhanam — GPL-3.0-or-later</string>
</dict>
</plist>
PLIST

echo "Bundled $APP_DIR"
