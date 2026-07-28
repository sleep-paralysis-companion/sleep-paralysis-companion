# Synchronization State Machine and Conflict Rules

States are `pending`, `syncing`, `synced`, `conflicted`, `failedRecoverable`, `authRequired`, and
`deleted`. GRDB remains the UI authority. The queue enforces one in-flight operation per entity and
a stable idempotency key per semantic revision.

## Mutation compatibility

The production payload provider and the database RPC enforce the same matrix before any receipt or
entity write:

| Operation | Valid entity/payload types |
|---|---|
| `upsert` | profile, settings, alarm, check-in |
| `convert` | profile, settings, alarm, check-in |
| `delete` | tombstone only |

The payload `id`, queued `entityID`, RPC `p_entity_id`, receipt `entity_id`, acknowledgment
`entityID`, entity-revision key, and conflict-grouping key are always the same mutation identity.
For deletion that identity is the **tombstone ID**. The deleted check-in ID remains only the
tombstone payload's `entity_id`. This separation makes a tombstone independently idempotent while
retaining the target needed to soft-delete the remote check-in and prevent resurrection.

The production `LocalDatabaseOutboundPayloadProvider` looks up the row using that mutation
identity, checks the profile/entity/revision tuple, and substitutes the authenticated user ID. It
never accepts an owner ID from a queued operation or caller. Normal synchronization requires an
account-linked profile. Conversion additionally requires the persisted checkpoint's exact expected
user. The composition root wires this adapter and the Supabase gateway into
`SynchronizationEngine`; guest synchronization is not started automatically.

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
