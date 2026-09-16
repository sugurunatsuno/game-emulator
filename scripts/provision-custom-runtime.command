#!/bin/zsh
set -euo pipefail

# 個人利用向けのカスタムAndroid実行環境をローカル生成する。
# ROMや生成済みuserdataはリポジトリへ保存しない。

readonly PROJECT_DIR="${0:A:h:h}"
source "$PROJECT_DIR/scripts/android-environment.sh"

readonly SDK_ROOT="${CUSTOM_ANDROID_SDK_ROOT:-$(resolve_android_sdk_root)}"
readonly AVD_HOME="${CUSTOM_AVD_HOME:-${ANDROID_AVD_HOME:-$HOME/.android/avd}}"
readonly AVD_NAME="${CUSTOM_AVD_NAME:-HakoCustom}"
readonly API_LEVEL="${CUSTOM_API_LEVEL:-35}"
readonly IMAGE_FLAVOR="${CUSTOM_IMAGE_FLAVOR:-google_apis}"
readonly ABI="${CUSTOM_ABI:-arm64-v8a}"
readonly IMAGE_PACKAGE="system-images;android-${API_LEVEL};${IMAGE_FLAVOR};${ABI}"
readonly EMULATOR_PORT="${CUSTOM_EMULATOR_PORT:-5580}"
readonly SERIAL="emulator-${EMULATOR_PORT}"
readonly CPU_CORES="${CUSTOM_CPU_CORES:-6}"
readonly MEMORY_MB="${CUSTOM_MEMORY_MB:-6144}"
readonly DATA_SIZE="${CUSTOM_DATA_SIZE:-16384M}"
readonly WIDTH="${CUSTOM_WIDTH:-900}"
readonly HEIGHT="${CUSTOM_HEIGHT:-1600}"
readonly DENSITY="${CUSTOM_DENSITY:-240}"
readonly GUEST_AGENT_APK="${CUSTOM_GUEST_AGENT_APK:-}"
readonly LOG_FILE="${CUSTOM_RUNTIME_LOG:-/tmp/hako-custom-runtime.log}"

find_sdk_tool() {
    local name="$1"
    local candidate
    for candidate in \
        "$SDK_ROOT/cmdline-tools/latest/bin/$name" \
        "$SDK_ROOT/cmdline-tools/bin/$name" \
        "$SDK_ROOT/tools/bin/$name"; do
        if [[ -x "$candidate" ]]; then
            print -r -- "$candidate"
            return 0
        fi
    done
    print -u2 "$name が見つかりません。Android SDK Command-line Toolsを導入してください。"
    return 1
}

readonly SDKMANAGER="$(find_sdk_tool sdkmanager)"
readonly AVDMANAGER="$(find_sdk_tool avdmanager)"
readonly ADB="$SDK_ROOT/platform-tools/adb"
readonly EMULATOR="$SDK_ROOT/emulator/emulator"

