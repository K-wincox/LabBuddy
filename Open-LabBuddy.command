#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

PROJECT="LabBuddy.xcodeproj"

if [[ ! -d "$PROJECT" ]]; then
  echo "Could not find $PROJECT next to this launcher."
  echo "Move Open-LabBuddy.command back to the LabBuddy project folder and try again."
  read -r -p "Press Return to close..."
  exit 1
fi

if ! xcrun --find xcodebuild >/dev/null 2>&1; then
  echo "Xcode is not selected yet."
  echo
  echo "1. Install Xcode from the Mac App Store."
  echo "2. Then run:"
  echo "   sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
  echo "3. Double-click this file again."
  echo
  read -r -p "Press Return to close..."
  exit 2
fi

echo "Opening $PROJECT..."
open "$PROJECT"
