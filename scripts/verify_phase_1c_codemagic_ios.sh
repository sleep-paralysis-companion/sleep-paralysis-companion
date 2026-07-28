#!/usr/bin/env bash
set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULT_ROOT="$REPOSITORY_ROOT/ios/TestResults"
mkdir -p "$RESULT_ROOT"

EXPECTED_HEAD="${CM_COMMIT:?Codemagic did not provide CM_COMMIT}"
ACTUAL_HEAD="$(git -C "$REPOSITORY_ROOT" rev-parse HEAD)"
[[ "$ACTUAL_HEAD" == "$EXPECTED_HEAD" ]] || {
  echo "Codemagic checkout mismatch: expected $EXPECTED_HEAD, found $ACTUAL_HEAD" >&2
  exit 1
}

{
  printf 'provider=Codemagic\n'
  printf 'build_id=%s\n' "${CM_BUILD_ID:?Codemagic did not provide CM_BUILD_ID}"
  printf 'head_sha=%s\n' "$ACTUAL_HEAD"
  printf 'branch=%s\n' "${CM_BRANCH:?Codemagic did not provide CM_BRANCH}"
  sw_vers
  uname -m
} | tee "$RESULT_ROOT/CodemagicEnvironment.txt"

set +e
bash "$REPOSITORY_ROOT/scripts/verify_phase_1c_ci.sh"
verification_status=$?
set -e

if [[ -d "$RESULT_ROOT/UI.xcresult" ]]; then
  mkdir -p "$RESULT_ROOT/Screenshots"
  xcrun xcresulttool export attachments \
    --path "$RESULT_ROOT/UI.xcresult" \
    --output-path "$RESULT_ROOT/Screenshots" || {
      echo "Screenshot attachment export failed." >&2
      if [[ "$verification_status" -eq 0 ]]; then
        verification_status=1
      fi
    }
fi

exit "$verification_status"
