#!/usr/bin/env bash
set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="$REPOSITORY_ROOT/ios/Configurations/Local.xcconfig"

CONFIGURATION="Development"
MODE="auto"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --configuration)
      CONFIGURATION="$2"
      shift 2
      ;;
    --mode)
      MODE="$2"
      shift 2
      ;;
    --file)
      CONFIG_FILE="$2"
      shift 2
      ;;
    -h|--help)
      echo "Usage: $0 [--configuration Development|Staging|Production] [--mode warn|require] [--file <path>]"
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

# Determine enforcement mode
REQUIRE_AUTH=false
if [[ "$MODE" == "require" ]]; then
  REQUIRE_AUTH=true
elif [[ "$MODE" == "warn" ]]; then
  REQUIRE_AUTH=false
elif [[ "$CONFIGURATION" =~ ^(Production|Staging)$ ]]; then
  REQUIRE_AUTH=true
elif [[ "${SPC_REQUIRE_AUTH_CONFIG:-0}" == "1" ]]; then
  REQUIRE_AUTH=true
fi

# Security gate: check for service-role or secret key leakages
if [[ -f "$CONFIG_FILE" ]]; then
  if grep -E 'sb_secret_[A-Za-z0-9_-]+|service_role' "$CONFIG_FILE" >/dev/null 2>&1; then
    echo "::error title=Security Violation::Service-role or secret key detected in configuration. Only public/publishable keys are permitted in client builds." >&2
    echo "See docs/phase-1c/AUTH_CONFIG_PROVISIONING.md for security policy." >&2
    exit 1
  fi
fi

if [[ "$REQUIRE_AUTH" == "false" ]]; then
  if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Notice: Auth configuration is unprovisioned in $CONFIGURATION mode (Local.xcconfig absent). Sign-in will route to unavailable/mock provider."
    exit 0
  fi

  # In warn mode, if file exists, check if key is empty
  KEY_LINE="$(grep -E '^[[:space:]]*SPC_SUPABASE_PUBLISHABLE_KEY[[:space:]]*=' "$CONFIG_FILE" 2>/dev/null || true)"
  KEY_VAL="$(printf '%s' "$KEY_LINE" | sed -E 's/^[[:space:]]*SPC_SUPABASE_PUBLISHABLE_KEY[[:space:]]*=[[:space:]]*//; s/[[:space:]]*\/\/.*$//; s/[[:space:]]+$//')"
  if [[ -z "$KEY_VAL" || "$KEY_VAL" == "sb_publishable_replace_with_project_key" ]]; then
    echo "Notice: SPC_SUPABASE_PUBLISHABLE_KEY is unset or placeholder in $CONFIGURATION mode. Sign-in will route to unavailable/mock provider."
    exit 0
  fi
fi

# Strict validation for Staging/Production / required mode
if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "::error title=Auth Configuration Missing::ios/Configurations/Local.xcconfig was not found. $CONFIGURATION builds require provisioned authentication configuration." >&2
  echo "See docs/phase-1c/AUTH_CONFIG_PROVISIONING.md for provisioning instructions." >&2
  exit 1
fi

KEY_LINE="$(grep -E '^[[:space:]]*SPC_SUPABASE_PUBLISHABLE_KEY[[:space:]]*=' "$CONFIG_FILE" 2>/dev/null || true)"
KEY_VAL="$(printf '%s' "$KEY_LINE" | sed -E 's/^[[:space:]]*SPC_SUPABASE_PUBLISHABLE_KEY[[:space:]]*=[[:space:]]*//; s/[[:space:]]*\/\/.*$//; s/[[:space:]]+$//')"

if [[ -z "$KEY_VAL" ]]; then
  echo "::error title=Missing Supabase Key::SPC_SUPABASE_PUBLISHABLE_KEY is empty in Local.xcconfig. $CONFIGURATION builds require a valid publishable key." >&2
  echo "See docs/phase-1c/AUTH_CONFIG_PROVISIONING.md for provisioning instructions." >&2
  exit 1
fi

if [[ "$KEY_VAL" == "sb_publishable_replace_with_project_key" ]]; then
  echo "::error title=Placeholder Supabase Key::SPC_SUPABASE_PUBLISHABLE_KEY in Local.xcconfig contains the example placeholder." >&2
  echo "See docs/phase-1c/AUTH_CONFIG_PROVISIONING.md for provisioning instructions." >&2
  exit 1
fi

# Validate key format: accepts sb_publishable_ prefix or eyJ prefix with length > 20
if ! [[ "$KEY_VAL" =~ ^(sb_publishable_[A-Za-z0-9_-]{20,}|eyJ[A-Za-z0-9_-]{20,})$ ]]; then
  echo "::error title=Invalid Supabase Key Format::SPC_SUPABASE_PUBLISHABLE_KEY is malformed (must start with 'sb_publishable_' or 'eyJ' and exceed 20 characters)." >&2
  echo "See docs/phase-1c/AUTH_CONFIG_PROVISIONING.md for provisioning instructions." >&2
  exit 1
fi

REDIRECT_LINE="$(grep -E '^[[:space:]]*SPC_OAUTH_REDIRECT_URL[[:space:]]*=' "$CONFIG_FILE" 2>/dev/null || true)"
REDIRECT_VAL="$(printf '%s' "$REDIRECT_LINE" | sed -E 's/^[[:space:]]*SPC_OAUTH_REDIRECT_URL[[:space:]]*=[[:space:]]*//; s/[[:space:]]*\/\/.*$//; s/[[:space:]]+$//')"

if [[ -z "$REDIRECT_VAL" ]]; then
  echo "::error title=Missing Redirect URL::SPC_OAUTH_REDIRECT_URL is empty in Local.xcconfig. $CONFIGURATION builds require an approved redirect URL." >&2
  echo "See docs/phase-1c/AUTH_CONFIG_PROVISIONING.md for provisioning instructions." >&2
  exit 1
fi

NORMALIZED_REDIRECT="$(printf '%s' "$REDIRECT_VAL" | sed -E 's|:/\$\(\)/|://|g; s|://+|://|g')"
if [[ "$NORMALIZED_REDIRECT" != "spc://auth/callback" ]]; then
  echo "::error title=Invalid Redirect URL::SPC_OAUTH_REDIRECT_URL must match approved redirect 'spc://auth/callback' (found unapproved redirect scheme/host)." >&2
  echo "See docs/phase-1c/AUTH_CONFIG_PROVISIONING.md for provisioning instructions." >&2
  exit 1
fi

echo "Auth configuration preflight passed ($CONFIGURATION / mode: $MODE)."
