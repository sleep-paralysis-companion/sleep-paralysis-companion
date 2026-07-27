#!/usr/bin/env bash
set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST="$REPOSITORY_ROOT/ios/Resources/PrivacyInfo.xcprivacy"

plutil -lint "$MANIFEST"

plutil -convert json -o - "$MANIFEST" | jq -e '
  .NSPrivacyTracking == false
  and (.NSPrivacyCollectedDataTypes | length) == 0
  and (.NSPrivacyAccessedAPITypes | length) == 0
  and (.NSPrivacyTrackingDomains | length) == 0
'

if grep -R -n -E 'UserDefaults|systemUptime|volumeAvailableCapacity|creationDate|contentModificationDate|statfs|\bstat\(' "$REPOSITORY_ROOT/ios/Sources"; then
  echo "Potential required-reason API usage needs manifest review." >&2
  exit 1
fi
