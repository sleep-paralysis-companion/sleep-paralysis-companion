#!/usr/bin/env bash
set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$REPOSITORY_ROOT/scripts/versions.env"
RESULT_ROOT="$REPOSITORY_ROOT/supabase/TestResults"
mkdir -p "$RESULT_ROOT"

EXPECTED_HEAD="${CM_COMMIT:?Codemagic did not provide CM_COMMIT}"
ACTUAL_HEAD="$(git -C "$REPOSITORY_ROOT" rev-parse HEAD)"
[[ "$ACTUAL_HEAD" == "$EXPECTED_HEAD" ]] || {
  echo "Codemagic checkout mismatch: expected $EXPECTED_HEAD, found $ACTUAL_HEAD" >&2
  exit 1
}

curl --fail --silent --show-error --location https://deno.land/install.sh \
  | sh -s "v$DENO_VERSION"
export PATH="$HOME/.deno/bin:$PATH"

{
  printf 'provider=Codemagic\n'
  printf 'build_id=%s\n' "${CM_BUILD_ID:?Codemagic did not provide CM_BUILD_ID}"
  printf 'head_sha=%s\n' "$ACTUAL_HEAD"
  printf 'branch=%s\n' "${CM_BRANCH:?Codemagic did not provide CM_BRANCH}"
  uname -a
  docker version
  node --version
  deno --version
} | tee "$RESULT_ROOT/CodemagicEnvironment.txt"

bash "$REPOSITORY_ROOT/scripts/verify_backend_ci.sh"
