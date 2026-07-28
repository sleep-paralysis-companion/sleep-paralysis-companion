begin;

create extension if not exists pgcrypto with schema extensions;

alter table public.mutation_receipts
  add column base_revision bigint,
  add column payload_hash text;

update public.mutation_receipts
set base_revision = greatest(entity_revision - 1, 0),
    payload_hash = repeat('0', 64);

alter table public.mutation_receipts
  alter column base_revision set not null,
  alter column payload_hash set not null,
  add constraint mutation_receipts_base_revision_nonnegative
    check (base_revision >= 0),
  add constraint mutation_receipts_revision_step
    check (entity_revision = base_revision + 1),
  add constraint mutation_receipts_payload_hash_shape
    check (payload_hash ~ '^[0-9a-f]{64}$'),
  add constraint mutation_receipts_operation_entity_compatibility
    check (
      (
        operation in ('upsert', 'convert')
        and entity_type in ('profile', 'settings', 'alarm', 'checkin')
      )
      or (operation = 'delete' and entity_type = 'tombstone')
    );

alter table public.account_deletion_audit
  add column request_binding text;

update public.account_deletion_audit
set request_binding = repeat('0', 64);

alter table public.account_deletion_audit
  alter column request_binding set not null,
  add constraint account_deletion_audit_request_binding_shape
    check (request_binding ~ '^[0-9a-f]{64}$');

grant insert (base_revision, payload_hash)
  on public.mutation_receipts to authenticated;

create or replace function private.prevent_checkin_resurrection()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if tg_op = 'UPDATE' and old.deleted_at is not null and new.deleted_at is null then
    raise exception 'deleted check-in cannot be resurrected' using errcode = '23514';
  end if;

  if new.deleted_at is null and exists (
    select 1
    from public.deletion_tombstones
    where owner_user_id = new.owner_user_id
      and entity_type = 'checkin'
      and entity_id = new.id
  ) then
    raise exception 'tombstoned check-in cannot be resurrected' using errcode = '23514';
  end if;

  return new;
end;
$$;

drop trigger submitted_checkins_no_resurrection on public.submitted_checkins;
create trigger submitted_checkins_no_resurrection
before insert or update on public.submitted_checkins
for each row execute function private.prevent_checkin_resurrection();

