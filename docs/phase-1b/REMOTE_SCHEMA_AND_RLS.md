# Remote Schema and RLS Matrix

Migration:
`supabase/migrations/20260728002909_phase_1b_app_sync_foundation.sql`

| Table | Client operations | Ownership/RLS | Server fields protected |
|---|---|---|---|
| `app_profiles` | select/insert/update/delete | `owner_user_id = auth.uid()` | owner and server timestamp not updateable |
| `app_settings` | select/insert/update/delete | same | owner/server timestamp excluded from update grants |
| `alarm_preferences` | select/insert/update/delete | same | same |
| `submitted_checkins` | select/insert/update/delete | same | same; deleted rows cannot be resurrected |
| `deletion_tombstones` | select/insert/ack/delete | same | owner/entity/delete facts immutable |
| `mutation_receipts` | select/insert/delete | same | receipt and semantic uniqueness enforce replay safety |
| `account_deletion_audit` | none | forced RLS, no client policy | service-role only |

All user tables have immutable `owner_user_id` foreign keys to `auth.users`, RLS enabled and forced,
separate policies per operation, and UPDATE policies with both `USING` and `WITH CHECK`. `anon`
receives no table or function grants. Authenticated grants are explicit and column-scoped.
Default privileges revoke future table, sequence, and function exposure.

`apply_sync_mutation` is a `SECURITY INVOKER` RPC. It derives ownership from `auth.uid()`, rejects
unknown/forged/server-owned payload fields, writes the receipt and entity in one transaction,
enforces revision preconditions, and returns an existing acknowledgment for an exact replay.

The policy pgTAP suite has 61 assertions covering owner-positive operations,
cross-user/anonymous denial, forged ownership, owner reassignment, over-posting, revisions,
deleted accounts, function privileges, default privileges, replay, and resurrection prevention.
Seven local advisor-equivalent assertions cover RLS/forced-RLS, public `SECURITY DEFINER`
functions, RLS init-plan form, foreign-key indexes, primary keys, and invalid indexes. Both suites
use only synthetic `.invalid` identities.
