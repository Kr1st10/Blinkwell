#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
swift build -c release
app="$PWD/build/Blinkwell.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp .build/release/Pause "$app/Contents/MacOS/Pause"
cp Resources/Info.plist "$app/Contents/Info.plist"
swift scripts/make-icon.swift "$PWD/build"
iconutil -c icns build/AppIcon.iconset -o "$app/Contents/Resources/AppIcon.icns"
strip -S "$app/Contents/MacOS/Pause"
codesign --force --sign - "$app"
codesign --verify --deep --strict "$app"
echo "Собрано: $app"
