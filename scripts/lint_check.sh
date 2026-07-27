#!/usr/bin/env bash
set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$REPOSITORY_ROOT/scripts/versions.env"

ACTUAL_VERSION="$(swiftlint version)"
[[ "$ACTUAL_VERSION" == "$SWIFTLINT_VERSION" ]] || {
  echo "Expected SwiftLint $SWIFTLINT_VERSION, found $ACTUAL_VERSION" >&2
  exit 1
}

(
  cd "$REPOSITORY_ROOT"
  swiftlint lint --strict --config .swiftlint.yml
)
