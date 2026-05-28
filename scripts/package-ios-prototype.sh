#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

VERSION="$(git rev-parse --short HEAD 2>/dev/null || date +%Y%m%d%H%M%S)"
PACKAGE_DIR="dist"
PACKAGE_NAME="LabBuddy-iOS-prototype-${VERSION}.zip"
PACKAGE_PATH="${PACKAGE_DIR}/${PACKAGE_NAME}"
LATEST_NAME="LabBuddy-iOS-prototype-latest.zip"
LATEST_PATH="${PACKAGE_DIR}/${LATEST_NAME}"

echo "== LabBuddy iOS prototype package =="
mkdir -p "$PACKAGE_DIR"
rm -f "$PACKAGE_PATH"
rm -f "$LATEST_PATH"

echo "Running static preflight..."
set +e
./scripts/check-ios-local.sh
PREFLIGHT_STATUS=$?
set -e
if [[ "$PREFLIGHT_STATUS" != "0" && "$PREFLIGHT_STATUS" != "2" ]]; then
  echo "Preflight failed with status ${PREFLIGHT_STATUS}; package aborted." >&2
  exit "$PREFLIGHT_STATUS"
fi

echo "Creating ${PACKAGE_PATH}..."
{
git ls-files \
  'LabBuddy/**' \
  'LabBuddy.xcodeproj/**' \
  'Open-LabBuddy.command' \
  'README.md' \
  'docs/**' \
  'scripts/check-ios-local.sh' \
  'scripts/package-ios-prototype.sh'
printf '%s\n' 'scripts/package-ios-prototype.sh'
printf '%s\n' 'Open-LabBuddy.command'
} | sort -u | zip -q "$PACKAGE_PATH" -@
cp "$PACKAGE_PATH" "$LATEST_PATH"

echo "Package created: ${PACKAGE_PATH}"
echo "Latest alias: ${LATEST_PATH}"
echo "Contents:"
zipinfo -1 "$PACKAGE_PATH" | sed 's/^/  /'
