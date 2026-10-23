#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
swift build -c release -Xlinker -rpath -Xlinker @executable_path/../Frameworks
app="$PWD/build/Blinkwell.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp .build/release/Pause "$app/Contents/MacOS/Pause"
mkdir -p "$app/Contents/Frameworks"
ditto .build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework "$app/Contents/Frameworks/Sparkle.framework"
cp .build/artifacts/sparkle/Sparkle/LICENSE "$app/Contents/Resources/Sparkle-LICENSE.txt"
cp Resources/Info.plist "$app/Contents/Info.plist"
swift scripts/make-icon.swift "$PWD/build"
iconutil -c icns build/AppIcon.iconset -o "$app/Contents/Resources/AppIcon.icns"
strip -S "$app/Contents/MacOS/Pause"
codesign --force --sign - "$app"
codesign --verify --deep --strict "$app"
echo "Собрано: $app"