[[ -x "$ADB" ]] || { print -u2 "adbが見つかりません: $ADB"; exit 2; }
[[ -x "$EMULATOR" ]] || { print -u2 "emulatorが見つかりません: $EMULATOR"; exit 2; }
[[ "$EMULATOR_PORT" == <0-9>## ]] || { print -u2 "CUSTOM_EMULATOR_PORTは数値で指定してください。"; exit 2; }
(( EMULATOR_PORT >= 5554 && EMULATOR_PORT <= 5682 && EMULATOR_PORT % 2 == 0 )) || {
    print -u2 "CUSTOM_EMULATOR_PORTは5554から5682までの偶数で指定してください。"
    exit 2
}
[[ -z "$AVD_NAME" || "$AVD_NAME" == *[^A-Za-z0-9._-]* ]] && {
    print -u2 "CUSTOM_AVD_NAMEに使用できない文字が含まれています。"
    exit 2
}

mkdir -p "$AVD_HOME"

print "Android system imageを確認します: $IMAGE_PACKAGE"
yes | "$SDKMANAGER" --licenses >/dev/null || true
"$SDKMANAGER" "platform-tools" "emulator" "$IMAGE_PACKAGE"

readonly AVD_DIR="$AVD_HOME/$AVD_NAME.avd"
readonly AVD_INI="$AVD_HOME/$AVD_NAME.ini"

if [[ ! -d "$AVD_DIR" ]]; then
    if [[ -e "$AVD_INI" ]]; then
        print -u2 "不完全なAVD定義があります: $AVD_INI"
        exit 2
    fi
    print "AVDを作成します: $AVD_NAME"
    print "no" | ANDROID_AVD_HOME="$AVD_HOME" "$AVDMANAGER" create avd \
        --force \
        --name "$AVD_NAME" \
        --package "$IMAGE_PACKAGE"
fi

readonly CONFIG="$AVD_DIR/config.ini"
[[ -f "$CONFIG" ]] || { print -u2 "AVD設定が見つかりません: $CONFIG"; exit 2; }

set_config() {
    local key="$1"
    local value="$2"
    if grep -q "^${key}=" "$CONFIG"; then
        /usr/bin/sed -i '' "s|^${key}=.*|${key}=${value}|" "$CONFIG"
    else
        print -r -- "${key}=${value}" >> "$CONFIG"
    fi
}

set_config "hw.cpu.ncore" "$CPU_CORES"
set_config "hw.ramSize" "$MEMORY_MB"
set_config "disk.dataPartition.size" "$DATA_SIZE"
set_config "hw.lcd.width" "$WIDTH"
set_config "hw.lcd.height" "$HEIGHT"
set_config "hw.lcd.density" "$DENSITY"
set_config "hw.gpu.enabled" "yes"
set_config "hw.gpu.mode" "host"
set_config "hw.keyboard" "yes"
set_config "showDeviceFrame" "no"
set_config "fastboot.forceColdBoot" "yes"
set_config "fastboot.forceFastBoot" "no"

if "$ADB" -s "$SERIAL" get-state >/dev/null 2>&1; then
    print -u2 "$SERIAL はすでに起動しています。停止してから再実行してください。"
    exit 2
fi

print "初期設定のためAVDを起動します。"
ANDROID_AVD_HOME="$AVD_HOME" "$EMULATOR" "@$AVD_NAME" \
    -port "$EMULATOR_PORT" \
    -gpu host \
    -no-boot-anim \
    -no-snapshot \
    -no-audio \
    >"$LOG_FILE" 2>&1 &
readonly EMULATOR_PID=$!

cleanup() {
    if kill -0 "$EMULATOR_PID" >/dev/null 2>&1; then
        "$ADB" -s "$SERIAL" emu kill >/dev/null 2>&1 || kill "$EMULATOR_PID" >/dev/null 2>&1 || true
    fi
}
trap cleanup EXIT INT TERM

"$ADB" -s "$SERIAL" wait-for-device

print "Androidの起動完了を待っています。"
for _ in {1..180}; do
    if [[ "$("$ADB" -s "$SERIAL" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" == "1" ]]; then
        break
    fi
    sleep 1
done

if [[ "$("$ADB" -s "$SERIAL" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" != "1" ]]; then
    print -u2 "Androidの起動が完了しませんでした。ログ: $LOG_FILE"
    exit 3
fi

"$ADB" -s "$SERIAL" shell settings put global window_animation_scale 0
"$ADB" -s "$SERIAL" shell settings put global transition_animation_scale 0
"$ADB" -s "$SERIAL" shell settings put global animator_duration_scale 0

"$ADB" -s "$SERIAL" shell settings put system screen_off_timeout 2147483647
"$ADB" -s "$SERIAL" shell settings put global stay_on_while_plugged_in 3
"$ADB" -s "$SERIAL" shell settings put system accelerometer_rotation 0
"$ADB" -s "$SERIAL" shell wm size "${WIDTH}x${HEIGHT}"
"$ADB" -s "$SERIAL" shell wm density "$DENSITY"

"$ADB" -s "$SERIAL" logcat -G "${CUSTOM_LOGCAT_SIZE:-2M}" >/dev/null 2>&1 || true

if [[ -n "${CUSTOM_DISABLE_PACKAGES:-}" ]]; then
    for package_name in ${(z)CUSTOM_DISABLE_PACKAGES}; do
        print "無効化: $package_name"
        "$ADB" -s "$SERIAL" shell pm disable-user --user 0 "$package_name"
    done
fi

if [[ -n "$GUEST_AGENT_APK" ]]; then
    [[ -f "$GUEST_AGENT_APK" ]] || { print -u2 "Guest Agent APKが見つかりません: $GUEST_AGENT_APK"; exit 2; }
    print "Guest Agentを導入します: $GUEST_AGENT_APK"
    "$ADB" -s "$SERIAL" install -r -g "$GUEST_AGENT_APK"
fi

"$ADB" -s "$SERIAL" shell sync >/dev/null 2>&1 || true
print "初期化が完了しました。Androidを停止します。"
"$ADB" -s "$SERIAL" emu kill >/dev/null
wait "$EMULATOR_PID" 2>/dev/null || true
trap - EXIT INT TERM

print ""
print "Custom runtime ready: $AVD_NAME"
print "AVD home: $AVD_HOME"
print "起動例:"
print "  ANDROID_AVD_HOME=\"$AVD_HOME\" \"$EMULATOR\" @$AVD_NAME -gpu host -no-boot-anim"
