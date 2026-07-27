#!/usr/bin/env bash
set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

bash "$REPOSITORY_ROOT/scripts/select_xcode.sh"
bash "$REPOSITORY_ROOT/scripts/bootstrap.sh"
bash "$REPOSITORY_ROOT/scripts/format_check.sh"
bash "$REPOSITORY_ROOT/scripts/lint_check.sh"
bash "$REPOSITORY_ROOT/scripts/static_check.sh"
bash "$REPOSITORY_ROOT/scripts/privacy_manifest_check.sh"
bash "$REPOSITORY_ROOT/scripts/secret_scan.sh"
bash "$REPOSITORY_ROOT/scripts/build.sh"
bash "$REPOSITORY_ROOT/scripts/unit_tests.sh"
bash "$REPOSITORY_ROOT/scripts/ui_tests.sh"
