begin;

alter table public.deletion_tombstones
  drop constraint deletion_tombstones_entity_type_check,
  add constraint deletion_tombstones_entity_type_check
    check (entity_type in ('profile', 'settings', 'alarm', 'checkin', 'persona'));

alter table public.mutation_receipts
  drop constraint mutation_receipts_entity_type_check,
  drop constraint mutation_receipts_operation_entity_compatibility,
  add constraint mutation_receipts_entity_type_check
    check (entity_type in ('profile', 'settings', 'alarm', 'checkin', 'persona', 'tombstone')),
  add constraint mutation_receipts_operation_entity_compatibility
    check (
      (operation = 'upsert' and entity_type in ('profile', 'settings', 'alarm', 'checkin', 'persona'))
      or (operation = 'convert' and entity_type in ('profile', 'settings', 'alarm', 'checkin'))
      or (operation = 'delete' and entity_type = 'tombstone')
    );

create table public.persona_answer_aggregates (
  id uuid primary key,
  owner_user_id uuid not null unique references auth.users(id) on delete cascade,
  episode_frequency text not null
    check (episode_frequency in ('rarely', 'monthly', 'weekly', 'almost_nightly')),
  post_episode_feeling text not null
    check (post_episode_feeling in ('shake_it_off', 'awake_scared', 'too_frightened_to_close_eyes')),
  calming_person_context text not null
    check (calming_person_context in ('beside_me', 'not_always_present', 'alone')),
  routing_rule_version text not null check (routing_rule_version = '2026-07-29-v1'),
  calculated_at timestamptz not null,
  updated_at timestamptz not null,
  revision bigint not null check (revision > 0),
  derived_persona text generated always as (
    case
      when episode_frequency in ('weekly', 'almost_nightly')
        and post_episode_feeling in ('awake_scared', 'too_frightened_to_close_eyes')
        and calming_person_context = 'not_always_present'
        then 'frequent_intense_person_not_always_present'
      when episode_frequency in ('weekly', 'almost_nightly')
        and post_episode_feeling in ('awake_scared', 'too_frightened_to_close_eyes')
        and calming_person_context = 'beside_me'
        then 'frequent_intense_person_beside_user'
      when episode_frequency in ('weekly', 'almost_nightly')
        and post_episode_feeling in ('awake_scared', 'too_frightened_to_close_eyes')
        and calming_person_context = 'alone'
        then 'frequent_intense_no_calming_person'
      else 'general_default'
    end
  ) stored,
  server_updated_at timestamptz not null default statement_timestamp(),
  constraint persona_answer_aggregates_owner_id_unique unique (owner_user_id, id),
  constraint persona_answer_aggregates_updated_after_calculated
    check (updated_at >= calculated_at)
);
create index persona_answer_aggregates_owner_id_idx
  on public.persona_answer_aggregates(owner_user_id, id);
create trigger persona_answer_aggregates_revision_guard
before insert or update on public.persona_answer_aggregates
for each row execute function private.enforce_owned_revision();

alter table public.persona_answer_aggregates enable row level security;
alter table public.persona_answer_aggregates force row level security;
create policy persona_answer_aggregates_owner_select on public.persona_answer_aggregates
for select to authenticated
using ((select auth.uid()) = owner_user_id);
create policy persona_answer_aggregates_owner_insert on public.persona_answer_aggregates
for insert to authenticated
with check ((select auth.uid()) = owner_user_id);
create policy persona_answer_aggregates_owner_update on public.persona_answer_aggregates
for update to authenticated
using ((select auth.uid()) = owner_user_id)
with check ((select auth.uid()) = owner_user_id);
create policy persona_answer_aggregates_owner_delete on public.persona_answer_aggregates
for delete to authenticated
using ((select auth.uid()) = owner_user_id);

revoke all on public.persona_answer_aggregates from anon, authenticated;
grant select, delete on public.persona_answer_aggregates to authenticated;
grant insert (
  id, owner_user_id, episode_frequency, post_episode_feeling, calming_person_context,
  routing_rule_version, calculated_at, updated_at, revision
) on public.persona_answer_aggregates to authenticated;
grant update (
  episode_frequency, post_episode_feeling, calming_person_context,
  routing_rule_version, calculated_at, updated_at, revision
) on public.persona_answer_aggregates to authenticated;

alter function public.apply_sync_mutation(uuid, uuid, text, uuid, text, bigint, bigint, jsonb)
  set schema private;
alter function private.apply_sync_mutation(uuid, uuid, text, uuid, text, bigint, bigint, jsonb)
  rename to apply_sync_mutation_legacy;
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
language plpgsql
security invoker
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
      select acknowledged_at, purge_after into v_acknowledged_at, v_purge_after
      from public.deletion_tombstones where owner_user_id = v_owner_user_id and id = v_existing.entity_id;
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

revoke all on function public.apply_sync_mutation(uuid, uuid, text, uuid, text, bigint, bigint, jsonb)
  from public, anon;
grant execute on function public.apply_sync_mutation(uuid, uuid, text, uuid, text, bigint, bigint, jsonb)
  to authenticated;
revoke all on function private.apply_sync_mutation_legacy(uuid, uuid, text, uuid, text, bigint, bigint, jsonb)
  from public, anon;
grant usage on schema private to authenticated;
grant execute on function private.apply_sync_mutation_legacy(uuid, uuid, text, uuid, text, bigint, bigint, jsonb)
  to authenticated;

commit;
