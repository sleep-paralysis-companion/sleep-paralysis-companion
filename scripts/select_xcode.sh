#!/usr/bin/env bash
set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$REPOSITORY_ROOT/scripts/versions.env"

XCODE_PATH=""
for candidate in \
  "/Applications/Xcode_${XCODE_VERSION}.app" \
  "/Applications/Xcode-${XCODE_VERSION}.app"; do
  if [[ -d "$candidate" ]]; then
    XCODE_PATH="$candidate"
    break
  fi
done

if [[ -z "$XCODE_PATH" ]]; then
  echo "Required Xcode $XCODE_VERSION was not found in a supported hosted-runner path." >&2
  exit 1
fi

sudo xcode-select --switch "$XCODE_PATH/Contents/Developer"

XCODE_OUTPUT="$(xcodebuild -version)"
grep -Fx "Xcode $XCODE_VERSION" <<<"$XCODE_OUTPUT"
grep -Fx "Build version $XCODE_BUILD" <<<"$XCODE_OUTPUT"

SWIFT_OUTPUT="$(swift --version)"
grep -F "Swift version $SWIFT_VERSION" <<<"$SWIFT_OUTPUT"

SDK_OUTPUT="$(xcrun --sdk iphonesimulator --show-sdk-version)"
[[ "$SDK_OUTPUT" == "$IOS_SDK_VERSION" ]] || {
  echo "Expected iOS Simulator SDK $IOS_SDK_VERSION, found $SDK_OUTPUT" >&2
  exit 1
}
