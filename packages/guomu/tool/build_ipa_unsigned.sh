#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "iOS IPA 必须在 macOS 上构建；当前系统不是 macOS。" >&2
  exit 1
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLUTTER_BIN="${FLUTTER_BIN:-flutter}"
APP_PATH="$ROOT/build/ios/iphoneos/Runner.app"
OUT_DIR="$ROOT/build/ios/ipa"
PAYLOAD_DIR="$OUT_DIR/Payload"
APP_COPY="$PAYLOAD_DIR/Runner.app"
VERSION="$(sed -n 's/^version:[[:space:]]*//p' "$ROOT/pubspec.yaml" | cut -d+ -f1)"
IPA_NAME="Guomu-${VERSION}-unsigned.ipa"

if ! command -v "$FLUTTER_BIN" >/dev/null 2>&1; then
  echo "找不到 Flutter：$FLUTTER_BIN" >&2
  exit 1
fi
if ! command -v zip >/dev/null 2>&1; then
  echo "找不到 zip；请先安装 Xcode Command Line Tools。" >&2
  exit 1
fi

cd "$ROOT"
"$FLUTTER_BIN" pub get
"$FLUTTER_BIN" build ios --release --no-codesign

if [[ ! -d "$APP_PATH" ]]; then
  echo "没有找到 iOS 构建产物：$APP_PATH" >&2
  exit 1
fi

rm -rf "$OUT_DIR"
mkdir -p "$PAYLOAD_DIR"
/usr/bin/ditto "$APP_PATH" "$APP_COPY"

if [[ ! -f "$APP_COPY/Info.plist" ]]; then
  echo "IPA 包结构校验失败：缺少 Payload/Runner.app/Info.plist。" >&2
  exit 1
fi

APP_EXECUTABLE="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$APP_COPY/Info.plist")"
if [[ -z "$APP_EXECUTABLE" || ! -f "$APP_COPY/$APP_EXECUTABLE" ]]; then
  echo "IPA 包结构校验失败：缺少 CFBundleExecutable 指向的可执行文件。" >&2
  exit 1
fi

APP_BUNDLE_NAME="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleName' "$APP_COPY/Info.plist" 2>/dev/null || true)"
WIDGET_INFO="$APP_COPY/PlugIns/GuomuWidget.appex/Info.plist"
WIDGET_BUNDLE_NAME="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleName' "$WIDGET_INFO" 2>/dev/null || true)"
if [[ -z "$APP_BUNDLE_NAME" || -z "$WIDGET_BUNDLE_NAME" ]]; then
  echo "IPA 包结构校验失败：主 App 或 Widget 扩展缺少非空 CFBundleName。" >&2
  exit 1
fi

(
  cd "$OUT_DIR"
  /usr/bin/zip -qry "$IPA_NAME" Payload
)

if ! /usr/bin/unzip -Z1 "$OUT_DIR/$IPA_NAME" | grep -qx 'Payload/Runner.app/Info.plist'; then
  echo "IPA 包结构校验失败：压缩包内未找到 Payload/Runner.app/Info.plist。" >&2
  exit 1
fi
if ! /usr/bin/unzip -Z1 "$OUT_DIR/$IPA_NAME" | grep -qx 'Payload/Runner.app/PlugIns/GuomuWidget.appex/Info.plist'; then
  echo "IPA 包结构校验失败：未嵌入灵动岛 Widget 扩展。" >&2
  exit 1
fi

rm -rf "$PAYLOAD_DIR"

printf '\n未签名 IPA：%s\n' "$OUT_DIR/$IPA_NAME"
printf '请使用 Sideloadly、AltStore、TrollStore 或你的签名证书完成签名安装。\n'
