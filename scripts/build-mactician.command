#!/bin/zsh
set -euo pipefail

readonly PROJECT_DIR="${0:A:h:h}"
readonly LAUNCHER_DIR="$PROJECT_DIR/launcher"
readonly DIST_DIR="${MACTICIAN_DIST_DIR:-$PROJECT_DIR/dist}"
readonly APP="$DIST_DIR/Mactician.app"
readonly CONTENTS="$APP/Contents"
readonly RESOURCES="$CONTENTS/Resources"
readonly MACOS="$CONTENTS/MacOS"

rm -rf "$APP"
mkdir -p "$MACOS" "$RESOURCES" "$DIST_DIR"
xcrun swiftc -O -parse-as-library -target arm64-apple-macosx12.0 \
    "$LAUNCHER_DIR/Sources/MacticianApp.swift" \
    -o "$MACOS/Mactician"
cp -X "$LAUNCHER_DIR/Info.plist" "$CONTENTS/Info.plist"
cp -X "$LAUNCHER_DIR/Resources/Mactician.icns" "$RESOURCES/Mactician.icns"
codesign --force --sign - --timestamp=none "$APP"
codesign --verify --deep --strict "$APP"
print "Built: $APP"
