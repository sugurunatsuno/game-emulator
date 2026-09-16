#!/bin/zsh
set -euo pipefail

readonly ROOT="${ANDROID_RUNTIME_ROOT:-${HOME}/Library/Application Support/Mactician/sdk}"
readonly DOWNLOADS="$ROOT/.downloads"
readonly PLATFORM_URL="https://dl.google.com/android/repository/platform-tools_r36.0.2-darwin.zip"
readonly PLATFORM_SHA256="106a5d31fad8c1c0c5a180d06f5779767d129d7d5edbe629005c11a85eec5b4b"
readonly EMULATOR_URL="https://dl.google.com/android/repository/emulator-darwin_aarch64-15917651.zip"
readonly EMULATOR_SHA256="22530de9363f34ea945ecb5cad74523abd4b615f27f3c1a9899efb183ea9e144"

download() {
    local url="$1" hash="$2" archive="$3"
    mkdir -p "$DOWNLOADS"
    if [[ ! -f "$archive" ]] || [[ "$(shasum -a 256 "$archive" | awk '{print $1}')" != "$hash" ]]; then
        curl -fL --retry 3 --retry-delay 2 --proto '=https' --tlsv1.2 "$url" -o "$archive"
    fi
    [[ "$(shasum -a 256 "$archive" | awk '{print $1}')" == "$hash" ]] \
        || { print -u2 "ダウンロードしたSDKのハッシュが一致しません"; exit 1; }
}

readonly PLATFORM_ARCHIVE="$DOWNLOADS/platform-tools.zip"
readonly EMULATOR_ARCHIVE="$DOWNLOADS/emulator.zip"
download "$PLATFORM_URL" "$PLATFORM_SHA256" "$PLATFORM_ARCHIVE"
download "$EMULATOR_URL" "$EMULATOR_SHA256" "$EMULATOR_ARCHIVE"
mkdir -p "$ROOT"
unzip -q -o "$PLATFORM_ARCHIVE" -d "$ROOT"
unzip -q -o "$EMULATOR_ARCHIVE" -d "$ROOT"
print "Android SDK tools installed under: $ROOT"
print "次にAndroid StudioでAVDまたはPlay Store system imageを作成してください。"
