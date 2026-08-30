# Authentication Configuration Provisioning Runbook

This document defines the contract, provisioning mechanism, security boundaries, CI setup, and failure-mode resolutions for Supabase authentication configuration in Sleep Paralysis Companion.

---

## 1. Overview & Problem Statement

Client authentication in Sleep Paralysis Companion requires public Supabase runtime configuration:
- Project URL (`SPCSupabaseURL` in `Info.plist`)
- Publishable/anon client key (`SPCSupabasePublishableKey` in `Info.plist`)
- OAuth callback redirect URL (`SPCSupabaseOAuthRedirectURL` in `Info.plist`)

These keys are read at runtime by `SupabasePublicConfiguration.load(from: Bundle)` (`ios/Sources/Configuration/SupabasePublicConfiguration.swift`).

### The Missing Configuration Failure Mode
In `ios/Configurations/Base.xcconfig`, default keys are blank and `Local.xcconfig` is included via `#include? "Local.xcconfig"`. Because `Local.xcconfig` is gitignored:
1. A clean checkout has no `Local.xcconfig`.
2. Xcode builds and archives without compiler errors (the `?` in `#include?` causes missing files to be silently ignored).
3. At runtime, `SupabasePublicConfiguration.load(from: .main)` returns `nil` because the key and redirect URL are empty.
4. `AppCompositionRoot.swift` resolves authentication to `UnavailableOAuthSessionService`, presenting the user-facing notice: *"Provider sign-in will be available once configuration is complete."*

**Goal**: Prevent Staging and Production builds from ever silently shipping dead authentication by providing a single provisioning script (`scripts/provision_local_xcconfig.sh`) and a strict fail-loud preflight check (`scripts/auth_config_preflight.sh`).

---

## 2. Configuration Values & Provenance

| Setting | xcconfig Key | Target `Info.plist` Key | Canonical Value / Source | Security Class |
|---|---|---|---|---|
| **Supabase Project URL** | `SPC_SUPABASE_URL` | `SPCSupabaseURL` | `https://nfzvlvukbeapcnlmyecf.supabase.co` (defined in `Base.xcconfig`) | Public |
| **Publishable / Anon Key** | `SPC_SUPABASE_PUBLISHABLE_KEY` | `SPCSupabasePublishableKey` | Supabase Dashboard: *Project Settings &rarr; API &rarr; API Keys &rarr; `anon` `public` key* (`sb_publishable_...`) | Public client key (injected via CI secret / local env) |
| **OAuth Redirect URL** | `SPC_OAUTH_REDIRECT_URL` | `SPCSupabaseOAuthRedirectURL` | `spc://auth/callback` (must match Supabase Auth Allow-list) | Public |

### Critical Security Boundaries
> [!CAUTION]
> **NEVER** put any of the following in `Local.xcconfig`, environment variables, or repository files:
> - Supabase `service_role` or secret keys (`sb_secret_...`)
> - Database passwords or connection strings
> - Apple Developer private keys (`.p8`, `.p12` passwords)
> - OAuth client secrets

The iOS app only ever receives the public/anon client key (`sb_publishable_...`). All database access permissions are enforced server-side via PostgreSQL Row Level Security (RLS).

### xcconfig URL Escaping Note
Xcode's xcconfig parser treats `//` as the start of a single-line comment. Therefore, URLs containing `://` must be escaped as `:/\$()/` in xcconfig files:
- `spc://auth/callback` &rarr; `spc:/$()/auth/callback`
- `https://nfzvlvukbeapcnlmyecf.supabase.co` &rarr; `https:/$()/nfzvlvukbeapcnlmyecf.supabase.co`

The provisioning script `scripts/provision_local_xcconfig.sh` handles this escaping automatically and idempotently.

---

## 3. Developer Local Setup

For local development and testing with live authentication:

### Option A: Using the Provisioning Script (Recommended)
Export the publishable key in your local shell and run the provisioning script:
```bash
export SPC_SUPABASE_PUBLISHABLE_KEY="<your_supabase_publishable_key>"
export SPC_OAUTH_REDIRECT_URL="spc://auth/callback"
bash scripts/provision_local_xcconfig.sh
```

### Option B: Manual Configuration
1. Copy `ios/Configurations/Local.xcconfig.example` to `ios/Configurations/Local.xcconfig`:
   ```bash
   cp ios/Configurations/Local.xcconfig.example ios/Configurations/Local.xcconfig
   ```
2. Open `ios/Configurations/Local.xcconfig` and set your publishable key:
   ```xcconfig
   SPC_SUPABASE_PUBLISHABLE_KEY = <your_supabase_publishable_key>
   SPC_OAUTH_REDIRECT_URL = spc:/$()/auth/callback
   ```
3. Run the preflight check in Development mode to verify:
   ```bash
   bash scripts/auth_config_preflight.sh --configuration Development
   ```

*Note: In Development mode, if `Local.xcconfig` is absent or unconfigured, the app runs with `UnavailableOAuthSessionService` (or `UITestOAuthSessionService` during UI tests) and builds without failure.*

---

## 4. CI/CD Environment Group Configuration

