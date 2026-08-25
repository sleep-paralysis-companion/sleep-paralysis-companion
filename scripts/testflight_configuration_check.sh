#!/usr/bin/env bash
set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKFLOW="$REPOSITORY_ROOT/.github/workflows/testflight-internal.yml"
EXPORT_OPTIONS="$REPOSITORY_ROOT/ios/ExportOptions-TestFlight.plist"
PROJECT_SPEC="$REPOSITORY_ROOT/ios/project.yml"
PRODUCTION_CONFIG="$REPOSITORY_ROOT/ios/Configurations/Production.xcconfig"

plutil -lint \
  "$EXPORT_OPTIONS" \
  "$REPOSITORY_ROOT/ios/Resources/Info.plist" \
  "$REPOSITORY_ROOT/ios/Widget/Info.plist" \
  "$REPOSITORY_ROOT/ios/Resources/PrivacyInfo.xcprivacy" \
  "$REPOSITORY_ROOT/ios/Resources/SleepParalysisCompanion.entitlements" \
  "$REPOSITORY_ROOT/ios/Widget/SPCWidgetExtension.entitlements"

python3 -m json.tool \
  "$REPOSITORY_ROOT/ios/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json" \
  >/dev/null

grep -Fxq 'SPC_BUNDLE_IDENTIFIER = app.sleepcompanion.spc' "$PRODUCTION_CONFIG"
grep -Fq 'APP_BUNDLE_ID: app.sleepcompanion.spc' "$WORKFLOW"
grep -Fq 'WIDGET_BUNDLE_ID: app.sleepcompanion.spc.widget' "$WORKFLOW"
grep -Fq '<key>app.sleepcompanion.spc</key>' "$EXPORT_OPTIONS"
grep -Fq '<string>Sleep Paralysis Companion - App Store</string>' "$EXPORT_OPTIONS"
grep -Fq '<key>app.sleepcompanion.spc.widget</key>' "$EXPORT_OPTIONS"
grep -Fq '<string>Sleep Paralysis Companion Widget - App Store</string>' "$EXPORT_OPTIONS"
grep -Fq '<string>app-store-connect</string>' "$EXPORT_OPTIONS"
grep -Fq 'PROVISIONING_PROFILE_SPECIFIER: "Sleep Paralysis Companion - App Store"' "$PROJECT_SPEC"
grep -Fq 'PROVISIONING_PROFILE_SPECIFIER: "Sleep Paralysis Companion Widget - App Store"' "$PROJECT_SPEC"
grep -Fq 'ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon' "$PROJECT_SPEC"
grep -Fq '"idiom" : "ios-marketing"' \
  "$REPOSITORY_ROOT/ios/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json"
[[ "$(plutil -extract ITSAppUsesNonExemptEncryption raw -o - \
  "$REPOSITORY_ROOT/ios/Resources/Info.plist")" == "false" ]]
grep -Fq 'SPC_APP_GROUP_IDENTIFIER = group.$(SPC_BUNDLE_IDENTIFIER)' \
  "$REPOSITORY_ROOT/ios/Configurations/Base.xcconfig"

if grep -Eq 'com\.sleepcompanion\.spc' "$WORKFLOW" "$EXPORT_OPTIONS"; then
  echo "Legacy production bundle identifiers remain in the TestFlight configuration." >&2
  exit 1
fi

if ! grep -Eq '^    MARKETING_VERSION: [0-9]+\.[0-9]+\.[0-9]+$' "$PROJECT_SPEC"; then
  echo "MARKETING_VERSION must be a three-component numeric version." >&2
  exit 1
fi

if ! grep -Eq '^    CURRENT_PROJECT_VERSION: [1-9][0-9]*$' "$PROJECT_SPEC"; then
  echo "CURRENT_PROJECT_VERSION must be a positive integer." >&2
  exit 1
fi

echo "TestFlight repository configuration is internally consistent."
