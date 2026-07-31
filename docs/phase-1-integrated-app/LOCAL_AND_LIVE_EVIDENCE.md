# Paralux Phase 1 integrated-app evidence

Evidence captured on 2026-07-31 (Asia/Calcutta). Starting commit:
`5de712b1b901f230400e52a70e33a6f556953ecd`. Branch:
`codex/phase-1-integrated-app`.

Integrated iOS implementation commit:
`8203aae785a2922ec9424e67e58083334067cf33`.

## Live Supabase schema evidence

The connected project URL was confirmed before mutation as
`https://nfzvlvukbeapcnlmyecf.supabase.co`. The read-only baseline contained
only `public.waitlist`, with RLS enabled and exactly four rows. Static review of
all four repository migrations found no `waitlist` reference.

The following exact repository migrations were applied through the Supabase
migration API in order:

1. `20260731054329 phase_1b_app_sync_foundation`
2. `20260731054502 phase_1b_closure_contracts`
3. `20260731054628 phase_1b_persona_audio_delta`
4. `20260731054657 phase_1b_persona_audio_mutation_boundary_repair`

Post-application read-only verification:

- `public.waitlist` still has exactly 4 rows.
- `storage.objects` has 0 rows; no personal-audio Storage bucket was created.
- `auth.users` has 0 rows.
- All 9 public tables have RLS enabled; all 8 new app tables also force RLS.
  The pre-existing waitlist remains non-forced, matching its baseline behavior.
- The 8 app tables are empty.
- Owner-facing policies on `app_profiles`, `app_settings`,
  `alarm_preferences`, `submitted_checkins`, `deletion_tombstones`,
  `mutation_receipts`, and `persona_answer_aggregates` are all scoped through
  `auth.uid()`.
- `anon` has no table grant on any new app table.
- The integrated iOS client sends remote writes only through
  `public.apply_sync_mutation`. Live privilege inspection also found the
  repository's legacy owner-scoped column-level INSERT/UPDATE grants on the
  non-persona tables. They remain constrained by `auth.uid()` RLS but mean the
  database does not enforce RPC exclusivity for those legacy entities.
- `public.apply_sync_mutation` is SECURITY INVOKER, has an empty `search_path`,
  is not executable by `anon`, and is executable by `authenticated`.
- `public.account_deletion_audit` has RLS and no client policy or client table
  grant. The advisor reports this as informational because the table is not a
  client-facing relation.

No production fixtures were inserted. Cross-owner isolation, deletion
cascades, tombstones, stale-resurrection rejection, and RPC payload validation
were verified by policy/function/constraint inspection only in the live
project. Their behavioral pgTAP suites remain isolated-runtime evidence and
were not executed against production.

The security advisor still reports three unrelated baseline warnings preserved
by authorization: the waitlist's intentionally broad anonymous INSERT policy,
and anonymous/authenticated execution of the pre-existing
`public.rls_auto_enable()` SECURITY DEFINER function. Remediation references:

- https://supabase.com/docs/guides/database/database-linter?lint=0024_permissive_rls_policy
- https://supabase.com/docs/guides/database/database-linter?lint=0028_anon_security_definer_function_executable
- https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable

The performance advisor reports only expected unused-index informational
notices on the newly empty tables:
https://supabase.com/docs/guides/database/database-linter?lint=0005_unused_index.

## Local deterministic evidence

Passed:

- `git diff --check`
- `scripts/phase_1c_contract_check.sh` through Git for Windows Bash
- `scripts/secret_scan.sh` through Git for Windows Bash
- Privacy manifest XML and exact collected-data/required-reason structure
  validation through Python `plistlib`
- Static exact-source API check against the pinned Supabase Swift 2.53.0 source
  for OAuth session return type, callback requirement, refresh, and expiry

Not run:

- Swift unit tests
- Xcode project generation/build
- Xcode UI tests or simulator
- isolated Supabase/pgTAP runtime tests
- hosted macOS/Codemagic
- physical-iPhone tests, including locked-device and terminated-app widget
  behavior

This Windows host has no Swift compiler, Xcode, XcodeGen, usable local
Supabase/Docker runtime, or macOS simulator. No unrun test is recorded as
passing.

## External configuration and asset blockers

- A current public Supabase publishable key is configured only in ignored local
  developer configuration. It is not committed.
- OAuth remains intentionally disabled until an approved `spc:` callback URL
  is supplied and added to the Supabase Auth redirect allow list, and the
  Apple and Google provider consoles plus Supabase Auth contain the real client
  IDs/secrets. No redirect URL, client ID, secret, bundle signing credential,
  or provider credential was invented.
- No account-deletion Edge Function is deployed in the authorized project, so
  remote account deletion cannot complete until that reviewed server boundary
  is deployed separately.
- Approved production Paralux-provided audio assets and rights/provenance
  records are absent. The app exposes the catalog boundary but keeps those
  choices unavailable instead of fabricating audio.
- Figma `get_design_context` was attempted read-only for node `299:358`; the
  node resolved as a page/nothing-selected context, and the next metadata call
  was blocked by the Figma Starter-plan MCP limit. The supplied SVG exports and
  PRD were therefore used for the visual implementation.

No push, PR, deployment, TestFlight publication, Codemagic trigger, or Figma
write occurred.
