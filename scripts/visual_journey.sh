#!/usr/bin/env bash
set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$REPOSITORY_ROOT/scripts/simulator_destination.sh"

RESULT_ROOT="$REPOSITORY_ROOT/ios/TestResults"
RESULT_BUNDLE="$RESULT_ROOT/VisualJourney.xcresult"
ARTIFACT_ROOT="$RESULT_ROOT/VisualJourney"
SCREENSHOT_ROOT="$ARTIFACT_ROOT/Screenshots"
VIDEO_PATH="$ARTIFACT_ROOT/paralux-visual-journey.mp4"
RECORDING_PID=""

rm -rf "$RESULT_BUNDLE" "$ARTIFACT_ROOT"
mkdir -p "$SCREENSHOT_ROOT"

stop_recording() {
  if [[ -n "$RECORDING_PID" ]] && kill -0 "$RECORDING_PID" 2>/dev/null; then
    kill -INT "$RECORDING_PID" 2>/dev/null || true
    wait "$RECORDING_PID" 2>/dev/null || true
  fi
  RECORDING_PID=""
  xcrun simctl status_bar "$SIMULATOR_UDID" clear >/dev/null 2>&1 || true
}
trap stop_recording EXIT INT TERM

xcrun simctl bootstatus "$SIMULATOR_UDID" -b
xcrun simctl status_bar "$SIMULATOR_UDID" override \
  --time "9:41" \
  --batteryState charged \
  --batteryLevel 100 \
  --wifiBars 3 \
  --cellularBars 4

xcrun simctl io "$SIMULATOR_UDID" recordVideo \
  --codec=h264 \
  "$VIDEO_PATH" &
RECORDING_PID=$!

sleep 2
set +e
xcodebuild \
  -project "$REPOSITORY_ROOT/ios/SleepParalysisCompanion.xcodeproj" \
  -scheme SPC-Development \
  -configuration Development \
  -destination "$SIMULATOR_DESTINATION" \
  -derivedDataPath "$REPOSITORY_ROOT/ios/.generated/DerivedData" \
  -resultBundlePath "$RESULT_BUNDLE" \
  CODE_SIGNING_ALLOWED=NO \
  GCC_TREAT_WARNINGS_AS_ERRORS=YES \
  test \
  -only-testing:SPCUITests/ApplicationLaunchUITests/testVisualShowcaseJourney
TEST_STATUS=$?
set -e

stop_recording
trap - EXIT INT TERM

VIDEO_STATUS=0
[[ -s "$VIDEO_PATH" ]] || VIDEO_STATUS=1

EXPORT_STATUS=0
xcrun xcresulttool export attachments \
  --path "$RESULT_BUNDLE" \
  --output-path "$SCREENSHOT_ROOT" || EXPORT_STATUS=$?

SCREENSHOT_COUNT="$(find "$SCREENSHOT_ROOT" -type f \( -name '*.png' -o -name '*.heic' \) | wc -l | tr -d ' ')"

cat >"$ARTIFACT_ROOT/README.md" <<EOF
# Paralux visual journey

- Commit: \`$(git -C "$REPOSITORY_ROOT" rev-parse HEAD)\`
- Simulator: \`$SIMULATOR_DESTINATION\`
- Journey result: \`$TEST_STATUS\`
- Video result: \`$VIDEO_STATUS\`
- Screenshot export result: \`$EXPORT_STATUS\`
- Named screenshot checkpoints: \`$SCREENSHOT_COUNT\`

The presentation uses the Debug-only UI-test authentication seam after showing
the real unconfigured-provider boundary. It does not prove production OAuth,
signing, TestFlight, physical-device behavior, locked-device behavior, or audio
quality.

Open \`paralux-visual-journey.mp4\` for the walkthrough. The \`Screenshots\`
folder contains the named visual checkpoints and the xcresult export manifest.
EOF

[[ "$TEST_STATUS" -eq 0 ]] || exit "$TEST_STATUS"
[[ "$VIDEO_STATUS" -eq 0 ]] || {
  echo "The Simulator recording was not created." >&2
  exit 1
}
[[ "$EXPORT_STATUS" -eq 0 ]] || exit "$EXPORT_STATUS"
[[ "$SCREENSHOT_COUNT" -ge 16 ]] || {
  echo "Expected at least 16 visual checkpoints, found $SCREENSHOT_COUNT." >&2
  exit 1
}

printf 'Captured %s visual checkpoints and %s.\n' "$SCREENSHOT_COUNT" "$VIDEO_PATH"
