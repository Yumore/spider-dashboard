#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLUTTER_BIN="${FLUTTER_BIN:-/www/.toolchains/flutter/bin/flutter}"
API_BASE="${HG_API_BASE:-https://d1716d.bmikbxhi.cc}"

mkdir -p "$ROOT/.tmp/flutter" "$ROOT/.tmp/java" "$ROOT/.tmp/gradle-home"
export TMPDIR="$ROOT/.tmp/flutter"
export JAVA_HOME="${JAVA_HOME:-/www/.toolchains/jdk17}"
export ANDROID_HOME="${ANDROID_HOME:-/www/.toolchains/android-sdk}"
export ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-/www/.toolchains/android-sdk}"
export GRADLE_USER_HOME="${GRADLE_USER_HOME:-$ROOT/.tmp/gradle-home}"
export JAVA_TOOL_OPTIONS="${JAVA_TOOL_OPTIONS:+$JAVA_TOOL_OPTIONS }-Djava.io.tmpdir=$ROOT/.tmp/java"
export PATH="/www/.toolchains/ninja/root/usr/bin:$JAVA_HOME/bin:$PATH"

exec "$FLUTTER_BIN" build apk \
  --release \
  --target-platform android-arm64 \
  --dart-define="HG_API_BASE=$API_BASE"
