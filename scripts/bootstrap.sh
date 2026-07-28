#!/usr/bin/env bash
set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$REPOSITORY_ROOT/scripts/versions.env"

SWIFTLINT_ROOT="$REPOSITORY_ROOT/.build-tools/swiftlint-$SWIFTLINT_VERSION"
SWIFTLINT_BIN_RECORD="$SWIFTLINT_ROOT/bin-path"
if [[ ! -f "$SWIFTLINT_BIN_RECORD" ]] || [[ ! -x "$(cat "$SWIFTLINT_BIN_RECORD" 2>/dev/null || true)" ]]; then
  rm -rf "$SWIFTLINT_ROOT"
  mkdir -p "$SWIFTLINT_ROOT/extracted"
  SWIFTLINT_ARCHIVE="$SWIFTLINT_ROOT/portable_swiftlint.zip"
  curl --fail --location --retry 3 \
    "https://github.com/realm/SwiftLint/releases/download/$SWIFTLINT_VERSION/portable_swiftlint.zip" \
    --output "$SWIFTLINT_ARCHIVE"
  echo "$SWIFTLINT_SHA256  $SWIFTLINT_ARCHIVE" | shasum --algorithm 256 --check
  ditto -x -k "$SWIFTLINT_ARCHIVE" "$SWIFTLINT_ROOT/extracted"
  SWIFTLINT_BIN="$(find "$SWIFTLINT_ROOT/extracted" -type f -name swiftlint | head -n 1)"
  [[ -n "$SWIFTLINT_BIN" ]] || {
    echo "Pinned SwiftLint archive did not contain the expected binary." >&2
    exit 1
  }
  chmod +x "$SWIFTLINT_BIN"
  printf '%s\n' "$SWIFTLINT_BIN" >"$SWIFTLINT_BIN_RECORD"
fi

SWIFTLINT_BIN="$(cat "$SWIFTLINT_BIN_RECORD")"
[[ "$("$SWIFTLINT_BIN" version)" == "$SWIFTLINT_VERSION" ]]

XCODEGEN_ROOT="$REPOSITORY_ROOT/.build-tools/xcodegen-$XCODEGEN_VERSION"
XCODEGEN_BIN_RECORD="$XCODEGEN_ROOT/bin-path"
if [[ ! -f "$XCODEGEN_BIN_RECORD" ]] || [[ ! -x "$(cat "$XCODEGEN_BIN_RECORD" 2>/dev/null || true)" ]]; then
  rm -rf "$XCODEGEN_ROOT"
  mkdir -p "$XCODEGEN_ROOT/extracted"
  XCODEGEN_ARCHIVE="$XCODEGEN_ROOT/xcodegen.zip"
  curl --fail --location --retry 3 \
    "https://github.com/yonaskolb/XcodeGen/releases/download/$XCODEGEN_VERSION/xcodegen.zip" \
    --output "$XCODEGEN_ARCHIVE"
  echo "$XCODEGEN_SHA256  $XCODEGEN_ARCHIVE" | shasum --algorithm 256 --check
  ditto -x -k "$XCODEGEN_ARCHIVE" "$XCODEGEN_ROOT/extracted"
  XCODEGEN_BIN="$(find "$XCODEGEN_ROOT/extracted" -type f -name xcodegen | head -n 1)"
  [[ -n "$XCODEGEN_BIN" ]] || {
    echo "Pinned XcodeGen archive did not contain the expected binary." >&2
    exit 1
  }
  chmod +x "$XCODEGEN_BIN"
  printf '%s\n' "$XCODEGEN_BIN" >"$XCODEGEN_BIN_RECORD"
fi

XCODEGEN_BIN="$(cat "$XCODEGEN_BIN_RECORD")"
[[ "$("$XCODEGEN_BIN" --version)" == "Version: $XCODEGEN_VERSION" ]]

(
  cd "$REPOSITORY_ROOT/ios"
  "$XCODEGEN_BIN" generate --spec project.yml
  xcodebuild \
    -project SleepParalysisCompanion.xcodeproj \
    -resolvePackageDependencies \
    -clonedSourcePackagesDirPath .generated/SourcePackages
  xcodebuild -project SleepParalysisCompanion.xcodeproj -list
)
