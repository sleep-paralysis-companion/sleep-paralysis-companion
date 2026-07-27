#!/usr/bin/env bash
set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$REPOSITORY_ROOT/scripts/versions.env"

SIMULATOR_RECORD="$REPOSITORY_ROOT/ios/.generated/simulator-udid"
mkdir -p "$(dirname "$SIMULATOR_RECORD")"

xcrun simctl list runtimes --json | jq -e \
  --arg identifier "$SIMULATOR_RUNTIME" \
  '.runtimes | any(.identifier == $identifier and .isAvailable == true)'

xcrun simctl list devicetypes --json | jq -e \
  --arg identifier "$SIMULATOR_DEVICE_TYPE" \
  '.devicetypes | any(.identifier == $identifier)'

SIMULATOR_UDID=""
if [[ -s "$SIMULATOR_RECORD" ]]; then
  RECORDED_UDID="$(cat "$SIMULATOR_RECORD")"
  if xcrun simctl list devices --json | jq -e \
    --arg udid "$RECORDED_UDID" \
    '.devices[][] | select(.udid == $udid and .isAvailable == true)' \
    >/dev/null; then
    SIMULATOR_UDID="$RECORDED_UDID"
  fi
fi

if [[ -z "$SIMULATOR_UDID" ]]; then
  SIMULATOR_UDID="$(
    xcrun simctl create \
      "$SIMULATOR_DEVICE_NAME" \
      "$SIMULATOR_DEVICE_TYPE" \
      "$SIMULATOR_RUNTIME"
  )"
  [[ "$SIMULATOR_UDID" =~ ^[0-9A-Fa-f-]{36}$ ]] || {
    echo "simctl returned an invalid simulator identifier." >&2
    exit 1
  }
  printf '%s\n' "$SIMULATOR_UDID" >"$SIMULATOR_RECORD"
fi

SIMULATOR_STATE="$(
  xcrun simctl list devices --json | jq -r \
    --arg udid "$SIMULATOR_UDID" \
    '.devices[][] | select(.udid == $udid) | .state'
)"

if [[ "$SIMULATOR_STATE" == "Shutdown" ]]; then
  xcrun simctl boot "$SIMULATOR_UDID"
elif [[ "$SIMULATOR_STATE" != "Booted" ]]; then
  echo "Simulator is in an unexpected state: $SIMULATOR_STATE" >&2
  exit 1
fi

xcrun simctl bootstatus "$SIMULATOR_UDID" -b
printf 'Prepared %s (%s) on %s.\n' \
  "$SIMULATOR_DEVICE_NAME" \
  "$SIMULATOR_UDID" \
  "$SIMULATOR_RUNTIME"
