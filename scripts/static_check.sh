#!/usr/bin/env bash
set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_ROOT="$REPOSITORY_ROOT/ios/Sources"
RESOURCE_ROOT="$REPOSITORY_ROOT/ios/Resources"

FORBIDDEN_SOURCE='@unchecked[[:space:]]+Sendable|nonisolated\(unsafe\)|Task\.detached|DispatchSemaphore|import[[:space:]]+(Supabase|RevenueCat|StoreKit|AlarmKit|AVFoundation|HealthKit|AdSupport)|UserDefaults|FileManager|URLSession|try!|as!'
FORBIDDEN_RESOURCE='NSMicrophoneUsageDescription|NSHealthShareUsageDescription|NSHealthUpdateUsageDescription|NSUserTrackingUsageDescription|UIBackgroundModes'

if grep -R -n -E "$FORBIDDEN_SOURCE" "$SOURCE_ROOT"; then
  echo "Forbidden Phase 1A source pattern found." >&2
  exit 1
fi

if grep -R -n -E "$FORBIDDEN_RESOURCE" "$RESOURCE_ROOT"; then
  echo "Forbidden entitlement or permission key found." >&2
  exit 1
fi

if find "$REPOSITORY_ROOT/ios" -type f \( -name '*.entitlements' -o -name '*.mobileprovision' -o -name '*.p8' \) | grep -q .; then
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

if grep -R -n -E 'https?://|nfzvlvukbeapcnlmyecf' \
  "$REPOSITORY_ROOT/ios/Configurations/"*.xcconfig; then
  echo "Committed runtime configuration contains a host or live project reference." >&2
  exit 1
fi
