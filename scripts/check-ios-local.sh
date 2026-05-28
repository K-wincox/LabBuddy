#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

PROJECT="LabBuddy.xcodeproj"
SCHEME="LabBuddy"
SOURCES=(
  "LabBuddy/LabBuddyApp.swift"
  "LabBuddy/Models.swift"
  "LabBuddy/SampleData.swift"
  "LabBuddy/ContentView.swift"
)
JSON_FILES=(
  "LabBuddy/Assets.xcassets/Contents.json"
  "LabBuddy/Assets.xcassets/AccentColor.colorset/Contents.json"
  "LabBuddy/Assets.xcassets/AppIcon.appiconset/Contents.json"
  "LabBuddy/Preview Content/Preview Assets.xcassets/Contents.json"
)

echo "== LabBuddy local iOS preflight =="

echo "Checking Swift sources..."
swiftc -typecheck "${SOURCES[@]}"

echo "Checking Xcode project..."
plutil -lint "$PROJECT/project.pbxproj" >/dev/null
xmllint --noout "$PROJECT/xcshareddata/xcschemes/$SCHEME.xcscheme"

echo "Checking asset JSON..."
ruby -rjson -e 'ARGV.each { |path| JSON.parse(File.read(path)); puts "#{path}: OK" }' "${JSON_FILES[@]}"

if ! xcrun --find xcodebuild >/dev/null 2>&1; then
  echo
  echo "Xcode is not installed or xcode-select is still pointing at Command Line Tools."
  echo "Install Xcode, then run:"
  echo "  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
  echo "  ./scripts/check-ios-local.sh"
  exit 2
fi

echo "Checking Xcode version..."
xcodebuild -version

echo "Building for iOS Simulator..."
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO \
  build

echo "Preflight passed. Open $PROJECT in Xcode and run the $SCHEME scheme."
