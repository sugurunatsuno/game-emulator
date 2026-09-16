#!/bin/zsh
set -euo pipefail

# Play Store イメージは root 化せず、開発用AVDと別に扱う。
readonly PROJECT_DIR="${0:A:h:h}"
source "$PROJECT_DIR/scripts/android-environment.sh"

readonly SDK_ROOT="${PLAYSTORE_ANDROID_SDK_ROOT:-${ANDROID_SDK_ROOT:-}}"
readonly AVD_HOME="${PLAYSTORE_AVD_HOME:-${ANDROID_AVD_HOME:-$HOME/.android/avd}}"
readonly AVD_NAME="${PLAYSTORE_AVD_NAME:-PlayStore}"
readonly IMAGE_DIR="${PLAYSTORE_SYSTEM_IMAGE_DIR:-$SDK_ROOT/system-images/android-35/google_apis_playstore/arm64-v8a}"
readonly QEMU_IMG="${PLAYSTORE_QEMU_IMG:-$SDK_ROOT/emulator/qemu-img}"

if [[ -z "$SDK_ROOT" || ! -d "$SDK_ROOT" ]]; then
    print -u2 "Set PLAYSTORE_ANDROID_SDK_ROOT to an Android SDK containing a Play Store image."
    exit 2
fi
if [[ -z "$AVD_NAME" || "$AVD_NAME" == *[^A-Za-z0-9._-]* ]]; then
    print -u2 "PLAYSTORE_AVD_NAME contains unsupported characters."
    exit 2
fi
if [[ ! -f "$IMAGE_DIR/system.img" ]]; then
    print -u2 "Play Store system image not found: $IMAGE_DIR"
    print -u2 "Install system-images;android-35;google_apis_playstore;arm64-v8a or set PLAYSTORE_SYSTEM_IMAGE_DIR."
    exit 2
fi
if [[ ! -x "$QEMU_IMG" ]]; then
    print -u2 "qemu-img was not found: $QEMU_IMG"
    exit 2
fi

readonly AVD_DIR="$AVD_HOME/$AVD_NAME.avd"
readonly AVD_INI="$AVD_HOME/$AVD_NAME.ini"
if [[ -f "$AVD_INI" && -f "$AVD_DIR/config.ini" && -f "$AVD_DIR/userdata-qemu.img" ]]; then
    print "Play Store AVD already exists: $AVD_NAME"
    exit 0
fi
if [[ -e "$AVD_INI" || -e "$AVD_DIR" ]]; then
    print -u2 "Play Store AVD is incomplete; remove it explicitly before retrying: $AVD_NAME"
    exit 2
fi

mkdir -p "$AVD_HOME"
readonly STAGING_DIR="$(mktemp -d "$AVD_HOME/.${AVD_NAME}.XXXXXX")"
trap 'rm -rf "$STAGING_DIR"' EXIT

cat > "$STAGING_DIR/config.ini" <<EOF
AvdId=$AVD_NAME
avd.ini.displayname=Mactician Play Store
abi.type=arm64-v8a
hw.cpu.arch=arm64
hw.cpu.ncore=${PLAYSTORE_CPU_CORES:-6}
hw.lcd.density=${PLAYSTORE_DENSITY:-240}
hw.lcd.height=${PLAYSTORE_HEIGHT:-1600}
hw.lcd.width=${PLAYSTORE_WIDTH:-900}
hw.ramSize=${PLAYSTORE_MEMORY_MB:-6144}
hw.vmHeapSize=576
hw.gpu.enabled=yes
hw.gpu.mode=host
hw.gltransport=pipe
hw.keyboard=yes
skin.name=900x1600
showDeviceFrame=no
disk.dataPartition.size=${PLAYSTORE_DATA_SIZE:-12288}M
image.sysdir.1=${IMAGE_DIR#$SDK_ROOT/}/
tag.id=google_apis_playstore
tag.display=Google Play Store
PlayStore.enabled=true
fastboot.forceColdBoot=yes
fastboot.forceFastBoot=no
avd.ini.encoding=UTF-8
EOF

"$QEMU_IMG" create -f qcow2 "$STAGING_DIR/userdata-qemu.img" "${PLAYSTORE_DATA_SIZE:-12288}M" >/dev/null
if [[ -f "$IMAGE_DIR/encryptionkey.img" ]]; then
    cp "$IMAGE_DIR/encryptionkey.img" "$STAGING_DIR/encryptionkey.img"
fi

mv "$STAGING_DIR" "$AVD_DIR"
cat > "$AVD_INI" <<EOF
avd.ini.encoding=UTF-8
path=$AVD_DIR
path.rel=$AVD_NAME.avd
target=android-35
EOF
trap - EXIT

print "Created Play Store AVD: $AVD_NAME"
print "Start it with: $SDK_ROOT/emulator/emulator @$AVD_NAME -gpu host -no-snapshot"
