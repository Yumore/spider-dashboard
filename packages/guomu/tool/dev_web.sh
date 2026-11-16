#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLUTTER_BIN="${FLUTTER_BIN:-/www/.toolchains/flutter/bin/flutter}"
API_BASE="${HG_API_BASE:-https://d1716d.bmikbxhi.cc}"
PORT="${WEB_PORT:-43125}"

mkdir -p "$ROOT/.tmp/flutter" "$ROOT/.tmp/java"
export TMPDIR="$ROOT/.tmp/flutter"
export JAVA_TOOL_OPTIONS="${JAVA_TOOL_OPTIONS:+$JAVA_TOOL_OPTIONS }-Djava.io.tmpdir=$ROOT/.tmp/java"

exec "$FLUTTER_BIN" run \
  -d web-server \
  --web-hostname 127.0.0.1 \
  --web-port "$PORT" \
  --dart-define="HG_API_BASE=$API_BASE"
