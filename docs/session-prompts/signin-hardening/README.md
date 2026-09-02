# Sign-In Flow Hardening — Orchestrated Sessions

> **Completed 01 September 2026.** All hardening sessions S1–S7 are merged and reconciled.
> The definitive end-to-end authentication narrative, launch composition, offline restore, storage inventory,
> failure taxonomy, and wrong-account guards are documented in [`docs/PHASE_SIGN_IN_FLOW.md`](../../PHASE_SIGN_IN_FLOW.md).

> Created 27 August 2026 following the full sign-in flow review. Run each prompt below in its
> own chat session (fresh context). Each file is a complete operating contract; sessions assume
> no memory of other chats. Merge branches in the numbered order.

## Why these sessions exist

The review of `ios/Sources/Authentication/*`, `ios/Sources/App/AppModel.swift`,
`FigmaAuthenticationView.swift`, and the xcconfig/CI wiring found eight issues. They are grouped
into seven low-conflict sessions so parallel chat sessions cannot stomp each other's files.

## Session index

| # | Prompt file | Fixes | Priority | Status |
|---|-------------|-------|----------|--------|
| S1 | `AUTH_S1_OFFLINE_TOLERANT_RESTORE_SESSION_PROMPT.md` | Offline launch deleting valid sessions; unconditional refresh | 🔴 High | **Completed** — see [`docs/PHASE_SIGN_IN_FLOW.md`](../../PHASE_SIGN_IN_FLOW.md#5-launch-restoration-strategy-offline-tolerant-s1--migration-s4) |
| S2 | `AUTH_S2_FAILURE_TAXONOMY_LOGGING_SESSION_PROMPT.md` | All failures conflated to one opaque message; no auth logging | 🟡 Medium | **Completed** — see [`docs/PHASE_SIGN_IN_FLOW.md`](../../PHASE_SIGN_IN_FLOW.md#7-failure-taxonomy-user-copy--privacy-safe-logging-s2) |
| S3 | `AUTH_S3_CONSTANTS_AND_POLISH_SESSION_PROMPT.md` | Keychain service-string drift; dead `wrongAccount` catch; callback deeplink test; a11y audit | ⚪ Medium-low | **Completed** — see [`docs/PHASE_SIGN_IN_FLOW.md`](../../PHASE_SIGN_IN_FLOW.md#10-accessibility--ui-design-system-notes-s3--s5-outcomes) |
| S4 | `AUTH_S4_SINGLE_SOURCE_SESSION_STORAGE_SESSION_PROMPT.md` | Refresh/access tokens persisted twice (SDK + app Keychain store) | 🟡 Medium | **Completed** — see [`docs/PHASE_SIGN_IN_FLOW.md`](../../PHASE_SIGN_IN_FLOW.md#4-storage-inventory-at-rest-post-s4-architecture) |
| S5 | `AUTH_S5_FULLNAME_FIELD_RESOLUTION_SESSION_PROMPT.md` | Create-account mode collects a Full Name it discards | 🟡 Medium | **Completed** — see [`docs/PHASE_SIGN_IN_FLOW.md`](../../PHASE_SIGN_IN_FLOW.md#10-accessibility--ui-design-system-notes-s3--s5-outcomes) |
| S6 | `AUTH_S6_RELEASE_CONFIG_PROVISIONING_SESSION_PROMPT.md` | Clean-clone/TestFlight builds ship with blank Supabase key/redirect → silent dead auth | 🔴 High | **Completed** — see [`docs/PHASE_SIGN_IN_FLOW.md`](../../PHASE_SIGN_IN_FLOW.md#3-launch-composition--configuration-decision-tree) + [`AUTH_CONFIG_PROVISIONING.md`](../../phase-1c/AUTH_CONFIG_PROVISIONING.md) |
| S7 | `AUTH_S7_CONSOLIDATION_AND_FLOW_DOC_SESSION_PROMPT.md` | Dual auth architectures undocumented; final flow documentation | ⚪ Low | **Completed** — see [`docs/PHASE_SIGN_IN_FLOW.md`](../../PHASE_SIGN_IN_FLOW.md) |

## Recommended run order

1. **S6 immediately** (independent files; protects the next TestFlight upload).
2. **S1**, then sequentially **S2 → S3** (shared files: `OAuthSessionService.swift`, `AppModel.swift`).
3. **S4** (touches most auth files again; must land on top of settled code).
4. **S5** any time in an idle slot (isolated to the auth screen).
5. **S7 last**, purely to consolidate and document the end state.

## Conflict-control rules

- Each prompt lists **Files you own** and **Do not touch**. Do not widen them mid-session.
- One git branch per session; suggested titles are inside each prompt.
- If a session discovers another session's territory needs a change, stop and note it in the
  report-back instead of editing across ownership boundaries.

## Standing repo facts (true as of authoring; re-verify in each session)

- Stack pins: `supabase-swift 2.53.0` exact, `GRDB 7.11.1` exact (`ios/project.yml`). No new packages.
- Build settings: Swift 6, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` (hence the pervasive
  explicit `nonisolated` markers), `SWIFT_STRICT_CONCURRENCY = complete`,
  `SWIFT_TREAT_WARNINGS_AS_ERRORS = YES`.
- **CI/CD is GitHub Actions only.** Codemagic was planned but later dropped; `codemagic.yaml`
  remains in the repo but is not executed. The archive-and-upload path is
  `.github/workflows/testflight-internal.yml` (workflow_dispatch, macos-26), which provisions
  `Local.xcconfig` from the repository secret `SPC_SUPABASE_PUBLISHABLE_KEY` and repository
  variable `SPC_OAUTH_REDIRECT_URL`, then runs `scripts/auth_config_preflight.sh
  --configuration Production` before bootstrap/archive. Other `phase-1*.yml` workflows run
  verification gates via `scripts/verify_ci.sh`.
- **Verification route (owner has no Mac):** verification runs on **GitHub Actions hosted
  runners**. `phase-1-integrated-app.yml` is the full battery ("Build and run all iOS tests":
  format + lint + static + privacy + unit/UI on `macos-26`) and triggers on: **push to `main`**
  (added during S1B follow-up; direct-to-main is the owner's normal flow, so every main push is
  verified post-merge), **push to `codex/phase-1-integrated-app`**, **workflow_dispatch**, and
  **pull_request** (paths `ios/**`, `scripts/**`, `supabase/**` — useful for pre-merge gating on
  branches). `phase-1a-ios.yml`, `phase-1b-foundation.yml`, and `phase-1c-onboarding.yml` remain
  PR-path-triggered only. Session prompts referencing `make lint/unit/ui` should treat those as
  the CI gates above and say so in their verification instructions; if a session's changes must be
  verified before landing on main, use a branch + PR instead of a direct push.
- Make targets (`Makefile`): `bootstrap format lint static privacy secrets simulator build unit ui verify`
  — all require macOS/Xcode and are exercised inside the PR workflows above, not by the owner.
