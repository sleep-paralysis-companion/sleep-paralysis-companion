# Session Prompt: Sign-in Hardening S1B — Classifier Fail-Safe Reorder (404/422) + Split Commits

You are working in the Sleep Paralysis Companion repository (`C:\Users\satya\Documents\paralux`).
This session is exclusively for **S1B: a small follow-up to the completed S1 work — reorder the
refresh-error classifier so infrastructure 404/422 responses can never purge a valid session —
and then perform two pre-planned split commits**. Operating contract; assume no memory of any
other chat. Start by reading `AGENTS.md` and
`docs/session-prompts/signin-hardening/README.md` (Standing repo facts).

## Environment facts (verified)

Windows workstation — no Xcode/xcodebuild/swift; never claim executed builds or test runs. The S1
implementation is complete and **uncommitted** in the working tree. Standing repo rules: Swift 6,
`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, strict concurrency complete, warnings-as-errors; no
`@unchecked Sendable`, `nonisolated(unsafe)`, force unwraps, or new packages. `codemagic.yaml` was
deliberately reverted to HEAD and must remain untouched. CI/CD is GitHub Actions only.

## Task 1 — classifier reorder (code)

In `ios/Sources/Authentication/OAuthSessionService.swift`, `classifyRefreshError(_:)`
(currently ~L166–236): the bare-status-code branch that maps `401 | 403 | 404 | 422` to
`.definitiveRejection` runs **before** the keyword scan. A bare HTTP 404 from a misrouted proxy or
gateway outage therefore purges a valid session. Rework the order and sets:

1. Keep all network classification exactly as-is (URLError, NSURLErrorDomain, CFNetwork, POSIX set).
2. Keep `429`/`5xx` → `.unclassified`.
3. Move the **keyword scan before any bare-status definitive mapping**. The existing pattern list
   (`invalid_grant`, `invalid refresh token`, `refresh_token_not_found`, `session_not_found`,
   `user_not_found`, `jwt expired`, `bad_jwt`, `revoked`, …) stays unchanged — it is what catches
   genuine token-not-found rejections regardless of status code.
4. After keywords: bare `401` or `403` → `.definitiveRejection`; bare `404` and `422` →
   `.unclassified` (preserve — infra-level 404/422 must not destroy sessions).
5. Keep the final bare-`400` → `.definitiveRejection` fallback after keywords, and the overall
   `.unclassified` default.
6. Update the rationale comment table above the function to match the new behavior exactly.

## Task 2 — tests

Update `ios/Tests/Unit/OAuthSessionServiceRestoreTests.swift`:

- Adjust any matrix assertions that treated bare 404/422 as definitive.
- Add: bare HTTP 404 with an unrelated body (e.g. HTML text, no keywords) → `.unclassified`, and
  via `restore()` → `.preservedOffline` with keychain preserved.
- Add: bare HTTP 422 with unrelated body → same outcome.
- Add: an error whose description contains `session not found` (even wrapped in a 404/400) →
  `.definitiveRejection`, and via `restore()` → keychain purged + `AuthenticationError.expired`
  thrown (proving keywords still catch real rejections after the reorder).

## Task 3 — static self-checks (no toolchain available)

- Grep the classifier to prove no bare `404`/`422` → `.definitiveRejection` mapping remains and the
  keyword loop precedes the `401`/`403` bare-status branch.
- Grep that the rationale table text matches the new mapping.
- Confirm zero diff outside the two files listed in Tasks 1–2.

## Task 4 — commits (you perform them; two logical commits, explicit paths only)

**Preconditions — verify `git status --short` matches exactly this set before committing**
(expected modified: `.github/workflows/testflight-internal.yml`,
`ios/Configurations/Local.xcconfig.example`, `ios/Sources/App/AppModel.swift`,
`ios/Sources/Authentication/OAuthSessionService.swift`, `scripts/testflight_configuration_check.sh`,
`scripts/verify_ci.sh`; expected untracked: `agents.md` (LEAVE UNTRACKED — do not stage),
`docs/phase-1c/AUTH_CONFIG_PROVISIONING.md`, `docs/session-prompts/signin-hardening/`,
`ios/Tests/Unit/OAuthSessionServiceRestoreTests.swift`, `scripts/auth_config_preflight.sh`,
`scripts/provision_local_xcconfig.sh`). If `codemagic.yaml` appears as modified, or the set differs
materially, STOP and report instead of committing.

**Commit 1 — S6 (auth config provisioning & preflight):**
`scripts/provision_local_xcconfig.sh`, `scripts/auth_config_preflight.sh`, `scripts/verify_ci.sh`,
`scripts/testflight_configuration_check.sh`, `.github/workflows/testflight-internal.yml`,
`ios/Configurations/Local.xcconfig.example`, `docs/phase-1c/AUTH_CONFIG_PROVISIONING.md`,
`docs/session-prompts/signin-hardening`
Message: `feat(auth): fail-loud auth config provisioning + preflight for release archives (S6)`

**Commit 2 — S1 incl. this tweak:**
`ios/Sources/Authentication/OAuthSessionService.swift`, `ios/Sources/App/AppModel.swift`,
`ios/Tests/Unit/OAuthSessionServiceRestoreTests.swift`
Message: `feat(auth): offline-tolerant session restore with refresh-error classification (S1)`

Commit rules: stage explicit paths only — never `git add -A` or `git add .`; do not stage
`agents.md`; do not push; no force operations; if the working branch rejects commits (protection),
create branch `signin-hardening` and note it. After committing, print `git log --oneline -3` and
`git status --short` (expected: only `?? agents.md` remains).

## Out of scope

Do not touch `signIn`/`reauthenticateForDeletion` bodies, S2's logging territory,
`SupabasePublicConfiguration`, Configurations, workflows, or the orchestration README. Do not begin
S2. Do not push.

## Report-back

Classifier before/after mapping summary, test inventory changes (updated vs added), rationale-table
diff, both commit hashes + messages, final `git status --short`, and the explicit
"compile-unverified on this workstation" statement plus the exact macOS commands the owner runs
next (`make lint && make unit`, then push).
