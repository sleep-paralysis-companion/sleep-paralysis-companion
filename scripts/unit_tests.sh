#!/usr/bin/env bash
set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$REPOSITORY_ROOT/scripts/simulator_destination.sh"

rm -rf "$REPOSITORY_ROOT/ios/TestResults/Unit.xcresult"
xcodebuild \
  -project "$REPOSITORY_ROOT/ios/SleepParalysisCompanion.xcodeproj" \
  -scheme SPC-Development \
  -configuration Development \
  -destination "$SIMULATOR_DESTINATION" \
  -derivedDataPath "$REPOSITORY_ROOT/ios/.generated/DerivedData" \
  -resultBundlePath "$REPOSITORY_ROOT/ios/TestResults/Unit.xcresult" \
  CODE_SIGNING_ALLOWED=NO \
  GCC_TREAT_WARNINGS_AS_ERRORS=YES \
  test -only-testing:SPCUnitTests
