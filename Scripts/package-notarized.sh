#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
DERIVED="${DERIVED_DATA_PATH:-/tmp/macropadstudio-notarized}"
OUTPUT="$ROOT/outputs"
STAGING="$DERIVED/NotarizedPackage"
APP="$DERIVED/Build/Products/Release/MacroPadStudio.app"
VERIFY="$DERIVED/PackageVerification"
ARCHIVE_BASENAME="${ARCHIVE_BASENAME:-MacroPad-Studio-macOS}"
ZIP="$OUTPUT/$ARCHIVE_BASENAME.zip"
CHECKSUM="$ZIP.sha256"

: "${DEVELOPER_ID_APPLICATION:?Set DEVELOPER_ID_APPLICATION to the full Developer ID Application identity name.}"
: "${NOTARYTOOL_PROFILE:?Set NOTARYTOOL_PROFILE to the notarytool keychain profile name.}"

cd "$ROOT"

xcodegen generate
xcodebuild \
  -project MacroPadStudio.xcodeproj \
  -scheme MacroPadStudio \
  -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath "$DERIVED" \
  CODE_SIGNING_ALLOWED=YES \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="$DEVELOPER_ID_APPLICATION" \
  CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
  OTHER_CODE_SIGN_FLAGS="--timestamp" \
  build

codesign --verify --deep --strict --verbose=2 "$APP"
codesign --display --verbose=4 "$APP" > "$DERIVED/codesign-display.txt" 2>&1
grep -q "runtime" "$DERIVED/codesign-display.txt"

rm -rf "$STAGING" "$VERIFY"
mkdir -p "$STAGING" "$VERIFY" "$OUTPUT"
ditto --norsrc --noextattr --noqtn "$APP" "$STAGING/MacroPadStudio.app"
codesign --verify --deep --strict --verbose=2 "$STAGING/MacroPadStudio.app"

ditto -c -k --norsrc --noextattr --noqtn --keepParent \
  "$STAGING/MacroPadStudio.app" \
  "$ZIP"

xcrun notarytool submit "$ZIP" \
  --keychain-profile "$NOTARYTOOL_PROFILE" \
  --wait

xcrun stapler staple "$STAGING/MacroPadStudio.app"
xcrun stapler validate "$STAGING/MacroPadStudio.app"
spctl --assess --type execute --verbose=4 "$STAGING/MacroPadStudio.app"

rm -f "$ZIP" "$CHECKSUM"
ditto -c -k --norsrc --noextattr --noqtn --keepParent \
  "$STAGING/MacroPadStudio.app" \
  "$ZIP"

rm -rf "$VERIFY"
mkdir -p "$VERIFY"
ditto -x -k "$ZIP" "$VERIFY"
codesign --verify --deep --strict --verbose=2 "$VERIFY/MacroPadStudio.app"
xcrun stapler validate "$VERIFY/MacroPadStudio.app"
spctl --assess --type execute --verbose=4 "$VERIFY/MacroPadStudio.app"

cd "$OUTPUT"
shasum -a 256 "$ARCHIVE_BASENAME.zip" > "$ARCHIVE_BASENAME.zip.sha256"

echo "Packaged notarized app: $ZIP"
echo "Checksum: $CHECKSUM"
