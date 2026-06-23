#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APK_PATH="$ROOT_DIR/build/app/outputs/flutter-apk/app-release.apk"
PACKAGE_NAME="com.kongweikang.labbuddy_android"
ANDROID_SDK="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/Library/Android/sdk}}"
APKSIGNER="${APKSIGNER:-$ANDROID_SDK/build-tools/36.1.0/apksigner}"
JAVA_HOME="${JAVA_HOME:-/Applications/Android Studio.app/Contents/jbr/Contents/Home}"
export JAVA_HOME

cd "$ROOT_DIR"

flutter analyze
flutter test
flutter build apk --debug
flutter build apk --release

"$APKSIGNER" verify --verbose --print-certs "$APK_PATH"

if ! command -v adb >/dev/null 2>&1; then
  echo "adb not found; install/start Android platform-tools to run device smoke test."
  exit 0
fi

DEVICE_ID="$(adb devices | awk 'NR > 1 && $2 == "device" { print $1; exit }')"
if [[ -z "$DEVICE_ID" ]]; then
  echo "No Android device/emulator detected; build and signature verification passed, install smoke test skipped."
  exit 0
fi

adb -s "$DEVICE_ID" install -r "$APK_PATH"
adb -s "$DEVICE_ID" shell monkey -p "$PACKAGE_NAME" -c android.intent.category.LAUNCHER 1 >/dev/null
sleep 2
adb -s "$DEVICE_ID" shell pidof "$PACKAGE_NAME" >/dev/null
echo "Android APK install and launch smoke test passed on $DEVICE_ID."
