#!/usr/bin/env bash
#
# Safe release install for the 卡嘟 Android app.
#
# THE RULE THIS SCRIPT EXISTS FOR:
#   never use a tooling command that uninstalls the app before reinstalling.
#   An Android uninstall deletes /data/data/com.caldoo — the Drift
#   database with every meal, food, profile and exercise record — and this app
#   declares allowBackup="false", so the OS keeps no copy either. On 2026-10-30
#   exactly that happened: a tool's install command fell back to
#   "Uninstalling old version..." and wiped the user's data.
#
# So this script always:
#   1. builds the release APK explicitly (never installs a stale artifact),
#   2. checks that the device holds a recent automatic backup
#      (下载/卡嘟备份 in the file manager; the app writes one on launch and
#      on every background transition) and refuses to continue without one,
#   3. installs with `adb install -r`, which OVERWRITES and keeps app data.
#
# Usage:
#   tool/install_android.sh                 # build + verify backup + install -r
#   tool/install_android.sh --device <id>   # pick a device when several attach
#   ALLOW_NO_BACKUP=1 tool/install_android.sh   # bypass the backup check
#   SKIP_BUILD=1 tool/install_android.sh    # reuse the existing release APK
#
# The script never runs `adb uninstall`, `pm clear`, or any install command
# that replaces the package; grep this file if you want to be sure.
set -euo pipefail

cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

APP_ID="com.caldoo"
BACKUP_DIR="/sdcard/Download/卡嘟备份"
APK="build/app/outputs/flutter-apk/app-release.apk"
ADB="${ADB:-adb}"
DEVICE_ARGS=()
CLOCK_SKEW_SECONDS=60

while [ $# -gt 0 ]; do
  case "$1" in
    --device)
      DEVICE_ARGS=(-s "$2")
      shift 2
      ;;
    -h|--help)
      sed -n '2,30p' "$0"
      exit 0
      ;;
    *)
      echo "未知参数：$1" >&2
      exit 2
      ;;
  esac
done

echo "== 1/3 连接检查 =="
if ! command -v "$ADB" >/dev/null 2>&1; then
  echo "找不到 adb，请先把 Android SDK platform-tools 加进 PATH" >&2
  exit 1
fi
"$ADB" ${DEVICE_ARGS[@]+"${DEVICE_ARGS[@]}"} get-state >/dev/null 2>&1 || {
  echo "没有可用的设备（adb devices 为空或未授权）" >&2
  exit 1
}
DEVICE="$("$ADB" ${DEVICE_ARGS[@]+"${DEVICE_ARGS[@]}"} shell getprop ro.product.model | tr -d '\r')"
echo "设备：$DEVICE"

echo
echo "== 2/3 构建 release APK =="
if [ "${SKIP_BUILD:-0}" = "1" ] && [ -f "$APK" ]; then
  echo "SKIP_BUILD=1，复用现有 $APK"
else
  # This Flutter toolchain only regenerates GeneratedPluginRegistrant.java with
  # releaseMode filtering when `pub get` runs as part of the build; a stale
  # registrant from an earlier `flutter pub get` references the dev-only
  # integration_test plugin and fails the release compile. Touching the pubspec
  # makes the build re-run pub get + the release-mode regeneration.
  touch pubspec.yaml
  flutter --no-version-check build apk --release
fi
if [ ! -f "$APK" ]; then
  echo "构建产物不存在：$APK" >&2
  exit 1
fi
echo "APK：${APK}（$(stat -f '%Sm' -t '%Y-%m-%d %H:%M:%S' "$APK" 2>/dev/null || stat -c '%y' "$APK")）"

echo
echo "== 3/3 安装（覆盖安装，保留数据）=="
LATEST="$("$ADB" ${DEVICE_ARGS[@]+"${DEVICE_ARGS[@]}"} shell "ls -t '$BACKUP_DIR' 2>/dev/null | head -1" | tr -d '\r')"
if [ -z "$LATEST" ]; then
  if [ "${ALLOW_NO_BACKUP:-0}" != "1" ]; then
    cat >&2 <<EOF
设备上还没有自动备份（$BACKUP_DIR 为空）。

先打开 App 一次，让它自动写一份备份（打开或退到后台就会触发），再重新运行本脚本。
确认自己另有 data.json 备份的话，可以用：
  ALLOW_NO_BACKUP=1 tool/install_android.sh
EOF
    exit 1
  fi
  echo "!! 没有自动备份，但 ALLOW_NO_BACKUP=1，继续" >&2
else
  AGE="$("$ADB" ${DEVICE_ARGS[@]+"${DEVICE_ARGS[@]}"} shell "stat -c %Y '$BACKUP_DIR/$LATEST' 2>/dev/null" | tr -d '\r')"
  NOW="$(date +%s)"
  if [ -n "$AGE" ] && [ "$AGE" -gt 0 ] 2>/dev/null; then
    MINS=$(( (NOW - AGE) / 60 ))
    echo "最近自动备份：${LATEST}（${MINS} 分钟前）"
    if [ "$MINS" -gt 1440 ] && [ "${ALLOW_NO_BACKUP:-0}" != "1" ]; then
      echo "备份已超过 24 小时，先打开 App 刷新一次，或用 ALLOW_NO_BACKUP=1 强制继续" >&2
      exit 1
    fi
  else
    echo "最近自动备份：$LATEST"
  fi
fi

# -r = overwrite in place, keeping the app's data directory. Never add -d or
# --uninstall here: they are exactly the destructive step this script prevents.
"$ADB" ${DEVICE_ARGS[@]+"${DEVICE_ARGS[@]}"} install -r "$APK"

echo
echo "安装完成（覆盖安装，数据保留）。建议打开 App 确认记录还在。"
