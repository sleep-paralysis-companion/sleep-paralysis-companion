#!/usr/bin/env bash
set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

run_gate() {
  local gate_name="$1"
  shift
  echo "Running hosted verification gate: $gate_name"
  if "$@"; then
    return 0
  fi
  local gate_status=$?
  echo "::error title=Hosted iOS verification gate failed::$gate_name (exit $gate_status)"
  return "$gate_status"
}

run_gate select_xcode bash "$REPOSITORY_ROOT/scripts/select_xcode.sh"
run_gate bootstrap bash "$REPOSITORY_ROOT/scripts/bootstrap.sh"
run_gate format_check bash "$REPOSITORY_ROOT/scripts/format_check.sh"
run_gate lint_check bash "$REPOSITORY_ROOT/scripts/lint_check.sh"
run_gate static_check bash "$REPOSITORY_ROOT/scripts/static_check.sh"
run_gate privacy_manifest_check bash "$REPOSITORY_ROOT/scripts/privacy_manifest_check.sh"
run_gate secret_scan bash "$REPOSITORY_ROOT/scripts/secret_scan.sh"
run_gate prepare_simulator bash "$REPOSITORY_ROOT/scripts/prepare_simulator.sh"
run_gate build bash "$REPOSITORY_ROOT/scripts/build.sh"
run_gate unit_tests bash "$REPOSITORY_ROOT/scripts/unit_tests.sh"
run_gate ui_tests bash "$REPOSITORY_ROOT/scripts/ui_tests.sh"
