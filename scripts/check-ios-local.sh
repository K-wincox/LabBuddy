#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

PROJECT="LabBuddy.xcodeproj"
SCHEME="LabBuddy"
APPICON_DIR="LabBuddy/Assets.xcassets/AppIcon.appiconset"
APPICON_FILE="$(ruby -rjson -e 'contents = JSON.parse(File.read(ARGV[0])); icon = contents.fetch("images").find { |image| image["filename"] && image["idiom"] == "universal" } || contents.fetch("images").find { |image| image["filename"] }; abort("Missing AppIcon filename in #{ARGV[0]}") unless icon && icon["filename"]; puts icon["filename"]' "$APPICON_DIR/Contents.json")"
SOURCES=(
  "LabBuddy/LabBuddyApp.swift"
  "LabBuddy/Models.swift"
  "LabBuddy/SampleData.swift"
  "LabBuddy/ContentView.swift"
)
REQUIRED_FILES=(
  "$PROJECT/project.pbxproj"
  "$PROJECT/xcshareddata/xcschemes/$SCHEME.xcscheme"
  "$APPICON_DIR/$APPICON_FILE"
  "${SOURCES[@]}"
)
JSON_FILES=(
  "LabBuddy/Assets.xcassets/Contents.json"
  "LabBuddy/Assets.xcassets/AccentColor.colorset/Contents.json"
  "LabBuddy/Assets.xcassets/AppIcon.appiconset/Contents.json"
  "LabBuddy/Preview Content/Preview Assets.xcassets/Contents.json"
)

echo "== LabBuddy local iOS preflight =="

echo "Checking required files..."
for path in "${REQUIRED_FILES[@]}"; do
  if [[ ! -f "$path" ]]; then
    echo "Missing required file: $path" >&2
    exit 1
  fi
done

echo "Checking source file presence..."

echo "Checking Xcode project..."
plutil -lint "$PROJECT/project.pbxproj" >/dev/null
xmllint --noout "$PROJECT/xcshareddata/xcschemes/$SCHEME.xcscheme"
grep -q "BlueprintName = \"$SCHEME\"" "$PROJECT/xcshareddata/xcschemes/$SCHEME.xcscheme"

echo "Checking asset JSON..."
ruby -rjson -e 'ARGV.each { |path| JSON.parse(File.read(path)); puts "#{path}: OK" }' "${JSON_FILES[@]}"

echo "Checking AppIcon dimensions..."
ICON_INFO="$(sips -g pixelWidth -g pixelHeight "$APPICON_DIR/$APPICON_FILE" 2>/dev/null)"
echo "$ICON_INFO" | grep -q "pixelWidth: 1024"
echo "$ICON_INFO" | grep -q "pixelHeight: 1024"

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
