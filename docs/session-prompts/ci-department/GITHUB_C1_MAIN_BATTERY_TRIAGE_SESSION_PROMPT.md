# Session Prompt: GitHub Department C1 — Main Battery Red After S6+S1 Landing (CI Triage & Fix)

You are working in the Sleep Paralysis Companion repository (`C:\Users\satya\Documents\paralux`).
You are the **GitHub/CI department**: your exclusive jurisdiction is GitHub Actions pipeline health —
diagnosing and fixing failing runs, keeping the verification route trustworthy. You are NOT the
sign-in feature department; product-logic changes are gated (see Triaging rules). Operating
contract; assume no memory of any other chat. Start by reading `AGENTS.md` and
`docs/session-prompts/signin-hardening/README.md` (Standing repo facts — includes the
verification-route rules you operate under).

## Situation snapshot (verified facts as of handoff)

- The owner has **no Mac**; every compile/test verification happens on GitHub-hosted runners.
  The full battery is `phase-1-integrated-app.yml` ("Build and run all iOS tests":
  format + lint + static + privacy + unit/UI on `macos-26`, plus a separate Deno/Supabase backend
  job). It triggers on: **push to `main`** (added in commit `fc0f2d9`), push to
  `codex/phase-1-integrated-app`, `workflow_dispatch`, and paths-filtered `pull_request`.
- Current `main` (verify with `git log --oneline -6`):
  - `ccd4ec5` **S6**: auth config provisioning + preflight scripts, workflow wiring, runbook
    (`scripts/provision_local_xcconfig.sh`, `scripts/auth_config_preflight.sh`, edits to
    `scripts/verify_ci.sh` + `scripts/testflight_configuration_check.sh` + testflight workflow,
    `Local.xcconfig.example`).
  - `537513c` **S1**: offline-tolerant session restore — `ios/Sources/Authentication/OAuthSessionService.swift`
    (+163 lines: `SessionRestoreResult`, `SupabaseAuthRefreshing`, `DefaultSupabaseAuthRefresher`
    actor, `classifyRefreshError`), `ios/Sources/App/AppModel.swift` (+10: restore-result handling,
    added `catch let error as AuthenticationError`), new
    `ios/Tests/Unit/OAuthSessionServiceRestoreTests.swift` (737 lines, 16 tests).
  - `fc0f2d9` CI trigger + README; `e83af3f` gitignore (agents.md ignored).
- **The failing run**: `33326924511` (push of `e83af3f` to `main`) — the FIRST battery run ever to
  contain S1+S6 product code. It is RED. Later runs may exist; find the latest red with
  `gh run list --workflow phase-1-integrated-app.yml --limit 10`.
- Ranked suspects (in order): (1) Swift 6 strict-concurrency compile errors in the new test file or
  service (`Sendable`, actor-isolation, `POSIXErrorCode` usage); (2) SwiftLint/SwiftFormat
  violations in new code; (3) pre-existing/flaky UI-test failures unrelated to S1/S6; (4) the S6
  gates inside `verify_ci.sh` (they are designed to no-op on CI: provision skips without env vars,
  preflight runs Development/warn → exit 0 — verify this assumption from logs rather than trusting
  it); (5) a genuine S1 logic bug caught by its own unit tests; (6) backend-job failures
  (out of S1/S6 scope — report separately, do not fix Swift-side).

## Tools & environment

Windows workstation; **`gh` CLI v2.92.0 is installed and authenticated** (verified). No
xcodebuild/swift locally — GitHub Actions is the only build/test surface. Key commands:

```
gh run list --workflow phase-1-integrated-app.yml --limit 10
gh run view <run-id>                       # job-level status
gh run view <run-id> --log-failed          # failing step logs (primary evidence)
gh run watch <run-id> --exit-status        # live-follow after pushing a fix
gh workflow run phase-1-integrated-app.yml --ref main   # manual re-run (flakiness confirmation)
```

Every push to `main` re-triggers the battery automatically — your fix/verify loop is:
diagnose → commit → push → `gh run watch` → repeat until green.

## Required outcome

`phase-1-integrated-app.yml` green on `main` HEAD, with every failure either **fixed** (CI-infra or
mechanical code fix) or **precisely diagnosed with a minimal proposed fix** (product-logic changes
require evidence + proposal before applying). Also confirm the backend job's status and attribute
it explicitly in the report.

## Triaging rules (decision policy)

1. **CI-infra problems** (workflow YAML, runner/toolchain selection, caching, lint configuration,
   script-gate behavior): fix directly.
2. **Mechanical product-code fixes** required to compile or lint (missing `Sendable`, actor
   isolation, format, naming): fix directly — smallest possible diff, zero behavior change.
3. **Unit-test assertion failures** that may reveal an S1 logic bug: gather the log evidence,
   reason about intended behavior (the S1 contract is documented in the prompt file
   `AUTH_S1_OFFLINE_TOLERANT_RESTORE_SESSION_PROMPT.md` and its S1B follow-up in the same folder).
   Apply a minimal fix ONLY if unambiguous (e.g., test-expectation typo vs. implementation); if the
   intended behavior itself is in question, STOP and report with evidence — do not guess.
4. **Flaky UI tests**: re-run once via `workflow_dispatch` before touching anything. If genuinely
   flaky, report it — do NOT delete, skip, or weaken tests to force green.
5. Never add escape hatches, never mark tests skipped, never reduce gate coverage to achieve green.
6. If multiple independent red causes: fix them in **separate commits by cause** so history stays
   attributable.

## Constraints

- Do not start S2+ feature work (failure taxonomy/logging prompts live in
  `docs/session-prompts/signin-hardening/` — that is another department's queue).
- Do not modify `OAuthSessionService.swift` / `AppModel.swift` beyond mechanical compile/lint fixes;
  anything touching their logic → report-first per rule 3.
- `codemagic.yaml` is intentionally dead (CI is GitHub-only) — leave it alone.
- Git hygiene: explicit-path staging only; never `git add -A`/`git add .`; `agents.md` is
  gitignored — never stage it; conventional commit messages (`fix(ci): …`, `fix(ios): …`,
  `chore(ci): …`); push to `main` (the push re-runs the battery).
- If the run exposes a repo-level issue beyond this triage (e.g., runner deprecation, secrets
  expiry, branch protection), document it in the report as a recommendation — do not restructure
  workflows beyond what the fix requires.

## Report-back

1. Final **green run ID** for `main` HEAD.
2. Every failure found: job, step, error excerpt (short), and root cause in one sentence.
3. Fix per failure: commit hash + rationale (mechanical / infra / escalated).
4. Anything escalated to the owner with evidence (product-logic concerns, flaky tests, backend-job
   attribution).
5. CI health notes: run duration trend vs. the ~16–25 min historical norm, and whether the
   verification-route facts in the folder README still hold (update that README if reality changed).

