# Remote schema, RLS, and synchronization

Migration `20260728220925_phase_1b_persona_audio_delta.sql` adds only `public.persona_answer_aggregates`; there is no personal-audio table, bucket, policy, or storage reference. The table has forced RLS, `(select auth.uid()) = owner_user_id` policies, ownership/foreign-key indexes, generated `derived_persona`, owner immutability/revision trigger, and least-privilege grants.

The mutation RPC validates a complete persona payload before receipt insertion, computes persona in Postgres, reuses stable identity/revision rules, and deletes through a persona tombstone. Draft/audio entities are rejected. Existing supported entity paths delegate to the prior isolated mutation implementation.

## Follow-up mutation privilege boundary

The immutable follow-up migration `20260729113000_phase_1b_persona_audio_mutation_boundary_repair.sql` revokes authenticated direct `INSERT`, `UPDATE`, and `DELETE` on `persona_answer_aggregates`; authenticated retains owner-scoped `SELECT` only. A `SECURITY INVOKER` implementation could no longer write the aggregate or its receipt/tombstone after those grants were removed, so the checked implementation is moved to `private.apply_sync_mutation_trusted` as `SECURITY DEFINER` with `search_path = ''`.

This is not a public definer escape hatch: the exposed `public.apply_sync_mutation` wrapper remains `SECURITY INVOKER`; the trusted function is in the non-exposed `private` schema; `PUBLIC` and `anon` execution are revoked; and `authenticated` receives only the schema/function access required for the invoker wrapper to reach the private function. The trusted implementation derives owner only from `auth.uid()`, validates payload owner against it before receipt insertion, uses schema-qualified relations under its empty search path, never consults JWT user metadata, and retains the prior operation/entity validation before delegating supported legacy entities. RLS continues to restrict table reads to the authenticated owner.

This is statically reviewed only. The expanded pgTAP privilege, malformed-payload, legacy-path, and account-cascade assertions remain **not run** until the isolated backend is available.
