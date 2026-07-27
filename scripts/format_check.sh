#!/usr/bin/env bash
set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$REPOSITORY_ROOT/scripts/versions.env"

ACTUAL_VERSION="$(swiftformat --version)"
[[ "$ACTUAL_VERSION" == "$SWIFTFORMAT_VERSION" ]] || {
  echo "Expected SwiftFormat $SWIFTFORMAT_VERSION, found $ACTUAL_VERSION" >&2
  exit 1
}

swiftformat "$REPOSITORY_ROOT/ios/Sources" "$REPOSITORY_ROOT/ios/Tests" \
  --config "$REPOSITORY_ROOT/.swiftformat" \
  --lint
