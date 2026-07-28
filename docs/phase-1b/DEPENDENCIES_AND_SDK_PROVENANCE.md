# Dependencies and SDK Provenance

| Component | Exact version | Source | Phase 1B purpose |
|---|---:|---|---|
| GRDB.swift | 7.11.1 | `github.com/groue/GRDB.swift` | local SQLite persistence/migrations |
| Supabase Swift | 2.53.0 | `github.com/supabase/supabase-swift` | Auth, PostgREST/RPC, Edge Function client |
| Supabase CLI | 2.110.0 | npm `supabase` | isolated stack, reset, pgTAP, lint |
| PostgreSQL | 17 | Supabase local image | isolated app schema/RLS |
| Deno | 2.8.1 | `denoland/deno` | Edge Function format/lint/tests |

SwiftPM uses exact requirements in `ios/project.yml`; CI captures and validates the generated
`Package.resolved`. No analytics, crash reporting, RevenueCat, networking wrapper, or generic
dependency-injection framework was added.

Primary-source review performed 2026-07-28:

- Supabase Swift releases and native Apple/Google ID-token Auth documentation.
- Supabase CLI `2.110.0 --help` for migration, reset, test, and lint commands.
- Supabase Data API grants documentation and the 2026 explicit-grants changelog.
- GRDB 7.11.1 release/tag and migration documentation.
- Apple privacy manifest and required-reason API documentation.

The migration does not rely on automatic Data API exposure: grants and RLS are separate,
explicit controls.
