# Synchronization State Machine and Conflict Rules

States are `pending`, `syncing`, `synced`, `conflicted`, `failedRecoverable`, `authRequired`, and
`deleted`. GRDB remains the UI authority. The queue enforces one in-flight operation per entity and
a stable idempotency key per semantic revision.

Recoverable network/backend failures use exponential backoff from 2 seconds, 25% bounded jitter,
and a 15-minute cap. Clock and randomness are injected. Cancellation returns the operation to a
recoverable state with the same key. Authentication pauses work; validation, authorization, stale
acknowledgment, and revision conflicts do not retry indefinitely.

Entity conflict rules:

- Profile: account identity is authoritative; no timestamp choice.
- Settings/alarm intent: explicit device-or-account choice.
- Check-ins: different stable IDs form a union; identical content deduplicates; differing revisions
  of the same ID require an explicit local-or-remote revision choice.
- Tombstones: delete wins only when the deleted base includes the edit; otherwise require an
  explicit keep-edit-or-keep-delete choice.

Guest conversion states are `localOnly`, `authenticating`, `awaitingMergeChoice`, `converting`,
`linked`, `conflict`, `authRequired`, and `failedRecoverable`. The checkpoint stores conversion ID,
profile ID, expected user ID, choice, and progress. Retry and relaunch reuse the conversion and
operation IDs; a mismatched account cannot finalize.
