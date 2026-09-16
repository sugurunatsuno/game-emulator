#!/bin/zsh
set -euo pipefail

readonly PROJECT_DIR="${0:A:h:h}"
readonly LAUNCHER_DIR="$PROJECT_DIR/launcher"
readonly DIST_DIR="${HAKO_DIST_DIR:-$PROJECT_DIR/dist}"
readonly APP="$DIST_DIR/Hako.app"
readonly CONTENTS="$APP/Contents"
readonly RESOURCES="$CONTENTS/Resources"
readonly MACOS="$CONTENTS/MacOS"
readonly ICON_SOURCE="$PROJECT_DIR/branding/hako-app-icon.svg"
readonly ICON_TMP="$(mktemp -d "${TMPDIR:-/tmp}/hako-icon.XXXXXX")"
readonly ICONSET="$ICON_TMP/Hako.iconset"

cleanup() {
    rm -rf "$ICON_TMP"
}
trap cleanup EXIT

render_icon() {
    mkdir -p "$ICONSET"
    /usr/bin/qlmanage -t -s 1024 -o "$ICON_TMP" "$ICON_SOURCE" >/dev/null 2>&1
    local rendered="$ICON_TMP/${ICON_SOURCE:t}.png"
    [[ -f "$rendered" ]] || {
        print -u2 "アイコンのSVGをPNGへ変換できませんでした: $ICON_SOURCE"
        exit 1
    }

    make_size() {
        local pixels="$1"
        local output="$2"
        /usr/bin/sips -z "$pixels" "$pixels" "$rendered" --out "$ICONSET/$output" >/dev/null
    }

    make_size 16 icon_16x16.png
    make_size 32 icon_16x16@2x.png
    make_size 32 icon_32x32.png
    make_size 64 icon_32x32@2x.png
    make_size 128 icon_128x128.png
    make_size 256 icon_128x128@2x.png
    make_size 256 icon_256x256.png
    make_size 512 icon_256x256@2x.png
    make_size 512 icon_512x512.png
    make_size 1024 icon_512x512@2x.png
    /usr/bin/iconutil -c icns "$ICONSET" -o "$RESOURCES/Hako.icns"
}

rm -rf "$APP"
mkdir -p "$MACOS" "$RESOURCES" "$DIST_DIR"

xcrun swiftc -O -parse-as-library -target arm64-apple-macosx12.0 \
    "$LAUNCHER_DIR/Sources/HakoApp.swift" \
    -o "$MACOS/Hako"

cp -X "$LAUNCHER_DIR/Info.plist" "$CONTENTS/Info.plist"
render_icon
cp -X "$PROJECT_DIR/scripts/install-android-runtime.command" "$RESOURCES/install-android-runtime.command"
chmod 755 "$RESOURCES/install-android-runtime.command"

codesign --force --sign - --timestamp=none "$APP"
codesign --verify --deep --strict "$APP"
print "Built: $APP"
