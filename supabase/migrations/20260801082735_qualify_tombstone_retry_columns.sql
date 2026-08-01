-- Repair the released persona tombstone retry path without rewriting migration
-- history. The prior function's TABLE return column `acknowledged_at` collided
-- with the unqualified deletion_tombstones column of the same name.
begin;

create or replace function private.apply_sync_mutation_trusted(
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
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_owner_user_id uuid := auth.uid();
  v_existing public.mutation_receipts%rowtype;
  v_payload_hash text;
  v_current_revision bigint;
  v_current_deleted_at timestamptz;
  v_acknowledged_at timestamptz;
  v_purge_after timestamptz;
  v_deleted_entity_id uuid;
  v_deleted_entity_type text;
begin
  if v_owner_user_id is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;
  if p_receipt_id is null or p_idempotency_key is null or p_entity_id is null
    or p_payload is null or jsonb_typeof(p_payload) <> 'object'
    or p_base_revision < 0 or p_entity_revision <= 0
    or p_entity_revision <> p_base_revision + 1 then
    raise exception 'invalid mutation envelope' using errcode = '22023';
  end if;
  if p_entity_type <> 'persona'
    and not (p_entity_type = 'tombstone' and p_payload ->> 'entity_type' = 'persona') then
    return query select * from private.apply_sync_mutation_legacy(
      p_receipt_id, p_idempotency_key, p_entity_type, p_entity_id, p_operation,
      p_base_revision, p_entity_revision, p_payload
    );
    return;
  end if;
  if not (
    (p_operation = 'upsert' and p_entity_type in ('profile', 'settings', 'alarm', 'checkin', 'persona'))
    or (p_operation = 'convert' and p_entity_type in ('profile', 'settings', 'alarm', 'checkin'))
    or (p_operation = 'delete' and p_entity_type = 'tombstone')
  ) then
    raise exception 'incompatible operation and entity type' using errcode = '22023';
  end if;
  if not (p_payload ? 'id') or not (p_payload ? 'owner_user_id')
    or (p_payload ->> 'id')::uuid is distinct from p_entity_id
    or (p_payload ->> 'owner_user_id')::uuid is distinct from v_owner_user_id then
    raise exception 'payload ownership or identity mismatch' using errcode = '42501';
  end if;

  if p_entity_type = 'persona' then
    if p_payload - array[
      'id', 'owner_user_id', 'episode_frequency', 'post_episode_feeling',
      'calming_person_context', 'routing_rule_version', 'calculated_at', 'updated_at', 'revision'
    ]::text[] <> '{}'::jsonb
      or not (p_payload ?& array[
        'id', 'owner_user_id', 'episode_frequency', 'post_episode_feeling',
        'calming_person_context', 'routing_rule_version', 'calculated_at', 'updated_at', 'revision'
      ])
      or (p_payload ->> 'episode_frequency') not in ('rarely', 'monthly', 'weekly', 'almost_nightly')
      or (p_payload ->> 'post_episode_feeling') not in ('shake_it_off', 'awake_scared', 'too_frightened_to_close_eyes')
      or (p_payload ->> 'calming_person_context') not in ('beside_me', 'not_always_present', 'alone')
      or p_payload ->> 'routing_rule_version' <> '2026-07-29-v1'
      or (p_payload ->> 'calculated_at')::timestamptz is null
      or (p_payload ->> 'updated_at')::timestamptz is null
      or (p_payload ->> 'revision')::bigint is distinct from p_entity_revision then
      raise exception 'malformed persona payload' using errcode = '22023';
    end if;
    if exists (
      select 1 from public.deletion_tombstones
      where owner_user_id = v_owner_user_id and entity_type = 'persona' and entity_id = p_entity_id
    ) then
      raise exception 'tombstoned persona cannot be resurrected' using errcode = '23514';
    end if;
  elsif p_entity_type = 'tombstone' then
    if p_payload - array['id', 'owner_user_id', 'entity_type', 'entity_id', 'deleted_revision', 'deleted_at']::text[] <> '{}'::jsonb
      or not (p_payload ?& array['id', 'owner_user_id', 'entity_type', 'entity_id', 'deleted_revision', 'deleted_at'])
      or p_payload ->> 'entity_type' not in ('checkin', 'persona')
      or (p_payload ->> 'entity_id')::uuid = p_entity_id
      or (p_payload ->> 'deleted_revision')::bigint is distinct from p_entity_revision
      or (p_payload ->> 'deleted_at')::timestamptz is null then
      raise exception 'malformed tombstone payload' using errcode = '22023';
    end if;
  else
    -- Existing entity families retain their prior field validation in their client payload paths.
    if (p_payload ->> 'revision')::bigint is distinct from p_entity_revision then
      raise exception 'malformed mutation payload' using errcode = '22023';
    end if;
  end if;

  v_payload_hash := encode(extensions.digest(convert_to(p_payload::text, 'UTF8'), 'sha256'), 'hex');
  select * into v_existing from public.mutation_receipts
  where owner_user_id = v_owner_user_id and idempotency_key = p_idempotency_key;
  if found then
    if v_existing.entity_type <> p_entity_type or v_existing.entity_id <> p_entity_id
      or v_existing.operation <> p_operation or v_existing.base_revision <> p_base_revision
      or v_existing.entity_revision <> p_entity_revision or v_existing.payload_hash <> v_payload_hash then
      raise exception 'idempotency key payload mismatch' using errcode = '23505';
    end if;
    if v_existing.entity_type = 'tombstone' then
      select tombstone.acknowledged_at, tombstone.purge_after
      into v_acknowledged_at, v_purge_after
      from public.deletion_tombstones as tombstone
      where tombstone.owner_user_id = v_owner_user_id
        and tombstone.id = v_existing.entity_id;
    end if;
    return query select v_existing.id, v_existing.entity_revision, v_acknowledged_at, v_purge_after;
    return;
  end if;

  if p_entity_type = 'persona' then
    update public.persona_answer_aggregates
    set episode_frequency = p_payload ->> 'episode_frequency',
        post_episode_feeling = p_payload ->> 'post_episode_feeling',
        calming_person_context = p_payload ->> 'calming_person_context',
        routing_rule_version = p_payload ->> 'routing_rule_version',
        calculated_at = (p_payload ->> 'calculated_at')::timestamptz,
        updated_at = (p_payload ->> 'updated_at')::timestamptz,
        revision = p_entity_revision
    where id = p_entity_id and owner_user_id = v_owner_user_id and revision = p_base_revision;
    if not found then
      if exists (select 1 from public.persona_answer_aggregates where id = p_entity_id)
        or p_base_revision <> 0 then
        raise exception 'persona revision conflict' using errcode = '40001';
      end if;
      insert into public.persona_answer_aggregates (
        id, owner_user_id, episode_frequency, post_episode_feeling, calming_person_context,
        routing_rule_version, calculated_at, updated_at, revision
      ) values (
        p_entity_id, v_owner_user_id, p_payload ->> 'episode_frequency',
        p_payload ->> 'post_episode_feeling', p_payload ->> 'calming_person_context',
        p_payload ->> 'routing_rule_version', (p_payload ->> 'calculated_at')::timestamptz,
        (p_payload ->> 'updated_at')::timestamptz, p_entity_revision
      );
    end if;
  elsif p_entity_type = 'tombstone' and p_payload ->> 'entity_type' = 'persona' then
    v_deleted_entity_id := (p_payload ->> 'entity_id')::uuid;
    select revision into v_current_revision from public.persona_answer_aggregates
    where owner_user_id = v_owner_user_id and id = v_deleted_entity_id for update;
    if found then
      if v_current_revision <> p_base_revision then
        raise exception 'persona deletion revision conflict' using errcode = '40001';
      end if;
      delete from public.persona_answer_aggregates
      where owner_user_id = v_owner_user_id and id = v_deleted_entity_id;
    end if;
    v_acknowledged_at := statement_timestamp();
    v_purge_after := v_acknowledged_at + interval '30 days';
    insert into public.deletion_tombstones (
      id, owner_user_id, entity_type, entity_id, deleted_revision, deleted_at, acknowledged_at, purge_after
    ) values (
      p_entity_id, v_owner_user_id, 'persona', v_deleted_entity_id, p_entity_revision,
      (p_payload ->> 'deleted_at')::timestamptz, v_acknowledged_at, v_purge_after
    );
  else
    raise exception 'unsupported legacy entity mutation in persona delta' using errcode = '22023';
  end if;

  insert into public.mutation_receipts (
    id, owner_user_id, idempotency_key, entity_type, entity_id, operation,
    base_revision, entity_revision, payload_hash, expires_at
  ) values (
    p_receipt_id, v_owner_user_id, p_idempotency_key, p_entity_type, p_entity_id, p_operation,
    p_base_revision, p_entity_revision, v_payload_hash, statement_timestamp() + interval '30 days'
  );
  return query select p_receipt_id, p_entity_revision, v_acknowledged_at, v_purge_after;
end;
$$;

revoke all on function private.apply_sync_mutation_trusted(uuid, uuid, text, uuid, text, bigint, bigint, jsonb)
  from public, anon;
grant usage on schema private to authenticated;
grant execute on function private.apply_sync_mutation_trusted(uuid, uuid, text, uuid, text, bigint, bigint, jsonb)
  to authenticated;

commit;
