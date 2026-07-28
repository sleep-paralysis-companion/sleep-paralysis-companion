#!/usr/bin/env bash
set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$REPOSITORY_ROOT/scripts/versions.env"
cd "$REPOSITORY_ROOT"

if grep -R -n -E 'nfzvlvukbeapcnlmyecf|public\.waitlist|CREATE[[:space:]]+TABLE[[:space:]]+.*waitlist' \
  supabase .github/workflows; then
  echo "Live project or waitlist reference found in executable backend files." >&2
  exit 1
fi

SUPABASE=(npx --yes "supabase@$SUPABASE_CLI_VERSION")
[[ "$("${SUPABASE[@]}" --version)" == "$SUPABASE_CLI_VERSION" ]]

cleanup() {
  "${SUPABASE[@]}" stop --no-backup >/dev/null 2>&1 || true
}
trap cleanup EXIT

"${SUPABASE[@]}" start \
  -x studio,imgproxy,inbucket,storage-api,edge-runtime,logflare,vector,supavisor
"${SUPABASE[@]}" db reset --local
"${SUPABASE[@]}" test db
"${SUPABASE[@]}" db lint --local --level warning --fail-on error

deno fmt --check supabase/functions
deno lint supabase/functions
deno test --allow-env --allow-net supabase/functions/delete-account/handler_test.ts

bash scripts/secret_scan.sh
