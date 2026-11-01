#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root"

dart_bin="${DART_BIN:-dart}"
if ! command -v "$dart_bin" >/dev/null 2>&1; then
  target="$(printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]')"
  case "$target" in
    ohos|harmony|setup-ohos)
      flutter_bin="${OHOS_FLUTTER_BIN:-${FLUTTER_BIN:-flutter}}"
      ;;
    *)
      flutter_bin="${FLUTTER_BIN:-flutter}"
      ;;
  esac
  flutter_path="$(command -v "$flutter_bin" || true)"
  if [[ -z "$flutter_path" ]]; then
    echo "找不到 dart 或 flutter；请配置 DART_BIN / FLUTTER_BIN。" >&2
    exit 127
  fi
  flutter_root="$(cd -- "$(dirname -- "$flutter_path")/.." && pwd)"
  dart_bin="$flutter_root/bin/cache/dart-sdk/bin/dart"
fi

exec "$dart_bin" tool/package.dart "$@"
