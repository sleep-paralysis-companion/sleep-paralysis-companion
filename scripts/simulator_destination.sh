#!/usr/bin/env bash
set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$REPOSITORY_ROOT/scripts/versions.env"

SIMULATOR_RECORD="$REPOSITORY_ROOT/ios/.generated/simulator-udid"
[[ -s "$SIMULATOR_RECORD" ]] || {
  echo "Prepared simulator is unavailable; run scripts/prepare_simulator.sh first." >&2
  exit 1
}

SIMULATOR_UDID="$(cat "$SIMULATOR_RECORD")"
xcrun simctl list devices --json | jq -e \
  --arg udid "$SIMULATOR_UDID" \
  '.devices[][] | select(.udid == $udid and .isAvailable == true)' \
  >/dev/null

SIMULATOR_DESTINATION="platform=iOS Simulator,id=$SIMULATOR_UDID,arch=$SIMULATOR_ARCH"
