#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-$PWD/.build/clang-cache}"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/module-cache"
swift build -c release --disable-sandbox
APP="$PWD/dist/Teum.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/Teum "$APP/Contents/MacOS/Teum.next"
mv -f "$APP/Contents/MacOS/Teum.next" "$APP/Contents/MacOS/Teum"
cp Resources/Info.plist "$APP/Contents/Info.plist"
swift scripts/make-icon.swift "$APP/Contents/Resources/AppIcon.icns" "$PWD/dist/Teum-icon.png"
codesign --force --sign - "$APP"
printf 'Built %s\n' "$APP"
