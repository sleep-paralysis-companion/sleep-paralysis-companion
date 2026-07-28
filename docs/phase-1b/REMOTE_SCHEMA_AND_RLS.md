# Remote Schema and RLS Matrix

Migrations:

- `supabase/migrations/20260728002909_phase_1b_app_sync_foundation.sql`
- `supabase/migrations/20260728085131_phase_1b_closure_contracts.sql`

| Table | Client operations | Ownership/RLS | Server fields protected |
|---|---|---|---|
| `app_profiles` | select/insert/update/delete | `owner_user_id = auth.uid()` | owner and server timestamp not updateable |
| `app_settings` | select/insert/update/delete | same | owner/server timestamp excluded from update grants |
| `alarm_preferences` | select/insert/update/delete | same | same |
| `submitted_checkins` | select/insert/update/delete | same | same; deleted rows cannot be resurrected |
| `deletion_tombstones` | select/insert/ack/delete | same | owner/entity/delete facts immutable |
| `mutation_receipts` | select/insert/delete | same | operation/entity matrix, base/revision step, payload hash, and semantic uniqueness enforce replay safety |
| `account_deletion_audit` | none | forced RLS, no client policy | service-role only; opaque request binding |

All user tables have immutable `owner_user_id` foreign keys to `auth.users`, RLS enabled and forced,
separate policies per operation, and UPDATE policies with both `USING` and `WITH CHECK`. `anon`
receives no table or function grants. Authenticated grants are explicit and column-scoped.
Default privileges revoke future table, sequence, and function exposure.

`apply_sync_mutation` is a `SECURITY INVOKER` RPC. It derives ownership from `auth.uid()`, validates
the operation/entity/payload matrix, mutation identity, allowed fields, base/revision step, and
payload hash before inserting a receipt. Receipt and entity writes share the PostgreSQL function
transaction, so a failed entity mutation leaves no receipt. Exact replays return the original
server mutation and tombstone acknowledgment; a changed operation, base, revision, entity, or
payload is rejected. The client cannot supply tombstone acknowledgment or purge timestamps.

The policy pgTAP suite has 61 assertions covering owner-positive operations,
cross-user/anonymous denial, forged ownership, owner reassignment, over-posting, revisions,
deleted accounts, function privileges, default privileges, replay, and resurrection prevention.
The mutation-contract pgTAP suite adds 34 assertions covering all nine valid operation/entity
combinations, incompatible combinations, malformed tombstones, changed replays, atomic receipt
rollback, deletion retry, server acknowledgment, and resurrection denial.
Seven local advisor-equivalent assertions cover RLS/forced-RLS, public `SECURITY DEFINER`
functions, RLS init-plan form, foreign-key indexes, primary keys, and invalid indexes. Both suites
use only synthetic `.invalid` identities.
