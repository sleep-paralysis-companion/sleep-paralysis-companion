#!/usr/bin/env bash
set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPOSITORY_ROOT"

SECRET_PATTERN='-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----|AKIA[0-9A-Z]{16}|ASIA[0-9A-Z]{16}|gh[pousr]_[A-Za-z0-9]{36,}|github_pat_[A-Za-z0-9_]{50,}|sb_secret_[A-Za-z0-9_-]{20,}|sk_(live|test)_[A-Za-z0-9]{20,}|eyJ[A-Za-z0-9_-]{20,}\.eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}'

if grep -R -I -n -E \
  --exclude-dir=.git \
  --exclude-dir=.build-tools \
  --exclude-dir=.generated \
  --exclude-dir=.temp \
  --exclude='*.docx' \
  -- "$SECRET_PATTERN" .; then
  echo "Potential secret found in the worktree." >&2
  exit 1
fi

while IFS= read -r commit; do
  if git grep -I -n -E -e "$SECRET_PATTERN" "$commit" -- . ':!*.docx'; then
    echo "Potential secret found in git history at $commit." >&2
    exit 1
  fi
done < <(git rev-list --all)

if grep -R -I -n -E 'service[_-]?role[[:space:]]*[:=][[:space:]]*[^[:space:]]+' ios; then
  echo "A service-role assignment was found in iOS runtime files." >&2
  exit 1
fi