### A. GitHub Actions Setup (TestFlight Workflow)

> **Historical note (amended at S6 review):** Codemagic was planned but later dropped —
> GitHub Actions is the only CI/CD in use, and `codemagic.yaml` is retained in the repository
> but not executed. No Codemagic environment group is required. The only archive-and-upload
> path is `.github/workflows/testflight-internal.yml`.

In `.github/workflows/testflight-internal.yml`:
- **Repository Secret**: `SPC_SUPABASE_PUBLISHABLE_KEY` (Settings &rarr; Secrets and variables &rarr; Actions &rarr; Repository secrets)
- **Repository Variable**: `SPC_OAUTH_REDIRECT_URL` (`spc://auth/callback`)
- Step execution:
```yaml
      - name: Configure authorized public runtime values
        run: |
          bash scripts/provision_local_xcconfig.sh
          bash scripts/auth_config_preflight.sh --configuration Production
```

---

## 5. Scripts Reference

### `scripts/provision_local_xcconfig.sh`
- **Purpose**: Single source of truth for generating `ios/Configurations/Local.xcconfig`.
- **Behavior**:
  - Reads `SPC_SUPABASE_PUBLISHABLE_KEY`, `SPC_OAUTH_REDIRECT_URL`, and optional overrides from environment variables.
  - Normalizes and safely escapes all URL fields to prevent xcconfig comment collisions.
  - Generates `ios/Configurations/Local.xcconfig` atomically with restrictive file permissions (`chmod 600`).
  - Idempotent: Can be run repeatedly without duplicating escape sequences.
  - If no environment variables are present and `Local.xcconfig` exists, preserves the existing developer file.
  - Never logs secret values to stdout or stderr.

### `scripts/auth_config_preflight.sh`
- **Purpose**: Fail-loud gatekeeper ensuring builds do not ship with invalid or missing auth configuration.
- **Usage**:
  ```bash
  # Check against specific build configuration
  bash scripts/auth_config_preflight.sh --configuration Production
  bash scripts/auth_config_preflight.sh --configuration Staging
  bash scripts/auth_config_preflight.sh --configuration Development

  # Explicit mode enforcement
  bash scripts/auth_config_preflight.sh --mode require
  bash scripts/auth_config_preflight.sh --mode warn
  ```
- **Rules**:
  - **Staging / Production / `--mode require`**: Strict enforcement. Fails with non-zero exit code if `Local.xcconfig` is absent, key is empty, key is placeholder, key format is invalid, or redirect URL does not match `spc://auth/callback`.
  - **Development / `--mode warn`**: Warn-only. Emits informative notice and exits 0 to allow test suites and offline development to run smoothly.
  - **Zero Credential Leaking**: Diagnostic messages describe format requirements and missing variables without echoing key strings.

---

## 6. Failure Modes & Troubleshooting

| Preflight Error Message | Cause | Resolution |
|---|---|---|
| `::error title=Auth Configuration Missing::ios/Configurations/Local.xcconfig was not found...` | Staging/Production build ran without provisioning `Local.xcconfig`. | On GitHub Actions, verify the repository secret `SPC_SUPABASE_PUBLISHABLE_KEY` and variable `SPC_OAUTH_REDIRECT_URL` exist in repo Settings. Locally, run `bash scripts/provision_local_xcconfig.sh` with env vars set or copy `Local.xcconfig.example`. |
| `::error title=Missing Supabase Key::SPC_SUPABASE_PUBLISHABLE_KEY is empty in Local.xcconfig...` | `Local.xcconfig` exists but `SPC_SUPABASE_PUBLISHABLE_KEY` is blank. | Set the `anon` public key from Supabase Dashboard in `Local.xcconfig` or set `SPC_SUPABASE_PUBLISHABLE_KEY` environment variable. |
| `::error title=Placeholder Supabase Key::SPC_SUPABASE_PUBLISHABLE_KEY in Local.xcconfig contains the example placeholder.` | `Local.xcconfig` has the default placeholder string `sb_publishable_replace_with_project_key`. | Replace placeholder with the actual project anon/publishable key. |
| `::error title=Invalid Supabase Key Format::SPC_SUPABASE_PUBLISHABLE_KEY is malformed...` | Key string does not match `sb_publishable_...` or `eyJ...` prefix or is under 20 characters. | Ensure the complete, unmodified anon key was copied from Supabase Dashboard (*Project Settings &rarr; API*). |
| `::error title=Invalid Redirect URL::SPC_OAUTH_REDIRECT_URL must match approved redirect 'spc://auth/callback'...` | Redirect URL is not `spc://auth/callback` (or xcconfig escaped `spc:/$()/auth/callback`). | Set `SPC_OAUTH_REDIRECT_URL = spc:/$()/auth/callback` in `Local.xcconfig`. |
| `::error title=Security Violation::Service-role or secret key detected in configuration...` | A service-role key (`sb_secret_...` or `service_role`) was accidentally placed in `Local.xcconfig`. | **CRITICAL SECURITY RISK**: Immediately remove the service-role key. Replace with the public `anon` publishable key only. |
