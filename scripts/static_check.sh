#!/usr/bin/env bash
set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_ROOT="$REPOSITORY_ROOT/ios/Sources"
RESOURCE_ROOT="$REPOSITORY_ROOT/ios/Resources"

FORBIDDEN_SOURCE='@unchecked[[:space:]]+Sendable|nonisolated\(unsafe\)|Task\.detached|DispatchSemaphore|import[[:space:]]+(RevenueCat|StoreKit|AlarmKit|AVFoundation|HealthKit|AdSupport)|UserDefaults|URLSession|try!|as!'
FORBIDDEN_RESOURCE='NSMicrophoneUsageDescription|NSHealthShareUsageDescription|NSHealthUpdateUsageDescription|NSUserTrackingUsageDescription|UIBackgroundModes'

if grep -R -n -E "$FORBIDDEN_SOURCE" "$SOURCE_ROOT"; then
  echo "Forbidden Phase 1B source pattern found." >&2
  exit 1
fi

if grep -R -l -E 'import[[:space:]]+Supabase' "$SOURCE_ROOT" \
  | grep -v -E '/(Authentication|RemoteData)/|/DataRights/SupabaseAccountDeletionGateway\.swift$'; then
  echo "Supabase import escaped the authentication or remote-data boundary." >&2
  exit 1
fi

if grep -R -l -E '\bFileManager\b' "$SOURCE_ROOT" \
  | grep -v -E '/DataRights/|/PlatformInterfaces/(DataProtection|LocalStoreLocation)\.swift$'; then
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
  -type f \( -name '*.entitlements' -o -name '*.mobileprovision' -o -name '*.p8' \) \
  -print | grep -q .; then
  echo "Unexpected entitlement or credential file found." >&2
  exit 1
fi

grep -Fx "SPC_BUNDLE_IDENTIFIER = com.satyamshree.spc.dev" \
  "$REPOSITORY_ROOT/ios/Configurations/Development.xcconfig"
grep -Fx "SPC_BUNDLE_IDENTIFIER = com.satyamshree.spc.staging" \
  "$REPOSITORY_ROOT/ios/Configurations/Staging.xcconfig"
grep -Fx "SPC_BUNDLE_IDENTIFIER = com.satyamshree.spc" \
  "$REPOSITORY_ROOT/ios/Configurations/Production.xcconfig"
grep -Fx "IPHONEOS_DEPLOYMENT_TARGET = 26.0" \
  "$REPOSITORY_ROOT/ios/Configurations/Base.xcconfig"

grep -Fq 'exactVersion: 7.11.1' "$REPOSITORY_ROOT/ios/project.yml"
grep -Fq 'exactVersion: 2.53.0' "$REPOSITORY_ROOT/ios/project.yml"

if grep -R -n -E 'https?://|nfzvlvukbeapcnlmyecf' \
  "$REPOSITORY_ROOT/ios/Configurations/"*.xcconfig; then
  echo "Committed runtime configuration contains a host or live project reference." >&2
  exit 1
fi
