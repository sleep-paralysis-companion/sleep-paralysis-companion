-- Follow-up to the released persona/audio delta.  Do not rewrite the prior
-- migration: deployed migration history must remain reproducible.
begin;

-- Persona rows are read-only to ordinary clients. All writes, including
-- deletes, must cross the idempotent receipt/tombstone boundary.
revoke all on public.persona_answer_aggregates from anon, authenticated;
grant select on public.persona_answer_aggregates to authenticated;

-- The prior public invoker RPC needed table DML grants. Move the same checked
-- implementation behind a non-exposed private definer function, then expose a
-- thin invoker wrapper. The trusted function still obtains the owner solely
-- from auth.uid() and retains its empty search_path; it is not callable by anon
-- or PUBLIC.
alter function public.apply_sync_mutation(uuid, uuid, text, uuid, text, bigint, bigint, jsonb)
  set schema private;
alter function private.apply_sync_mutation(uuid, uuid, text, uuid, text, bigint, bigint, jsonb)
  rename to apply_sync_mutation_trusted;
alter function private.apply_sync_mutation_trusted(uuid, uuid, text, uuid, text, bigint, bigint, jsonb)
  security definer;
alter function private.apply_sync_mutation_trusted(uuid, uuid, text, uuid, text, bigint, bigint, jsonb)
  set search_path = '';
revoke all on function private.apply_sync_mutation_trusted(uuid, uuid, text, uuid, text, bigint, bigint, jsonb)
  from public, anon;
grant usage on schema private to authenticated;
grant execute on function private.apply_sync_mutation_trusted(uuid, uuid, text, uuid, text, bigint, bigint, jsonb)
  to authenticated;

create function public.apply_sync_mutation(
  p_receipt_id uuid,
  p_idempotency_key uuid,
  p_entity_type text,
  p_entity_id uuid,
  p_operation text,
  p_base_revision bigint,
  p_entity_revision bigint,
  p_payload jsonb
)
returns table (
  server_mutation_id uuid,
  accepted_revision bigint,
  acknowledged_at timestamptz,
  purge_after timestamptz
)
language sql
security invoker
set search_path = ''
as $$
  select * from private.apply_sync_mutation_trusted(
    p_receipt_id, p_idempotency_key, p_entity_type, p_entity_id, p_operation,
    p_base_revision, p_entity_revision, p_payload
  );
$$;

revoke all on function public.apply_sync_mutation(uuid, uuid, text, uuid, text, bigint, bigint, jsonb)
  from public, anon;
grant execute on function public.apply_sync_mutation(uuid, uuid, text, uuid, text, bigint, bigint, jsonb)
  to authenticated;

commit;
