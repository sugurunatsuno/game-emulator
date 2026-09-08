#!/bin/zsh
set -euo pipefail

readonly PROJECT_DIR="${0:A:h:h}"
readonly SOURCE="$PROJECT_DIR/tools/tft-screen-classifier.swift"
readonly OUTPUT="${TFT_SCREEN_CLASSIFIER_BINARY:-$PROJECT_DIR/runtime/tft-screen-classifier}"
readonly MODULE_CACHE="${TFT_SCREEN_CLASSIFIER_MODULE_CACHE:-$PROJECT_DIR/runtime/swift-module-cache}"

mkdir -p "${OUTPUT:h}" "$MODULE_CACHE"
/usr/bin/xcrun swiftc \
    -O \
    -target "${TFT_SCREEN_CLASSIFIER_TARGET:-arm64-apple-macosx12.0}" \
    -module-cache-path "$MODULE_CACHE" \
    -framework CoreGraphics \
    -framework ImageIO \
    -framework Vision \
    "$SOURCE" \
    -o "$OUTPUT"

print -r -- "$OUTPUT"
