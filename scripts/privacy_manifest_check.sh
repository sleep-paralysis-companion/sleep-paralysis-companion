#!/usr/bin/env bash
set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST="$REPOSITORY_ROOT/ios/Resources/PrivacyInfo.xcprivacy"
PROJECT_FILE="$REPOSITORY_ROOT/ios/SleepParalysisCompanion.xcodeproj/project.pbxproj"

plutil -lint "$MANIFEST"

plutil -convert json -o - "$MANIFEST" | jq -e '
  .NSPrivacyTracking == false
  and ([.NSPrivacyCollectedDataTypes[].NSPrivacyCollectedDataType] | sort)
      == ([
        "NSPrivacyCollectedDataTypeHealth",
        "NSPrivacyCollectedDataTypeOtherUserContent",
        "NSPrivacyCollectedDataTypeUserID"
      ] | sort)
  and ([.NSPrivacyCollectedDataTypes[] |
        .NSPrivacyCollectedDataTypeLinked == true
        and .NSPrivacyCollectedDataTypeTracking == false
        and .NSPrivacyCollectedDataTypePurposes
            == ["NSPrivacyCollectedDataTypePurposeAppFunctionality"]] | all)
  and ([.NSPrivacyAccessedAPITypes[].NSPrivacyAccessedAPIType] | sort)
      == ([
        "NSPrivacyAccessedAPICategoryDiskSpace",
        "NSPrivacyAccessedAPICategoryFileTimestamp",
        "NSPrivacyAccessedAPICategoryUserDefaults"
      ] | sort)
  and (.NSPrivacyAccessedAPITypes[] |
        select(.NSPrivacyAccessedAPIType == "NSPrivacyAccessedAPICategoryDiskSpace") |
        .NSPrivacyAccessedAPITypeReasons == ["3B52.1"])
  and (.NSPrivacyAccessedAPITypes[] |
        select(.NSPrivacyAccessedAPIType == "NSPrivacyAccessedAPICategoryFileTimestamp") |
        .NSPrivacyAccessedAPITypeReasons == ["C617.1"])
  and (.NSPrivacyAccessedAPITypes[] |
        select(.NSPrivacyAccessedAPIType == "NSPrivacyAccessedAPICategoryUserDefaults") |
        .NSPrivacyAccessedAPITypeReasons == ["CA92.1"])
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

# Required-reason API tripwire. volumeAvailableCapacity is intentionally not
# listed here: disk-space reads are covered by the manifest declaration above,
# which this script enforces exactly (NSPrivacyAccessedAPICategoryDiskSpace).
if grep -R -n -E 'systemUptime|creationDate|statfs|\bstat\(' "$REPOSITORY_ROOT/ios/Sources"; then
  echo "Potential required-reason API usage needs manifest review." >&2
  exit 1
fi

grep -R -n 'contentModificationDate' "$REPOSITORY_ROOT/ios/Sources/DataRights"
