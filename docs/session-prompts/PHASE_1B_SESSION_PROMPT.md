# Session Prompt: Phase 1B - Data, Authentication, Security, and Offline Foundation

You are working in the SP / Paralux repository. This session is exclusively for **Phase 1B: Data, authentication, security, and offline foundation**. Treat this prompt as the session's operating contract. Do not assume access to earlier chat.

## Entry gate

Read the execution plan, both engineering guides, all approved Phase 0 artifacts, the Phase 1A handoff, migration conventions, and repository guidance. Inspect `git status` and preserve unrelated changes. Confirm Gate 0 and Gate 1A passed. If an entry gate is missing, do not implement dependent data/auth code; report the precise blocker.

## Objective

Make local persistence, guest ownership, optional accounts, Supabase synchronization, deletion, and security deterministic before user-facing features depend on them.

## Product/data constraints

- SQLite through GRDB is the immediate source for core user-visible data.
- Guest/local-first use must not upload user data. Synchronization starts only after an explicit approved account transition.
- Supabase is the Phase 1 cloud authority for approved account-scoped sync; every user-owned row/file requires tested least-privilege row-level security (RLS) or private storage policy.
- Ultra-light check-in data is limited to approved occurrence, perceived intensity, recovery state, and optional note fields.
- No microphone/voice, HealthKit, AI, tracking, advertising profile, or unapproved free text.
- Commercial access state must be modeled separately from user data. Alarm and mandatory utilities remain free; all other product functions require verified StoreKit trial, subscription, approved grace, or lifetime access. Privacy/data/account/purchase-management operations are never blocked.

## Required implementation

- Implement versioned local schemas for approved settings, schedule/alarm, audio metadata/cache state, explicit episode records, ultra-light check-ins, sync metadata, account linkage, deletion/tombstone state, and access-policy cache if approved.
- Implement local migrations with transactions, rollback/recovery behavior, corruption/full-storage handling, and deterministic tests.
- Implement versioned Supabase migrations, constraints, foreign keys, indexes, ownership, RLS policies, private storage policies if needed, and policy tests in an isolated backend.
- Implement guest ownership and an atomic, retry-safe guest-to-account conversion. No partial conversion, duplicate upload, or silent loss.
- Implement synchronization as an explicit state machine: pending, syncing, synced, conflicted, failed, and deleted.
- Implement the approved conflict rule per entity. Do not hide last-write-wins behind timestamps or SDK defaults.
- Make sync idempotent and cancellation-aware; support retry/backoff without duplicate semantic records.
- Implement testable deletion tombstones and propagation across local rows, cached files, queued work, remote rows, and private objects.
- Define sign-in, token refresh/expiry/revocation, sign-out, reinstall, account conversion, account deletion, and multi-device outcomes.
- Store session tokens in Keychain. Apply approved data/file protection classes verified against locked-device needs.
- Implement export/deletion service boundaries before production data collection.
- Implement the minimal analytics/diagnostics allowlist; never include check-in answers, notes, episode data, tokens, signed URLs, audio paths, or raw payloads.

## Engineering rules

- Separate UI state, domain models, local rows, remote DTOs, synchronization state, and entitlement/access state.
- Views never operate on database rows or Supabase DTOs.
- Use one reviewed local serialization/isolation strategy; use actors where shared mutable access requires them.
- Stable IDs and explicit ownership scope are mandatory. Multi-step consistency belongs in transactions.
- Use structured concurrency, explicit cancellation, typed errors, redacted logging, and injected clocks/identifiers/network.
- No service-role key or privileged operation in the app. Client-written ownership/admin/entitlement claims are never server authority.
- Development/staging/production backends are isolated. Tests never target production.
- Do not add schema fields without requirement ID, purpose, sensitivity, retention, export, deletion, privacy category, and owner.

## Required tests/evidence

- Offline CRUD and relaunch for every core entity.
- Migration from every supported prior schema, interruption, rollback/recovery, corrupt data, and full storage.
- Guest-to-account success, cancellation, partial failure, retry, existing remote data, and duplicate prevention.
- Sync retry, stale result, network loss, backend outage, token expiry, conflict, tombstone, and multi-device ordering.
- Positive owner RLS tests and negative anonymous/cross-user/client-forged ownership/admin/entitlement tests.
- Sign-out, reinstall, token revocation, account deletion, Keychain cleanup, local data handling, and private file deletion.
- Export and deletion reconciliation against the approved data inventory.
- Secret/config/log scans.

## Gate 1B exit

Pass only when core records work offline, interrupted sync cannot duplicate or silently lose valid data, cross-user access is denied, lifecycle outcomes are documented/tested, and schema/policy automation runs against an isolated backend.

## Handoff

Report requirement IDs, migrations/schema versions, outcome, files/systems changed, decisions used, automated evidence, backend isolation/RLS evidence, privacy/security impact, limitations, blockers, whether Gate 1B passed, and the next safe Phase 1C work item. State what remains unverified.
