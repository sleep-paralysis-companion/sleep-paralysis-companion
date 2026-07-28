# Remote schema, RLS, and synchronization

Migration `20260728220925_phase_1b_persona_audio_delta.sql` adds only `public.persona_answer_aggregates`; there is no personal-audio table, bucket, policy, or storage reference. The table has forced RLS, `(select auth.uid()) = owner_user_id` policies, ownership/foreign-key indexes, generated `derived_persona`, owner immutability/revision trigger, and least-privilege grants.

The mutation RPC validates a complete persona payload before receipt insertion, computes persona in Postgres, reuses stable identity/revision rules, and deletes through a persona tombstone. Draft/audio entities are rejected. Existing supported entity paths delegate to the prior isolated mutation implementation.
