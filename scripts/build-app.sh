#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [ "$(uname -m)" != "arm64" ]; then
  echo "MatveyVoice supports Apple Silicon (arm64) only; this Mac is $(uname -m). / Приложение работает только на Apple Silicon." >&2
  exit 1
fi
swift build -c release --arch arm64
BIN="$(swift build -c release --arch arm64 --show-bin-path)/MatveyVoice"
APP="build/MatveyVoice.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/MatveyVoice"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp -R Resources/*.lproj "$APP/Contents/Resources/"
if [ -f Resources/AppIcon.icns ]; then
  cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
  /usr/libexec/PlistBuddy -c "Delete :CFBundleIconFile" "$APP/Contents/Info.plist" 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$APP/Contents/Info.plist"
fi
codesign --force --deep -s - "$APP"
echo "Built $APP"
