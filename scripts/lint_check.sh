#!/usr/bin/env bash
set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$REPOSITORY_ROOT/scripts/versions.env"

SWIFTLINT_BIN_RECORD="$REPOSITORY_ROOT/.build-tools/swiftlint-$SWIFTLINT_VERSION/bin-path"
[[ -f "$SWIFTLINT_BIN_RECORD" ]] || {
  echo "Pinned SwiftLint is unavailable; run scripts/bootstrap.sh first." >&2
  exit 1
}
SWIFTLINT_BIN="$(cat "$SWIFTLINT_BIN_RECORD")"
[[ -x "$SWIFTLINT_BIN" ]] || {
  echo "Pinned SwiftLint binary is not executable: $SWIFTLINT_BIN" >&2
  exit 1
}

ACTUAL_VERSION="$("$SWIFTLINT_BIN" version)"
[[ "$ACTUAL_VERSION" == "$SWIFTLINT_VERSION" ]] || {
  echo "Expected SwiftLint $SWIFTLINT_VERSION, found $ACTUAL_VERSION" >&2
  exit 1
}

(
  cd "$REPOSITORY_ROOT"
  "$SWIFTLINT_BIN" lint --strict --config .swiftlint.yml
)
