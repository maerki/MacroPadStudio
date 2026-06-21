#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
cd "$ROOT"

xcodegen generate
xcodebuild \
  -project MacroPadStudio.xcodeproj \
  -scheme MacroPadStudio \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/macropadstudio-derived \
  CODE_SIGNING_ALLOWED=NO \
  build
