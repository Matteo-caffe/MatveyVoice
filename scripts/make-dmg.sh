#!/bin/bash
# Builds build/MatveyVoice.dmg containing the app and an "Applications" shortcut.
set -euo pipefail
cd "$(dirname "$0")/.."
APP="build/MatveyVoice.app"
DMG="build/MatveyVoice.dmg"
[ -d "$APP" ] || scripts/build-app.sh
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
rm -f "$DMG"
hdiutil create -volname "MatveyVoice" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
(cd build && shasum -a 256 MatveyVoice.dmg > MatveyVoice.dmg.sha256)
echo "Built $DMG"
cat build/MatveyVoice.dmg.sha256
