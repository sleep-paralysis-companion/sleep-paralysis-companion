#!/usr/bin/env bash
set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$REPOSITORY_ROOT/scripts/versions.env"

xcodebuild \
  -project "$REPOSITORY_ROOT/ios/SleepParalysisCompanion.xcodeproj" \
  -scheme SPC-Development \
  -configuration Development \
  -destination "platform=iOS Simulator,name=$SIMULATOR_NAME,OS=$SIMULATOR_OS,arch=$SIMULATOR_ARCH" \
  -derivedDataPath "$REPOSITORY_ROOT/ios/.generated/DerivedData" \
  CODE_SIGNING_ALLOWED=NO \
  GCC_TREAT_WARNINGS_AS_ERRORS=YES \
  clean build

BUILT_APP="$REPOSITORY_ROOT/ios/.generated/DerivedData/Build/Products/Development-iphonesimulator/SleepParalysisCompanion.app"
[[ -f "$BUILT_APP/PrivacyInfo.xcprivacy" ]] || {
  echo "Built app is missing PrivacyInfo.xcprivacy." >&2
  exit 1
}

[[ -f "$BUILT_APP/en.lproj/Localizable.strings" ]] || {
  echo "Built app is missing the development localization." >&2
  exit 1
}
