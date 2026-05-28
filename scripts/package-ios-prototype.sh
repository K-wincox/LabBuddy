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
CHECKSUM_PATH="${LATEST_PATH}.sha256"
MANIFEST_PATH="PACKAGE_MANIFEST.txt"

echo "== LabBuddy iOS prototype package =="
mkdir -p "$PACKAGE_DIR"
rm -f "$PACKAGE_PATH"
rm -f "$LATEST_PATH"
rm -f "$CHECKSUM_PATH"
rm -f "$MANIFEST_PATH"

echo "Running static preflight..."
set +e
./scripts/check-ios-local.sh
PREFLIGHT_STATUS=$?
set -e
if [[ "$PREFLIGHT_STATUS" != "0" && "$PREFLIGHT_STATUS" != "2" ]]; then
  echo "Preflight failed with status ${PREFLIGHT_STATUS}; package aborted." >&2
  exit "$PREFLIGHT_STATUS"
fi

cat > "$MANIFEST_PATH" <<MANIFEST
LabBuddy iOS Prototype Package
Version: ${VERSION}

Open:
  Double-click Open-LabBuddy.command
  or open LabBuddy.xcodeproj in Xcode.

Verify:
  ./scripts/check-ios-local.sh
  or make preflight

Package:
  ${PACKAGE_NAME}
  ${LATEST_NAME}

Notes:
  This is a local-first SwiftUI prototype.
  Full iOS Simulator build requires full Xcode.
MANIFEST

echo "Creating ${PACKAGE_PATH}..."
{
git ls-files \
  'LabBuddy/**' \
  'LabBuddy.xcodeproj/**' \
  'Makefile' \
  'Open-LabBuddy.command' \
  'README.md' \
  'docs/**' \
  'scripts/check-ios-local.sh' \
  'scripts/package-ios-prototype.sh'
printf '%s\n' 'scripts/package-ios-prototype.sh'
printf '%s\n' 'Open-LabBuddy.command'
printf '%s\n' 'Makefile'
printf '%s\n' "$MANIFEST_PATH"
} | sort -u | zip -q "$PACKAGE_PATH" -@
cp "$PACKAGE_PATH" "$LATEST_PATH"
shasum -a 256 "$PACKAGE_PATH" "$LATEST_PATH" > "$CHECKSUM_PATH"
rm -f "$MANIFEST_PATH"

echo "Package created: ${PACKAGE_PATH}"
echo "Latest alias: ${LATEST_PATH}"
echo "Checksums:"
cat "$CHECKSUM_PATH" | sed 's/^/  /'
echo "Contents:"
zipinfo -1 "$PACKAGE_PATH" | sed 's/^/  /'
