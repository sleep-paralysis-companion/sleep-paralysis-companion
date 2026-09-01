# Session Prompt: GitHub Department C2 — Main Battery Second Red Run (8 Real Unit-Test Failures Now Surfaced)

You are working in the Sleep Paralysis Companion repository (`C:\Users\satya\Documents\paralux`).
You are the **GitHub/CI department**: your exclusive jurisdiction is GitHub Actions pipeline health —
diagnosing and fixing failing runs, keeping the verification route trustworthy. You are NOT the
sign-in feature department; product-logic changes are gated (see Triaging rules). Operating
contract: assume no memory of any other chat. Start by reading `AGENTS.md` and
`docs/session-prompts/signin-hardening/README.md` (Standing repo facts — includes the
verification-route rules you operate under).

## Situation snapshot (verified facts as of handoff C2, commit `bc2a53a` on `main`)

### What department C1 already fixed (merged to main, pushed — DO NOT re-do)

- `bc47d60 fix(ci): propagate real verification-gate failures through verify_ci.sh` — `run_gate`
  in `scripts/verify_ci.sh` had a bash bug: `if "$@"; then return 0; fi` followed by
  `local gate_status=$?` always captured **0**, so every failing gate was masked as `(exit 0)`
  and the battery stayed GREEN on main while format/lint/privacy/secret/build/unit/UI gates were
  actually failing. It is now fixed (verified locally: failing gate returns its real exit code).
  **Consequence: green runs before this commit cannot be trusted** (e.g. run `32764086863` on
  8/24 had the same masked failures).
- `5334674 fix(ios): make main CI green - S1 compile fixes and strict-gate compliance` — the
  compile errors from the first red run (unused `service` in `OAuthSessionServiceRestoreTests.swift`,
  unused `error` catch binding in `AppModel.swift:195`) plus every format/lint strict violation:
  `for_where`, `legacy_multiple`, `identifier_name`, `function_parameter_count` (WakeAlarmService
  `updated` now takes an `alarmIDs:` tuple), `file_length` (`LocalDatabase.swift` conversion block
  moved to new `ios/Sources/LocalPersistence/LocalDatabase+ConversionCheckpoint.swift`),
  `cyclomatic_complexity` (AppModel `saveScheduleUI` split out `scheduleValidationFeedback`),
  `force_unwrapping` (XCTUnwrap / `UUID(uuid:)`), `line_length`, and pinned SwiftFormat 0.62.1 output.
- `bc2a53a fix(ci): align privacy-manifest and secret-scan gates with declared reality` —
  `PrivacyInfo.xcprivacy` now declares `NSPrivacyAccessedAPICategoryDiskSpace` with reason `3B52.1`
  and `scripts/privacy_manifest_check.sh` enforces it (CatalogAudioBoundaries uses
  `volumeAvailableCapacity` for cache-capacity checks); `scripts/secret_scan.sh` filters the known
  false-positive PEM-header literal quoted in `scripts/poll_build_processing.mjs` (which also exists
  in immutable git history).

### The battery NOW (run `33332476655`, HEAD `bc2a53a`) — RED for the FIRST time for the right reason

- `phase-1-integrated-app.yml` (full iOS battery on `macos-26` + separate `isolated-backend` Deno/Supabase job).
- **Backend job `Verify the isolated Supabase contract`: ✓ PASSED in 2m45s** (ID 99313450892).
  The prior red backend (`toomanyrequests: Rate exceeded` on Docker Hub during supabase image pulls
  in run `33326924511`) was a **transient infra rate-limit** — clears on rerun. Do not "fix" Swift-side
  for it. (Recommendation for the report: consider mirroring supabase images from
  `public.ecr.aws/supabase/*` — already present in the local Docker cache — to de-flake; do not
  restructure the workflow beyond what a fix requires.)
- **iOS job `Build, test, and capture the iPhone journey`: ✗ in 11m4s, failing at the
  `Build and run all iOS tests` step — `unit_tests (exit 65)`** (ID 99313451083). The `run_gate`
  fix is working: it now surfaces the REAL, previously-masked unit-test failures. Every other gate
  passed (format, lint, static, privacy, secret, build). Visual journey step was skipped (job died earlier).
### Exactly 8 failing unit tests, no build/format/lint remain — grouped by root cause

