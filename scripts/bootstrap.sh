#!/usr/bin/env bash
set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$REPOSITORY_ROOT/scripts/versions.env"

TOOL_ROOT="$REPOSITORY_ROOT/.build-tools/xcodegen-$XCODEGEN_VERSION"
SOURCE_ROOT="$TOOL_ROOT/source"
BIN_RECORD="$TOOL_ROOT/bin-path"

if [[ ! -f "$BIN_RECORD" ]] || [[ ! -x "$(cat "$BIN_RECORD" 2>/dev/null || true)/xcodegen" ]]; then
  rm -rf "$TOOL_ROOT"
  mkdir -p "$TOOL_ROOT"
  git clone \
    --branch "$XCODEGEN_VERSION" \
    --depth 1 \
    https://github.com/yonaskolb/XcodeGen.git \
    "$SOURCE_ROOT"

  ACTUAL_COMMIT="$(git -C "$SOURCE_ROOT" rev-parse HEAD)"
  [[ "$ACTUAL_COMMIT" == "$XCODEGEN_COMMIT" ]] || {
    echo "XcodeGen provenance mismatch: $ACTUAL_COMMIT" >&2
    exit 1
  }

  swift build --package-path "$SOURCE_ROOT" --configuration release --product xcodegen
  swift build --package-path "$SOURCE_ROOT" --configuration release --show-bin-path >"$BIN_RECORD"
fi

XCODEGEN_BIN="$(cat "$BIN_RECORD")/xcodegen"
[[ "$("$XCODEGEN_BIN" --version)" == "Version: $XCODEGEN_VERSION" ]]

(
  cd "$REPOSITORY_ROOT/ios"
  "$XCODEGEN_BIN" generate --spec project.yml
  xcodebuild -project SleepParalysisCompanion.xcodeproj -list
)
