
#!/usr/bin/env bash

set -Eeuo pipefail

# MUSAIC Android Release Build & Install

APK_PATH="build/app/outputs/flutter-apk/app-release.apk"

echo "======================================"
echo " MUSAIC - Android Release"
echo "======================================"

# 检查环境
command -v flutter >/dev/null 2>&1 || {
  echo "错误：未找到 Flutter"
  exit 1
}

command -v adb >/dev/null 2>&1 || {
  echo "错误：未找到 ADB"
  exit 1
}

# 检查设备
ADB=(adb)

DEVICE_SERIAL="${1:-${ANDROID_SERIAL:-}}"

if [[ -n "$DEVICE_SERIAL" ]]; then
  ADB+=(-s "$DEVICE_SERIAL")
else
  DEVICE_COUNT=$(adb devices | awk '
    NR > 1 && $2 == "device" { count++ }
    END { print count+0 }
  ')

  if [[ "$DEVICE_COUNT" -eq 0 ]]; then
    echo "错误：没有检测到已授权的 Android 设备"
    adb devices
    exit 1
  elif [[ "$DEVICE_COUNT" -gt 1 ]]; then
    echo "错误：检测到多个设备，请指定设备序列号："
    adb devices
    echo "用法：./build_android_release.sh <device-serial>"
    exit 1
  fi

  DEVICE_SERIAL=$(adb devices | awk '
    NR > 1 && $2 == "device" { print $1; exit }
  ')
  ADB+=(-s "$DEVICE_SERIAL")
fi

"${ADB[@]}" get-state >/dev/null

echo ""
echo "[1/2] Building Release APK..."

flutter build apk --release

if [[ ! -f "$APK_PATH" ]]; then
  echo "错误：APK 文件不存在：$APK_PATH"
  exit 1
fi

echo ""
echo "[2/2] Installing APK..."

"${ADB[@]}" install -r "$APK_PATH"

echo ""
echo "======================================"
echo " Build & Install Completed!"
echo " Device: $DEVICE_SERIAL"
echo " APK: $APK_PATH"
echo "======================================"
