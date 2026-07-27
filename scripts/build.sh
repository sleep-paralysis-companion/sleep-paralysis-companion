#!/usr/bin/env bash
set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$REPOSITORY_ROOT/scripts/versions.env"

xcodebuild \
  -project "$REPOSITORY_ROOT/ios/SleepParalysisCompanion.xcodeproj" \
  -scheme SPC-Development \
  -configuration Development \
  -destination "platform=iOS Simulator,name=$SIMULATOR_NAME,OS=$SIMULATOR_OS" \
  -derivedDataPath "$REPOSITORY_ROOT/ios/.generated/DerivedData" \
  CODE_SIGNING_ALLOWED=NO \
  GCC_TREAT_WARNINGS_AS_ERRORS=YES \
  clean build