1. **`ios/Tests/Unit/OAuthSessionServiceRestoreTests.swift` — 2 failures (JSON decoding of SDK `Session`):**
   - `testStaleSessionSuccessfulRefreshWritesBackAndReturnsUpdatedMaterial`
   - `testStaleSessionSuccessfulRefreshWithKeychainWriteFailurePreservesStoredSessionOffline`
   Both fail at the helper `makeSyntheticSession` (currently ~line 74) with:
   `DecodingError.keyNotFound: Key 'accessToken' not found in keyed decoding container`.
   **Evidence:** supabase-swift **v2.53.0** `Session` (Sources/Auth/Types.swift) uses synthesized
   camelCase `CodingKeys` (`accessToken`, `refreshToken`, `expiresAt`, `expiresIn`, `tokenType`, `user`).
   The test's `makeSyntheticSession` builds a JSON literal with **snake_case** keys
   (`access_token`, `refresh_token`, `expires_at`, …) and decodes with a bare `JSONDecoder()` (no
   `keyDecodingStrategy`); the real SDK decodes with
   `AuthClient.Configuration.decoder`/`jsonDecoder`, which handles the snake_case GoTrue wire format.
   **Minimal fix (mechanical, zero behavior change — fix directly):** make `makeSyntheticSession`
   produce the same `Session` the SDK would: decode the exact snake_case JSON with a decoder whose
   `keyDecodingStrategy = .convertFromSnakeCase` (mirrors the SDK), OR build the literal in camelCase
   matching `Session`'s CodingKeys. **PREFERRED: use `.convertFromSnakeCase` on the test decoder and
   keep the snake_case wire-shaped fixture** — that mirrors the real refresh response. Only touch the
   test helper; do not touch `OAuthSessionService.swift` logic. Optionally verify what
   `AuthClient.Configuration.jsonDecoder` sets by grepping the pinned package source in
   `ios/.generated/SourcePackages` on the runner (or the GH tree at v2.53.0).

2. **`ios/Tests/Unit/LocalDatabaseTests.swift` — 4 failures (stale schema-version expectations):**
   - `testUnsupportedNewerSchemaFailsWithoutReset` — asserts
     `.unsupportedNewerSchema(found: 99, supported: 6)`, actual is **`supported: 10`**.
   - `testMigrationFromCommittedV1ToV6` / `testMigrationFromCommittedV2ToV6` /
     `testMigrationFromCommittedV3ToV6PreservesNoFabricatedPersonaData` — assert migrated
     `schemaVersion() == 6`, actual is **`10`**.
   **Evidence:** `ios/Sources/LocalPersistence/LocalSchema.swift` has
   `static let currentVersion = 10` and registered migrations `v1..v10`
   (`v7_partner_call_contact`, `v8_audio_cache_lifecycle`, `v9_alarm_sound_selection`,
   `v10_alarm_schedules`). The tests were written when current was 6 and never updated as v7–v10
   landed. **Minimal fix (mechanical, unambiguous — fix directly):** update the expected literals
   `6 → 10` in those four tests and rename the three `...ToV6` / `...V6...` test names to `V10`
   for accuracy (mechanical rename; keep assertions identical apart from the literal). Confirm
   `migrate(queue, upTo: "v1_core_local_data")` etc. still migrate through v10 (they do — `migrate`
   runs all migrations up to the identifier, then v10 is reached by opening `LocalDatabase`).