drop function public.apply_sync_mutation(
  uuid, uuid, text, uuid, text, bigint, jsonb
);

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
begin
  if v_owner_user_id is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;

  if p_receipt_id is null
    or p_idempotency_key is null
    or p_entity_id is null
    or p_payload is null
    or jsonb_typeof(p_payload) <> 'object'
    or p_base_revision < 0
    or p_entity_revision <= 0
    or p_entity_revision <> p_base_revision + 1 then
    raise exception 'invalid mutation envelope' using errcode = '22023';
  end if;

  if not (
    (
      p_operation in ('upsert', 'convert')
      and p_entity_type in ('profile', 'settings', 'alarm', 'checkin')
    )
    or (p_operation = 'delete' and p_entity_type = 'tombstone')
  ) then
    raise exception 'incompatible operation and entity type' using errcode = '22023';
  end if;

  if not (p_payload ? 'id')
    or not (p_payload ? 'owner_user_id')
    or (p_payload ->> 'id')::uuid is distinct from p_entity_id
    or (p_payload ->> 'owner_user_id')::uuid is distinct from v_owner_user_id then
    raise exception 'payload ownership or identity mismatch' using errcode = '42501';
  end if;

  case p_entity_type
    when 'profile' then
      if p_payload - array[
        'id', 'owner_user_id', 'profile_created_at', 'revision'
      ]::text[] <> '{}'::jsonb
        or not (p_payload ?& array[
          'id', 'owner_user_id', 'profile_created_at', 'revision'
        ])
        or (p_payload ->> 'revision')::bigint is distinct from p_entity_revision then
        raise exception 'malformed profile payload' using errcode = '22023';
      end if;
    when 'settings' then
      if p_payload - array[
        'id', 'owner_user_id', 'preferred_grounding_asset_id',
        'preferred_modality', 'haptics_enabled', 'revision'
      ]::text[] <> '{}'::jsonb
        or not (p_payload ?& array[
          'id', 'owner_user_id', 'preferred_modality', 'haptics_enabled', 'revision'
        ])
        or (p_payload ->> 'revision')::bigint is distinct from p_entity_revision then
        raise exception 'malformed settings payload' using errcode = '22023';
      end if;
    when 'alarm' then
      if p_payload - array[
        'id', 'owner_user_id', 'local_hour', 'local_minute',
        'weekdays_mask', 'snooze_minutes', 'enabled_intent', 'revision'
      ]::text[] <> '{}'::jsonb
        or not (p_payload ?& array[
          'id', 'owner_user_id', 'local_hour', 'local_minute',
          'weekdays_mask', 'enabled_intent', 'revision'
        ])
        or (p_payload ->> 'revision')::bigint is distinct from p_entity_revision then
        raise exception 'malformed alarm payload' using errcode = '22023';
      end if;
    when 'checkin' then
      if p_payload - array[
        'id', 'owner_user_id', 'reported_for_local_date', 'reported_timezone_id', 'occurrence',
        'perceived_intensity', 'present_state', 'note', 'created_at',
        'updated_at', 'revision', 'deleted_at'
      ]::text[] <> '{}'::jsonb
        or not (p_payload ?& array[
          'id', 'owner_user_id', 'reported_for_local_date', 'reported_timezone_id',
          'occurrence', 'created_at', 'updated_at', 'revision'
        ])
        or (p_payload ->> 'revision')::bigint is distinct from p_entity_revision
        or p_payload ->> 'deleted_at' is not null then
        raise exception 'malformed check-in payload' using errcode = '22023';
      end if;
      if exists (
        select 1
        from public.deletion_tombstones
        where owner_user_id = v_owner_user_id
          and entity_type = 'checkin'
          and entity_id = p_entity_id
      ) then
        raise exception 'tombstoned check-in cannot be resurrected' using errcode = '23514';
      end if;
    when 'tombstone' then
      if p_payload - array[
        'id', 'owner_user_id', 'entity_type', 'entity_id',
        'deleted_revision', 'deleted_at'
      ]::text[] <> '{}'::jsonb
        or not (p_payload ?& array[
          'id', 'owner_user_id', 'entity_type', 'entity_id',
          'deleted_revision', 'deleted_at'
        ])
        or p_payload ->> 'entity_type' <> 'checkin'
        or (p_payload ->> 'entity_id')::uuid = p_entity_id
        or (p_payload ->> 'deleted_revision')::bigint is distinct from p_entity_revision
        or (p_payload ->> 'deleted_at')::timestamptz is null then
        raise exception 'malformed tombstone payload' using errcode = '22023';
      end if;
    else
      raise exception 'unsupported entity type' using errcode = '22023';
  end case;

  v_payload_hash := encode(
    extensions.digest(convert_to(p_payload::text, 'UTF8'), 'sha256'),
    'hex'
  );

  select * into v_existing
  from public.mutation_receipts
  where owner_user_id = v_owner_user_id
    and idempotency_key = p_idempotency_key;

  if found then
    if v_existing.entity_type <> p_entity_type
      or v_existing.entity_id <> p_entity_id
      or v_existing.operation <> p_operation
      or v_existing.base_revision <> p_base_revision
      or v_existing.entity_revision <> p_entity_revision
      or v_existing.payload_hash <> v_payload_hash then
      raise exception 'idempotency key payload mismatch' using errcode = '23505';
    end if;

    if v_existing.entity_type = 'tombstone' then
      select t.acknowledged_at, t.purge_after
      into v_acknowledged_at, v_purge_after
      from public.deletion_tombstones as t
      where t.owner_user_id = v_owner_user_id
        and t.id = v_existing.entity_id;
    end if;

    return query
      select
        v_existing.id,
        v_existing.entity_revision,
        v_acknowledged_at,
        v_purge_after;
    return;
  end if;

  insert into public.mutation_receipts (
    id,
    owner_user_id,
    idempotency_key,
    entity_type,
    entity_id,
    operation,
    base_revision,
    entity_revision,
    payload_hash,
    expires_at
  ) values (
    p_receipt_id,
    v_owner_user_id,
    p_idempotency_key,
    p_entity_type,
    p_entity_id,
    p_operation,
    p_base_revision,
    p_entity_revision,
    v_payload_hash,
    statement_timestamp() + interval '30 days'
  );

  case p_entity_type
    when 'profile' then
      update public.app_profiles
      set profile_created_at = (p_payload ->> 'profile_created_at')::timestamptz,
          revision = p_entity_revision
      where id = p_entity_id
        and revision = p_base_revision;
      if not found then
        if exists (
          select 1 from public.app_profiles
          where id = p_entity_id
        ) or p_base_revision <> 0 then
          raise exception 'profile revision conflict' using errcode = '40001';
        end if;
        insert into public.app_profiles (
          id, owner_user_id, profile_created_at, revision
        ) values (
          p_entity_id,
          v_owner_user_id,
          (p_payload ->> 'profile_created_at')::timestamptz,
          p_entity_revision
        );
      end if;
    when 'settings' then
      update public.app_settings
      set preferred_grounding_asset_id = p_payload ->> 'preferred_grounding_asset_id',
          preferred_modality = p_payload ->> 'preferred_modality',
          haptics_enabled = (p_payload ->> 'haptics_enabled')::boolean,
          revision = p_entity_revision
      where id = p_entity_id
        and revision = p_base_revision;
      if not found then
        if exists (
          select 1 from public.app_settings
          where id = p_entity_id
        ) or p_base_revision <> 0 then
          raise exception 'settings revision conflict' using errcode = '40001';
        end if;
        insert into public.app_settings (
          id, owner_user_id, preferred_grounding_asset_id,
          preferred_modality, haptics_enabled, revision
        ) values (
          p_entity_id,
          v_owner_user_id,
          p_payload ->> 'preferred_grounding_asset_id',
          p_payload ->> 'preferred_modality',
          (p_payload ->> 'haptics_enabled')::boolean,
          p_entity_revision
        );
      end if;
    when 'alarm' then
      update public.alarm_preferences
      set local_hour = (p_payload ->> 'local_hour')::smallint,
          local_minute = (p_payload ->> 'local_minute')::smallint,
          weekdays_mask = (p_payload ->> 'weekdays_mask')::smallint,
          snooze_minutes = (p_payload ->> 'snooze_minutes')::smallint,
          enabled_intent = (p_payload ->> 'enabled_intent')::boolean,
          revision = p_entity_revision
      where id = p_entity_id
        and revision = p_base_revision;
      if not found then
        if exists (
          select 1 from public.alarm_preferences
          where id = p_entity_id
        ) or p_base_revision <> 0 then
          raise exception 'alarm revision conflict' using errcode = '40001';
        end if;
        insert into public.alarm_preferences (
          id, owner_user_id, local_hour, local_minute, weekdays_mask,
          snooze_minutes, enabled_intent, revision
        ) values (
          p_entity_id,
          v_owner_user_id,
          (p_payload ->> 'local_hour')::smallint,
          (p_payload ->> 'local_minute')::smallint,
          (p_payload ->> 'weekdays_mask')::smallint,
          (p_payload ->> 'snooze_minutes')::smallint,
          (p_payload ->> 'enabled_intent')::boolean,
          p_entity_revision
        );
      end if;
    when 'checkin' then
      update public.submitted_checkins
      set reported_for_local_date = (p_payload ->> 'reported_for_local_date')::date,
          reported_timezone_id = p_payload ->> 'reported_timezone_id',
          occurrence = p_payload ->> 'occurrence',
          perceived_intensity = p_payload ->> 'perceived_intensity',
          present_state = p_payload ->> 'present_state',
          note = p_payload ->> 'note',
          updated_at = (p_payload ->> 'updated_at')::timestamptz,
          revision = p_entity_revision
      where id = p_entity_id
        and revision = p_base_revision;
      if not found then
        if exists (
          select 1 from public.submitted_checkins
          where id = p_entity_id
        ) or p_base_revision <> 0 then
          raise exception 'check-in revision conflict' using errcode = '40001';
        end if;
        insert into public.submitted_checkins (
          id, owner_user_id, reported_for_local_date, reported_timezone_id,
          occurrence, perceived_intensity, present_state, note,
          created_at, updated_at, revision, deleted_at
        ) values (
          p_entity_id,
          v_owner_user_id,
          (p_payload ->> 'reported_for_local_date')::date,
          p_payload ->> 'reported_timezone_id',
          p_payload ->> 'occurrence',
          p_payload ->> 'perceived_intensity',
          p_payload ->> 'present_state',
          p_payload ->> 'note',
          (p_payload ->> 'created_at')::timestamptz,
          (p_payload ->> 'updated_at')::timestamptz,
          p_entity_revision,
          null
        );
      end if;
    when 'tombstone' then
      select revision, deleted_at
      into v_current_revision, v_current_deleted_at
      from public.submitted_checkins
      where owner_user_id = v_owner_user_id
        and id = (p_payload ->> 'entity_id')::uuid
      for update;

      if found and v_current_deleted_at is null then
        if v_current_revision <> p_base_revision then
          raise exception 'delete revision conflict' using errcode = '40001';
        end if;
        update public.submitted_checkins
        set deleted_at = (p_payload ->> 'deleted_at')::timestamptz,
            updated_at = greatest(
              updated_at,
              (p_payload ->> 'deleted_at')::timestamptz
            ),
            revision = p_entity_revision
        where owner_user_id = v_owner_user_id
          and id = (p_payload ->> 'entity_id')::uuid;
      elsif found and v_current_revision <> p_entity_revision then
        raise exception 'delete revision conflict' using errcode = '40001';
      end if;

      v_acknowledged_at := statement_timestamp();
      v_purge_after := v_acknowledged_at + interval '30 days';
      insert into public.deletion_tombstones (
        id,
        owner_user_id,
        entity_type,
        entity_id,
        deleted_revision,
        deleted_at,
        acknowledged_at,
        purge_after
      ) values (
        p_entity_id,
        v_owner_user_id,
        p_payload ->> 'entity_type',
        (p_payload ->> 'entity_id')::uuid,
        (p_payload ->> 'deleted_revision')::bigint,
        (p_payload ->> 'deleted_at')::timestamptz,
        v_acknowledged_at,
        v_purge_after
      );
    else
      raise exception 'unsupported entity type' using errcode = '22023';
  end case;

  return query
    select
      p_receipt_id,
      p_entity_revision,
      v_acknowledged_at,
      v_purge_after;
end;
$$;

revoke all on function public.apply_sync_mutation(
  uuid, uuid, text, uuid, text, bigint, bigint, jsonb
) from public, anon;
grant execute on function public.apply_sync_mutation(
  uuid, uuid, text, uuid, text, bigint, bigint, jsonb
) to authenticated;

commit;
