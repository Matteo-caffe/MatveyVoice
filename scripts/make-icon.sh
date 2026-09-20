#!/bin/bash
# Generates Resources/AppIcon.icns from code (no third-party artwork).
set -euo pipefail
cd "$(dirname "$0")/.."
SET="$(mktemp -d)/AppIcon.iconset"
mkdir -p "$SET"
swift scripts/make-icon.swift "$SET"
iconutil -c icns "$SET" -o Resources/AppIcon.icns
rm -rf "$(dirname "$SET")"
echo "Wrote Resources/AppIcon.icns"