3. **`ios/Tests/Unit/DataRightsFoundationTests.swift` — 2 failures (`DeletionError.localCleanupFailed`):**
   - `testLocalDeletionReconcilesDatabaseKeychainAlarmsAndFiles`
   - `testAccountDeletionDoesNotCleanLocalDataBeforeRemoteSuccess`
   Both fail with `caught error: "localCleanupFailed"`.
   **Evidence:** `ios/Sources/DataRights/DeletionFoundation.swift`
   `LocalDataDeletionCoordinator.deleteAllLocalData()` throws `DeletionError.localCleanupFailed` if
   ANY of `alarms.removeAllAppCreatedAlarms()`, `files.removeDownloadedAudioAndExports()`,
   `sessionStore.delete()`, or `database.deleteAllLocalData()` throws. The tests use recording
   mocks for alarms/files, so **the failing call is almost certainly `database.deleteAllLocalData()`**
   (now at `ios/Sources/LocalPersistence/LocalDatabase.swift:~631`): it runs
   `DELETE FROM local_profiles; DELETE FROM audio_cache; DELETE FROM audio_catalog;` inside
   `write { }` with GRDB `foreignKeysEnabled = true`. Foreign-key dependent rows in tables added by
   migrations v7–v10 (and pre-existing ones like `check_ins`, `alarm_schedules`, `drafts`,
   `conversion_checkpoints`, `persona_*`, `partner_contact`, etc.) reference `local_profiles`, so the
   `DELETE FROM local_profiles` likely violates an FK and throws.
   **IMPORTANT — triage rule 3 applies (possible product-logic bug, may not be unambiguous):**
   - DO NOT guess. Pull the failing-step log
     (`gh run view 33332476655 --log-failed`, or the retained `phase-1-integrated-ios-evidence-33332476655-1`
     artifact which contains `ios/TestResults/verify_ci.log` — download with
     `gh run download 33332476655 -n phase-1-integrated-ios-evidence-33332476655-1`) and find the
     underlying GRDB error (likely `SQLite error ... FOREIGN KEY constraint failed` mentioning a
     table) that is being swallowed into `.localCleanupFailed`.
   - If the evidence confirms `deleteAllLocalData` does not account for FK-dependent rows added after
     v6, that is a genuine data-deletion/product-logic defect (was silently red since v7/v8 landed).
     Decide per rule 3: apply a **minimal, provably-correct** fix (e.g. delete dependent rows first,
     or `DELETE` in an order/FK-safe way, or `PRAGMA foreign_keys=OFF` scoped to that one method with
     an explicit comment — pick the approach that matches the repo's existing GRDB patterns) ONLY if
     unambiguous; otherwise STOP and report with evidence — do not guess, do not weaken the test.
### Environment / tooling notes (from C1)

- Windows workstation; `gh` CLI v2.92.0 authenticated; **no local Swift/xcodebuild** — GitHub Actions
  is the only build surface. Docker Desktop 28.5.1 is available and images for the pinned toolchain
  are **already pulled locally**:
  - `ghcr.io/nicklockwood/swiftformat:0.62.1` (exact pin in `scripts/versions.env`)
  - `ghcr.io/realm/swiftlint:0.65.0` (C1 had to re-pull once — the first pull produced a broken
    `libswiftCore.so: file too short`; if you see that, `docker rmi` + re-pull)
- Verified local gate loops that run clean right now (re-run if you touch Swift):
  ```
  docker run --rm -v "C:\Users\satya\Documents\paralux:/repo" -w /repo ghcr.io/nicklockwood/swiftformat:0.62.1 ios/Sources ios/Tests --config /repo/.swiftformat --lint
  docker run --rm -v "C:\Users\satya\Documents\paralux:/repo" -w /repo ghcr.io/realm/swiftlint:0.65.0 lint --strict --config /repo/.swiftlint.yml
  ```
  (Use `cmd /c "... > out.txt 2>&1"` redirection from PowerShell — direct piping mangles docker's
  stderr. PowerShell `$t = [IO.File]::ReadAllText(...)` edits can flip line endings; re-normalize to LF
  and re-run swiftformat `--lint` after any write; `.gitattributes` enforces LF.)
- Git push needed `GIT_TERMINAL_PROMPT=0` + `gh auth setup-git` (first attempt can print
  `/dev/tty`/credential noise but still succeed — verify with `git rev-parse HEAD origin/main`).

## Required outcome

`phase-1-integrated-app.yml` green on `main` HEAD, with every failure either **fixed** (CI-infra or
mechanical code fix — the 2 S1-test decoding failures and the 4 LocalDatabase stale-schema failures
qualify) or **precisely diagnosed with minimal proposed fix as evidence** (the 2 DataRights
`localCleanupFailed` failures are the candidate for rule-3 escalation REGARDLESS — capture the
underlying GRDB error first). Also confirm the backend job's status in the report.

## Triaging rules (decision policy) — unchanged from C1

1. **CI-infra problems**: fix directly.
2. **Mechanical product-code fixes** required to compile/lint (missing Sendable, actor isolation,
   format, naming): fix directly — smallest possible diff, zero behavior change.
3. **Unit-test assertion failures that may reveal a logic bug**: gather log evidence, reason about
   intended behavior, apply a minimal fix ONLY if unambiguous; if intended behavior is in question,
   STOP and report with evidence — do not guess. (DataRights failures: prove the underlying error
   before touching `deleteAllLocalData`.)
4. **Flaky UI tests**: re-run once via `workflow_dispatch` before touching. Never delete/skip/weaken.
5. Never add escape hatches, never mark tests skipped, never reduce gate coverage.
6. Multiple independent red causes → fix in **separate commits by cause** so history stays attributable.

## Constraints

- The S1 session prompt contract is documented in
  `docs/session-prompts/signin-hardening/AUTH_S1_OFFLINE_TOLERANT_RESTORE_SESSION_PROMPT.md` and its
  S1B follow-up in the same folder — do not start S2+ work.
- Do not modify `OAuthSessionService.swift` / `AppModel.swift` beyond mechanical compile/lint fixes
  (they already passed; the 2 remaining S1-test failures are a **test-fixture decoding** issue, not
  service logic — fix the test helper).
- `codemagic.yaml` is intentionally dead — leave it alone.
- Git hygiene: explicit-path staging only; never `git add -A`/`git add .`; `agents.md` gitignored —
  never stage it; conventional commits (`fix(test): …`, `fix(ios): …`, `fix(ci): …`). Push to `main`
  (the push re-runs the battery). Verify with `git rev-parse HEAD origin/main` after push.
- If the run exposes a repo-level issue beyond triage (e.g. runner deprecation, Docker Hub rate
  limits, secrets expiry), document as a recommendation — do not restructure workflows beyond the fix.

## Suggested next actions (in order)

1. Fix the 2 Session-decoding test failures (test-only) → commit `fix(test): …`.
2. Fix the 4 stale LocalDatabase schema-version expectations (test-only) → commit (separate).
3. Investigate the 2 DataRights `localCleanupFailed` failures: pull evidence, identify the underlying
   error; apply minimal fix or escalate per rule 3 → commit only if unambiguous.
4. `gh run watch <run-id> --exit-status` until green; the visual-journey step will run only after
   unit tests pass — treat any visual/UI failures as suspect #4 (flaky → re-run once, don't weaken).
5. Write out all of the above into the report-back + verify the verification-route facts in
   `docs/session-prompts/signin-hardening/README.md` still hold (update if reality changed).

Local convenience files created during C1 (all removed): `.ci_*`, `scripts/.run_poller.ps1`.
The untracked folder `docs/session-prompts/ci-department/` is this department's workspace — keep
prompts/handoffs there.