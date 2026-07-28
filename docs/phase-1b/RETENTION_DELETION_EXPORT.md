# Retention, Deletion, and Export

- Abandoned drafts: local only, purged after seven days, excluded from export.
- Submitted records/settings: retained until individual, local-data, or account deletion.
- Tombstones/mutation receipts: retained until remote acknowledgment and the bounded 30-day purge
  point; they are never exported.
- Export files: protected temporary files, maximum 24-hour lifetime, bounded cleanup.
- Minimal account-deletion audit: request ID, outcome, completion, and 30-day purge only.

Individual deletion atomically marks the local record deleted, advances its revision, creates a
tombstone, and enqueues the stable delete operation. The local and remote schemas reject clearing a
non-null deletion marker.

Account deletion requires matching recent reauthentication and reuses the same request ID after an
interruption. The server-only Edge Function validates the user token, performs Auth deletion with
its environment-only service role, cascades app-owned data, and records only the content-free
audit. Subscription state is not consulted.

The deterministic export contains a manifest, profile/settings/alarm metadata, and submitted
records in JSON/CSV. It excludes sessions/tokens, OAuth payloads, queue internals, tombstones,
diagnostics, transaction payloads, audio binaries, drafts, and cache internals. Export has no
entitlement dependency.
