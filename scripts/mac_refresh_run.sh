#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if ! command -v flutter >/dev/null 2>&1; then
  echo "flutter is not installed or not in PATH" >&2
  exit 1
fi

echo "==> git pull --ff-only"
git pull --ff-only

echo "==> flutter clean"
flutter clean

echo "==> flutter pub get"
flutter pub get

echo "==> flutter run $*"
if [[ "$#" -eq 0 ]]; then
  flutter run
else
  flutter run "$@"
fi
