#!/usr/bin/env bash
set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST="$REPOSITORY_ROOT/ios/Resources/PrivacyInfo.xcprivacy"
PROJECT_FILE="$REPOSITORY_ROOT/ios/SleepParalysisCompanion.xcodeproj/project.pbxproj"

plutil -lint "$MANIFEST"

plutil -convert json -o - "$MANIFEST" | jq -e '
  .NSPrivacyTracking == false
  and (.NSPrivacyCollectedDataTypes | length) == 0
  and (.NSPrivacyAccessedAPITypes | length) == 0
  and (.NSPrivacyTrackingDomains | length) == 0
'

[[ -f "$PROJECT_FILE" ]] || {
  echo "Generated project is unavailable; run scripts/bootstrap.sh first." >&2
  exit 1
}

grep -Fq "PrivacyInfo.xcprivacy" "$PROJECT_FILE" || {
  echo "Privacy manifest is not a member of the generated app target." >&2
  exit 1
}

if grep -R -n -E 'UserDefaults|systemUptime|volumeAvailableCapacity|creationDate|contentModificationDate|statfs|\bstat\(' "$REPOSITORY_ROOT/ios/Sources"; then
  echo "Potential required-reason API usage needs manifest review." >&2
  exit 1
fi
