#!/usr/bin/env bash
set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$REPOSITORY_ROOT/scripts/versions.env"

rm -rf "$REPOSITORY_ROOT/ios/TestResults/UI.xcresult"
xcodebuild \
  -project "$REPOSITORY_ROOT/ios/SleepParalysisCompanion.xcodeproj" \
  -scheme SPC-Development \
  -configuration Development \
  -destination "platform=iOS Simulator,name=$SIMULATOR_NAME,OS=$SIMULATOR_OS,arch=$SIMULATOR_ARCH" \
  -derivedDataPath "$REPOSITORY_ROOT/ios/.generated/DerivedData" \
  -resultBundlePath "$REPOSITORY_ROOT/ios/TestResults/UI.xcresult" \
  CODE_SIGNING_ALLOWED=NO \
  GCC_TREAT_WARNINGS_AS_ERRORS=YES \
  test -only-testing:SPCUITests
