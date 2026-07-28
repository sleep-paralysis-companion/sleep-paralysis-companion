#!/usr/bin/env bash
set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

bash "$REPOSITORY_ROOT/scripts/phase_1c_contract_check.sh"
bash "$REPOSITORY_ROOT/scripts/verify_ci.sh"
