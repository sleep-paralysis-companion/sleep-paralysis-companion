# Sign-In Flow Hardening — Orchestrated Sessions

> Created 27 August 2026 following the full sign-in flow review. Run each prompt below in its
> own chat session (fresh context). Each file is a complete operating contract; sessions assume
> no memory of other chats. Merge branches in the numbered order.

## Why these sessions exist

The review of `ios/Sources/Authentication/*`, `ios/Sources/App/AppModel.swift`,
`FigmaAuthenticationView.swift`, and the xcconfig/CI wiring found eight issues. They are grouped
into seven low-conflict sessions so parallel chat sessions cannot stomp each other's files.

## Session index

| # | Prompt file | Fixes | Priority | Depends on |
|---|-------------|-------|----------|------------|
| S1 | `AUTH_S1_OFFLINE_TOLERANT_RESTORE_SESSION_PROMPT.md` | Offline launch deleting valid sessions; unconditional refresh | 🔴 High | — |
| S2 | `AUTH_S2_FAILURE_TAXONOMY_LOGGING_SESSION_PROMPT.md` | All failures conflated to one opaque message; no auth logging | 🟡 Medium | merge S1 first |
| S3 | `AUTH_S3_CONSTANTS_AND_POLISH_SESSION_PROMPT.md` | Keychain service-string drift; dead `wrongAccount` catch; callback deeplink test; a11y audit | ⚪ Medium-low | merge S2 first |
| S4 | `AUTH_S4_SINGLE_SOURCE_SESSION_STORAGE_SESSION_PROMPT.md` | Refresh/access tokens persisted twice (SDK + app Keychain store) | 🟡 Medium | merge S3 first |
| S5 | `AUTH_S5_FULLNAME_FIELD_RESOLUTION_SESSION_PROMPT.md` | Create-account mode collects a Full Name it discards | 🟡 Medium | — (any slot) |
| S6 | `AUTH_S6_RELEASE_CONFIG_PROVISIONING_SESSION_PROMPT.md` | Clean-clone/TestFlight builds ship with blank Supabase key/redirect → silent dead auth | 🔴 High | — (run FIRST, parallel-safe) |
| S7 | `AUTH_S7_CONSOLIDATION_AND_FLOW_DOC_SESSION_PROMPT.md` | Dual auth architectures undocumented; final flow documentation | ⚪ Low | merge S1–S6 |

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
- Make targets (`Makefile`): `bootstrap format lint static privacy secrets simulator build unit ui verify`
  — all require macOS/Xcode. Development sessions on Windows must author code + tests statically
  and **never claim executed builds or tests that did not run**; every prompt repeats this rule.
