#!/usr/bin/env bash
set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_ROOT="$REPOSITORY_ROOT/ios/Sources"
RESOURCE_ROOT="$REPOSITORY_ROOT/ios/Resources"

for required in \
  "$SOURCE_ROOT/Authentication/OAuthSessionService.swift" \
  "$SOURCE_ROOT/Features/Onboarding/IntegratedOnboardingViews.swift" \
  "$SOURCE_ROOT/Features/Audio/PersonalAudioViews.swift" \
  "$SOURCE_ROOT/Features/Grounding/GroundingView.swift" \
  "$SOURCE_ROOT/Features/CheckIn/MorningCheckInView.swift" \
  "$SOURCE_ROOT/SleepSchedule/SleepReminderService.swift" \
  "$REPOSITORY_ROOT/ios/Widget/ParaluxManualEpisodeWidget.swift"
do
  [[ -f "$required" ]] || {
    echo "Missing integrated Phase 1 source: $required" >&2
    exit 1
  }
done

grep -Fq 'case authentication' "$SOURCE_ROOT/Domain/AppRoute.swift"
grep -Fq 'case question(QuestionnaireQuestion)' "$SOURCE_ROOT/Domain/AppRoute.swift"
grep -Fq 'case recommendedSetup' "$SOURCE_ROOT/Domain/AppRoute.swift"
grep -Fq 'case personalAudio' "$SOURCE_ROOT/Domain/AppRoute.swift"
grep -Fq 'case sleepSchedule' "$SOURCE_ROOT/Domain/AppRoute.swift"
grep -Fq 'static let openAppWhenRun = true' "$SOURCE_ROOT/AppIntents/ManualEpisodeIntent.swift"
grep -Fq 'NSMicrophoneUsageDescription' "$RESOURCE_ROOT/Info.plist"

if grep -R -n -i -E \
  '\b(paywall|free trial|trial eligible|per month|per year|subscribe now)\b' \
  "$SOURCE_ROOT/Features" \
  "$RESOURCE_ROOT/en.lproj"; then
  echo "Unapproved commerce copy found in Phase 1." >&2
  exit 1
fi

if grep -R -n -i -E \
  'detects sleep paralysis|prevents sleep paralysis|treats sleep paralysis|automatically detects' \
  "$SOURCE_ROOT/Features" \
  "$RESOURCE_ROOT/en.lproj"; then
  echo "Prohibited medical or automatic-detection claim found." >&2
  exit 1
fi

if grep -R -n -E \
  '(originalFileName|originalFilename|remoteAudio|audioBucket|audioPath|audioTranscript|waveform|embedding)' \
  "$SOURCE_ROOT/RemoteData" \
  "$SOURCE_ROOT/Synchronization"; then
  echo "Personal-audio bytes or identifying metadata crossed the remote boundary." >&2
  exit 1
fi

if find "$REPOSITORY_ROOT/ios" \
  -path "$REPOSITORY_ROOT/ios/.generated" -prune -o \
  -type f \( -name '*.mobileprovision' -o -name '*.p8' \) \
  -print | grep -q .; then
  echo "Unexpected signing or provider credential resource found." >&2
  exit 1
fi

bash "$REPOSITORY_ROOT/scripts/static_check.sh"
