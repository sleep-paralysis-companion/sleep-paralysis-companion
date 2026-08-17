#!/usr/bin/env bash
set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_ROOT="$REPOSITORY_ROOT/ios/Sources"
RESOURCE_ROOT="$REPOSITORY_ROOT/ios/Resources"

FORBIDDEN_SOURCE='@unchecked[[:space:]]+Sendable|nonisolated\(unsafe\)|Task\.detached|DispatchSemaphore|import[[:space:]]+(RevenueCat|StoreKit|HealthKit|AdSupport)|try!|as!'
FORBIDDEN_RESOURCE='NSHealthShareUsageDescription|NSHealthUpdateUsageDescription|NSUserTrackingUsageDescription|UIBackgroundModes'

if grep -R -n -E "$FORBIDDEN_SOURCE" "$SOURCE_ROOT"; then
  echo "Forbidden Phase 1B source pattern found." >&2
  exit 1
fi

if grep -R -l -E '\bURLSession\b' "$SOURCE_ROOT" \
  | grep -F -v -E '/Audio/'; then
  echo "Networking may only be used by the provider-neutral audio boundary." >&2
  exit 1
fi

if grep -R -n -E 'import[[:space:]]+AVFoundation' "$SOURCE_ROOT/Features"; then
  echo "SwiftUI features may not import AVFoundation." >&2
  exit 1
fi

ALARMKIT_SOURCE="$SOURCE_ROOT/SleepSchedule/WakeAlarmService.swift"
if grep -R -l -E 'import[[:space:]]+AlarmKit' "$SOURCE_ROOT" \
  | grep -F -v -x "$ALARMKIT_SOURCE"; then
  echo "AlarmKit may only be used by the wake-alarm scheduling boundary." >&2
  exit 1
fi

if grep -R -l -E 'import[[:space:]]+Supabase' "$SOURCE_ROOT" \
  | grep -v -E '/(Authentication|Configuration|RemoteData)/|/DataRights/SupabaseAccountDeletionGateway\.swift$'; then
  echo "Supabase import escaped the authentication or remote-data boundary." >&2
  exit 1
fi

if grep -R -l -E '\bFileManager\b' "$SOURCE_ROOT" \
  | grep -v -E '/App/AppModel\.swift$|/Audio/|/DataRights/|/PersonalAudio/|/PlatformInterfaces/(DataProtection|LocalStoreLocation)\.swift$'; then
  echo "File access escaped the data-rights boundary." >&2
  exit 1
fi

if grep -R -n -E "$FORBIDDEN_RESOURCE" "$RESOURCE_ROOT"; then
  echo "Forbidden entitlement or permission key found." >&2
  exit 1
fi

if grep -R -n -E \
  'ProviderGrantCredential|appleAuthorizationCode|googleOAuthAccessToken|provider-revocation-proof' \
  "$SOURCE_ROOT/LocalPersistence" \
  "$SOURCE_ROOT/DataRights/ExportFoundation.swift" \
  "$RESOURCE_ROOT"; then
  echo "Provider revocation credential escaped its ephemeral authentication boundary." >&2
  exit 1
fi

if grep -R -n -E '\b(Logger|os_log|print)\b' \
  "$SOURCE_ROOT/Authentication" \
  "$SOURCE_ROOT/DataRights/SupabaseAccountDeletionGateway.swift"; then
  echo "Authentication or provider credentials could cross a logging boundary." >&2
  exit 1
fi

if find "$REPOSITORY_ROOT/ios" \
  -path "$REPOSITORY_ROOT/ios/.generated" -prune -o \
  -type f \( -name '*.mobileprovision' -o -name '*.p8' \) \
  -print | grep -q .; then
  echo "Unexpected signing or provider credential file found." >&2
  exit 1
fi

while IFS= read -r entitlement; do
  case "$entitlement" in
    "$REPOSITORY_ROOT/ios/Resources/SleepParalysisCompanion.entitlements" | \
    "$REPOSITORY_ROOT/ios/Widget/SPCWidgetExtension.entitlements")
      grep -Fq 'com.apple.security.application-groups' "$entitlement"
      grep -Fq '$(SPC_APP_GROUP_IDENTIFIER)' "$entitlement"
      ;;
    *)
      echo "Unexpected entitlement file found: $entitlement" >&2
      exit 1
      ;;
  esac
done < <(
  find "$REPOSITORY_ROOT/ios" \
    -path "$REPOSITORY_ROOT/ios/.generated" -prune -o \
    -type f -name '*.entitlements' -print
)

grep -Fx "SPC_BUNDLE_IDENTIFIER = app.sleepcompanion.spc.dev" \
  "$REPOSITORY_ROOT/ios/Configurations/Development.xcconfig"
grep -Fx "SPC_BUNDLE_IDENTIFIER = app.sleepcompanion.spc.staging" \
  "$REPOSITORY_ROOT/ios/Configurations/Staging.xcconfig"
grep -Fx "SPC_BUNDLE_IDENTIFIER = app.sleepcompanion.spc" \
  "$REPOSITORY_ROOT/ios/Configurations/Production.xcconfig"
grep -Fx "IPHONEOS_DEPLOYMENT_TARGET = 26.0" \
  "$REPOSITORY_ROOT/ios/Configurations/Base.xcconfig"

grep -Fq 'exactVersion: 7.11.1' "$REPOSITORY_ROOT/ios/project.yml"
grep -Fq 'exactVersion: 2.53.0' "$REPOSITORY_ROOT/ios/project.yml"

if ! grep -Fq 'SPC_SUPABASE_URL = https:/$()/nfzvlvukbeapcnlmyecf.supabase.co' \
  "$REPOSITORY_ROOT/ios/Configurations/Base.xcconfig"; then
  echo "The authorized public Supabase project URL is missing." >&2
  exit 1
fi

if grep -R -n -E 'SPC_SUPABASE_PUBLISHABLE_KEY[[:space:]]*=[[:space:]]*(sb_publishable_[A-Za-z0-9_-]{20,}|eyJ[A-Za-z0-9_-]{20,})' \
  "$REPOSITORY_ROOT/ios/Configurations/Base.xcconfig"; then
  echo "A concrete public client key must remain developer-local." >&2
  exit 1
fi
