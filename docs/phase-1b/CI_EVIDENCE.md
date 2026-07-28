# CI Evidence

Workflow: `.github/workflows/phase-1b-foundation.yml`

Previously verified implementation candidate:
`6b80c0d6269168b6f1a5494893869fc3278df47e`

Hosted run:
[30322506101](https://github.com/sleep-paralysis-companion/sleep-paralysis-companion/actions/runs/30322506101)

| Job | Result | Evidence |
|---|---|---|
| Xcode 26.6 / iPhone 17 / iOS 26.5 | PASS | build succeeded; 70 unit tests and 2 UI smoke tests passed with zero failures |
| Supabase 2.110.0 / PostgreSQL 17 / pgTAP | PASS | isolated start/reset succeeded; 61 RLS/schema assertions and 6 Edge tests passed; schema lint reported no errors |

That run predates the Phase 1B closure repairs and is retained only as historical evidence. It does
not verify the current branch head. The closure head must pass both hosted jobs before Gate 1B can
be restored to PASS. Its exact SHA, run ID, job IDs, counts, and artifact names will replace this
pending statement only after GitHub reports a green run for that exact pushed head.

The run also passed SwiftFormat 0.62.1, SwiftLint 0.65.0, warnings-as-errors, privacy-manifest
validation, static architecture checks, and worktree/full-history secret scanning. Artifacts were
retained for 30 days as `phase-1b-ios-evidence-30322506101-1` and
`phase-1b-backend-evidence-30322506101-1`.

Runner-reported toolchain:

- Xcode 26.6 (`17F113`)
- Apple Swift 6.3.3 (`swiftlang-6.3.3.1.3`, swift-driver 1.148.6)
- iPhone 17 simulator, iOS 26.5, arm64
- GRDB 7.11.1 and Supabase Swift 2.53.0 from committed SwiftPM resolution
- Supabase CLI 2.110.0
- PostgreSQL image 17.6.1.143
- Deno 2.8.1
- Docker Engine 28.0.4

The official Supabase hosted Security and Performance Advisors require a linked deployed project
and were not run because this phase forbids linking or changing the live project. The isolated
suite includes local advisor-equivalent checks for RLS/forced-RLS, public `SECURITY DEFINER`
functions, RLS init-plan form, foreign-key indexes, primary keys, and invalid indexes. Those
additional assertions remain part of the hosted isolated-backend workflow.
