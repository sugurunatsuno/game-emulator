#!/bin/zsh

# Android SDKの探索を共有する。特定のゲームやパッケージは扱わない。

resolve_android_sdk_root() {
    local explicit_root="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"
    local candidate
    for candidate in "$explicit_root" "$HOME/Library/Android/sdk"; do
        if [[ -n "$candidate" && -d "$candidate" ]]; then
            print -r -- "$candidate"
            return 0
        fi
    done
    print -u2 "Android SDKが見つかりません。ANDROID_SDK_ROOTを設定してください。"
    return 1
}

resolve_adb() {
    local sdk_root="$(resolve_android_sdk_root)"
    local adb_path="$sdk_root/platform-tools/adb"
    [[ -x "$adb_path" ]] || { print -u2 "adbが見つかりません: $adb_path"; return 1; }
    print -r -- "$adb_path"
}

resolve_emulator() {
    local sdk_root="$(resolve_android_sdk_root)"
    local emulator_path="$sdk_root/emulator/emulator"
    [[ -x "$emulator_path" ]] || { print -u2 "Android Emulatorが見つかりません: $emulator_path"; return 1; }
    print -r -- "$emulator_path"
}
