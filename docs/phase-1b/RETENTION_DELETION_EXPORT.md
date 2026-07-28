# Retention, Deletion, and Export

> **Phase 1B delta required - 29 July 2026.** Retention/export/deletion for persona answers and local-only personal recordings/imports is controlled by [Persona and Personal Audio Product Realignment](../phase-0/PERSONA_AND_PERSONAL_AUDIO_REALIGNMENT.md) and is not covered by this prior-foundation evidence.

- Abandoned drafts: local only, purged after seven days, excluded from export.
- Submitted records/settings: retained until individual, local-data, or account deletion.
- Tombstones/mutation receipts: retained until remote acknowledgment and the bounded 30-day purge
  point; they are never exported.
- Export files: protected temporary files, maximum 24-hour lifetime, bounded cleanup.
- Minimal account-deletion audit: request ID, opaque SHA-256 request binding, outcome, completion,
  and 30-day purge only.

Individual deletion atomically marks the local record deleted, advances its revision, creates a
tombstone, and enqueues the stable delete operation. The local and remote schemas reject clearing a
non-null deletion marker.

Account deletion requires matching recent reauthentication and reuses the same request ID after an
interruption. The server-only Edge Function cryptographically verifies the access token and checks
provider-backed recent authentication before trusting `sub`. It derives a request/user-bound HMAC
retry capability from an environment-only secret. The client retains that capability only in
coordinator memory; the audit stores only its SHA-256 binding. A forged, expired, wrong-user, or
changed-request call cannot resume deletion. The same bound retry can complete after Auth deletion,
making the operation idempotent without trusting a now-invalid user JWT inside the handler.
`verify_jwt=true` remains a gateway defense, but caller identity is independently verified by the
handler for the initial privileged operation. The environment-only service role performs Auth
deletion, app-owned rows cascade, and the audit remains content-free. Subscription state is not
consulted.

The deterministic export contains a manifest, profile/settings/alarm metadata, and submitted
records in JSON/CSV. It excludes sessions/tokens, OAuth payloads, queue internals, tombstones,
diagnostics, transaction payloads, audio binaries, drafts, and cache internals. Export has no
entitlement dependency.
