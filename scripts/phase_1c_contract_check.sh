#!/usr/bin/env bash
set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_ROOT="$REPOSITORY_ROOT/ios/Sources"
RESOURCE_ROOT="$REPOSITORY_ROOT/ios/Resources"
ONBOARDING_MODEL="$SOURCE_ROOT/Domain/OnboardingModels.swift"
LOCALIZATIONS="$RESOURCE_ROOT/en.lproj/Localizable.strings"

CLAIM_001='Sleep Paralysis Companion is a nonmedical wellness tool. It does not diagnose, detect, monitor, predict, prevent, or treat sleep paralysis, and it is not an emergency service.'
CLAIM_002='The app responds only when you choose an action or enter information.'

[[ "$(grep -Fxc "\"notice.claim.001\" = \"$CLAIM_001\";" "$LOCALIZATIONS")" == "1" ]]
[[ "$(grep -Fxc "\"notice.claim.002\" = \"$CLAIM_002\";" "$LOCALIZATIONS")" == "1" ]]

for field in \
  localProfileID \
  profileCreatedAt \
  productNoticeVersion \
  productNoticeSeenAt \
  onboardingCompletedAt
do
  grep -Eq "let[[:space:]]+$field:" "$ONBOARDING_MODEL"
done

[[ "$(sed -n '/struct OnboardingProfile:/,/^}/p' "$ONBOARDING_MODEL" \
  | grep -Ec '^[[:space:]]+let[[:space:]]+[A-Za-z]')" == "5" ]]

if grep -R -n -E \
  'import[[:space:]]+(RevenueCat|StoreKit|AlarmKit|AVFoundation|HealthKit|UserNotifications)' \
  "$SOURCE_ROOT"; then
  echo "A forbidden Phase 1C framework crossed the source boundary." >&2
  exit 1
fi

if grep -R -n -E \
  '\b(requestAuthorization|requestAccess|UNUserNotificationCenter|URLSession)\b' \
  "$SOURCE_ROOT/App" \
  "$SOURCE_ROOT/Features" \
  "$SOURCE_ROOT/LocalPersistence/LocalOnboardingProfileStore.swift"; then
  echo "Onboarding or ordinary launch can request permission or network access." >&2
  exit 1
fi

if grep -R -n -E \
  'import[[:space:]]+Supabase|SynchronizationEngine|ProductionSynchronizationComposition' \
  "$SOURCE_ROOT/App" \
  "$SOURCE_ROOT/Features" \
  "$SOURCE_ROOT/LocalPersistence/LocalOnboardingProfileStore.swift"; then
  echo "Authentication or synchronization escaped its explicit future route." >&2
  exit 1
fi

if grep -R -n -i -E \
  '\b(paywall|free trial|trial eligible|per month|per year|subscribe now)\b' \
  "$SOURCE_ROOT/Features" \
  "$LOCALIZATIONS"; then
  echo "Unapproved commerce copy found in Phase 1C presentation." >&2
  exit 1
fi

if grep -R -n -i -E \
  '\b(questionnaire|medication|episode frequency|voice preference|marketing consent)\b' \
  "$SOURCE_ROOT/Features/Onboarding" \
  "$SOURCE_ROOT/App/AppModel.swift" \
  "$ONBOARDING_MODEL"; then
  echo "Prohibited onboarding collection concept found." >&2
  exit 1
fi

if grep -R -n -i -E \
  'detects sleep paralysis|prevents sleep paralysis|treats sleep paralysis|wakes you during|emergency response' \
  "$SOURCE_ROOT/Features" \
  "$LOCALIZATIONS"; then
  echo "Prohibited product claim found." >&2
  exit 1
fi

if find "$REPOSITORY_ROOT/ios" \
  -path "$REPOSITORY_ROOT/ios/.generated" -prune -o \
  -type f \( -name '*.entitlements' -o -name '*.mobileprovision' -o -name '*.p8' \) \
  -print | grep -q .; then
  echo "Unexpected permission, signing, or provider resource found." >&2
  exit 1
fi

if grep -n -E \
  'ios_signing|app_store_connect|submit_to_testflight|submit_to_app_store|publishing:' \
  "$REPOSITORY_ROOT/codemagic.yaml"; then
  echo "Codemagic Phase 1C verification must not sign or publish." >&2
  exit 1
fi

bash "$REPOSITORY_ROOT/scripts/static_check.sh"
