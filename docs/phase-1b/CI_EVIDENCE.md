# CI Evidence

Workflow: `.github/workflows/phase-1b-foundation.yml`

Verified Phase 1B closure implementation head:
`2cd106ce561d6562dd3eabf38a534c780b116f51`

Hosted run:
[30350985687](https://github.com/sleep-paralysis-companion/sleep-paralysis-companion/actions/runs/30350985687)

| Job | Job ID | Result | Evidence |
|---|---:|---|---|
| [Xcode 26.6 / iPhone 17 / iOS 26.5](https://github.com/sleep-paralysis-companion/sleep-paralysis-companion/actions/runs/30350985687/job/90248170918) | `90248170918` | PASS | build succeeded; 77 unit tests and 2 UI smoke tests passed with zero failures on simulator UDID `4F368A51-D5B4-493C-9A9D-81BF201DDFA6` |
| [Supabase 2.110.0 / PostgreSQL 17 / pgTAP](https://github.com/sleep-paralysis-companion/sleep-paralysis-companion/actions/runs/30350985687/job/90248170851) | `90248170851` | PASS | isolated start/reset succeeded; 102 pgTAP assertions across 3 files and 11 Edge Function tests passed; schema lint reported no errors |

The exact implementation head passed SwiftFormat 0.62.1, SwiftLint 0.65.0,
warnings-as-errors, privacy-manifest validation, static architecture checks, provider-credential
non-persistence checks, and worktree/full-history secret scanning. The hosted artifacts are
retained for 30 days:

- `phase-1b-ios-evidence-30350985687-1` (`8685124696`),
  SHA-256 `18086bd708accfa03cb1194bf10da03cef5eee9c93d56ac33c7acdacb86487f2`;
- `phase-1b-backend-evidence-30350985687-1` (`8684937196`),
  SHA-256 `c05b89e82c0a6e2fd783b4bfd255a3937d90c5f7217e33f3f9ffb46195b1d68f`.

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
