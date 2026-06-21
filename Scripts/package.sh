#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
DERIVED="/tmp/macropadstudio-release"
OUTPUT="$ROOT/outputs"
APP="$DERIVED/Build/Products/Release/MacroPadStudio.app"
VERIFY="$DERIVED/PackageVerification"

cd "$ROOT"
xcodegen generate
xcodebuild \
  -project MacroPadStudio.xcodeproj \
  -scheme MacroPadStudio \
  -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath "$DERIVED" \
  CODE_SIGN_IDENTITY=- \
  build

mkdir -p "$OUTPUT"
rm -f "$OUTPUT/MacroPad-Studio-macOS.zip"
rm -f "$OUTPUT/MacroPad-Studio-macOS.zip.sha256"
rm -rf "$OUTPUT/MacroPadStudio.app"
codesign --verify --deep --strict --verbose=2 "$APP"
ditto --norsrc --noextattr --noqtn "$APP" "$OUTPUT/MacroPadStudio.app"
codesign --verify --deep --strict --verbose=2 "$OUTPUT/MacroPadStudio.app"
ditto -c -k --norsrc --noextattr --noqtn --keepParent \
  "$APP" \
  "$OUTPUT/MacroPad-Studio-macOS.zip"

rm -rf "$VERIFY"
mkdir -p "$VERIFY"
ditto -x -k "$OUTPUT/MacroPad-Studio-macOS.zip" "$VERIFY"
codesign --verify --deep --strict --verbose=2 "$VERIFY/MacroPadStudio.app"

cd "$OUTPUT"
shasum -a 256 "MacroPad-Studio-macOS.zip" \
  > "MacroPad-Studio-macOS.zip.sha256"

echo "Packaged: $OUTPUT/MacroPad-Studio-macOS.zip"
echo "Checksum: $OUTPUT/MacroPad-Studio-macOS.zip.sha256"
