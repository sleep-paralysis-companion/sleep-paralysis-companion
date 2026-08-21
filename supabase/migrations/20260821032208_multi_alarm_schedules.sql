begin;

-- `alarm_preferences` is the synchronization entity for one complete named
-- schedule.  Keep the existing table and UUIDs so the RPC/tombstone contract
-- remains compatible while allowing any number of rows per owner.
alter table public.alarm_preferences
  add column if not exists schedule_name text,
  add column if not exists schedule_kind text,
  add column if not exists sleep_hour smallint,
  add column if not exists sleep_minute smallint,
  add column if not exists one_time_local_date date,
  add column if not exists bedtime_reminder_lead_minutes smallint,
  add column if not exists prewake_lead_minutes smallint,
  add column if not exists wake_audio_kind text,
  add column if not exists wake_audio_reference text,
  add column if not exists display_order integer;

-- Existing development rows predate the schedule fields.  There are no live
-- users, but this keeps a reset from failing if a local fixture is retained.
update public.alarm_preferences
set schedule_name = 'Sleep schedule'
where schedule_name is null;

update public.alarm_preferences
set schedule_kind = 'sleep'
where schedule_kind is null;

update public.alarm_preferences
set sleep_hour = local_hour
where sleep_hour is null;

update public.alarm_preferences
set sleep_minute = local_minute
where sleep_minute is null;

update public.alarm_preferences
set wake_audio_kind = 'bundled'
where wake_audio_kind is null;

update public.alarm_preferences
set wake_audio_reference = 'system-default'
where wake_audio_reference is null;

update public.alarm_preferences
set display_order = 0
where display_order is null;

alter table public.alarm_preferences
  alter column schedule_name set default 'Sleep schedule',
  alter column schedule_name set not null,
  alter column schedule_kind set default 'sleep',
  alter column schedule_kind set not null,
  alter column wake_audio_kind set default 'bundled',
  alter column wake_audio_kind set not null,
  alter column wake_audio_reference set default 'system-default',
  alter column wake_audio_reference set not null,
  alter column display_order set default 0,
  alter column display_order set not null;

alter table public.alarm_preferences
  drop constraint if exists alarm_preferences_schedule_name_check,
  drop constraint if exists alarm_preferences_schedule_kind_check,
  drop constraint if exists alarm_preferences_sleep_time_pair_check,
  drop constraint if exists alarm_preferences_schedule_shape_check,
  drop constraint if exists alarm_preferences_bedtime_reminder_kind_check,
  drop constraint if exists alarm_preferences_bedtime_reminder_range_check,
  drop constraint if exists alarm_preferences_prewake_range_check,
  drop constraint if exists alarm_preferences_wake_audio_kind_check,
  drop constraint if exists alarm_preferences_wake_audio_reference_check,
  drop constraint if exists alarm_preferences_display_order_check;

alter table public.alarm_preferences
  add constraint alarm_preferences_schedule_name_check
    check (char_length(btrim(schedule_name)) between 1 and 80),
  add constraint alarm_preferences_schedule_kind_check
    check (schedule_kind in ('sleep', 'wake_only')),
  add constraint alarm_preferences_sleep_time_pair_check
    check ((sleep_hour is null) = (sleep_minute is null)),
  add constraint alarm_preferences_schedule_shape_check
    check (
      (
        schedule_kind = 'sleep'
        and sleep_hour is not null
        and sleep_minute is not null
        and weekdays_mask > 0
        and one_time_local_date is null
      )
      or (
        schedule_kind = 'wake_only'
        and sleep_hour is null
        and sleep_minute is null
        and (
          (one_time_local_date is null and weekdays_mask > 0)
          or (one_time_local_date is not null and weekdays_mask = 0)
        )
      )
    ),
  add constraint alarm_preferences_bedtime_reminder_kind_check
    check (schedule_kind = 'sleep' or bedtime_reminder_lead_minutes is null),
  add constraint alarm_preferences_bedtime_reminder_range_check
    check (
      bedtime_reminder_lead_minutes is null
      or bedtime_reminder_lead_minutes in (0, 5, 10, 15, 30, 60)
    ),
  add constraint alarm_preferences_prewake_range_check
    check (prewake_lead_minutes is null or prewake_lead_minutes in (5, 10, 15, 30)),
  add constraint alarm_preferences_wake_audio_kind_check
    check (wake_audio_kind in ('bundled', 'catalog', 'personal')),
  add constraint alarm_preferences_wake_audio_reference_check
    check (char_length(btrim(wake_audio_reference)) between 1 and 255),
  add constraint alarm_preferences_display_order_check
    check (display_order between 0 and 100000);

create index if not exists alarm_preferences_owner_order_idx
  on public.alarm_preferences (owner_user_id, display_order, id);

-- The existing tombstone table already carries alarm identity, but make the
-- complete entity allow-list explicit after the persona migration history.
alter table public.deletion_tombstones
  drop constraint if exists deletion_tombstones_entity_type_check;

alter table public.deletion_tombstones
  add constraint deletion_tombstones_entity_type_check
    check (entity_type in ('profile', 'settings', 'alarm', 'checkin', 'persona'));

-- Replace only the private legacy implementation.  The public RPC and its
-- trusted wrapper retain their existing signatures and grants; the wrapper
-- delegates alarm/profile/settings/check-in/tombstone mutations here.
create or replace function private.apply_sync_mutation_legacy(
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
  v_schedule_name text;
  v_schedule_kind text;
  v_sleep_hour smallint;
  v_sleep_minute smallint;
  v_local_hour smallint;
  v_local_minute smallint;
  v_weekdays_mask smallint;
  v_one_time_local_date date;
  v_bedtime_reminder_lead_minutes smallint;
  v_prewake_lead_minutes smallint;
  v_wake_audio_kind text;
  v_wake_audio_reference text;
  v_display_order integer;
  v_snooze_minutes smallint;
  v_has_schedule_shape boolean;
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
        'id', 'owner_user_id', 'schedule_name', 'schedule_kind',
        'sleep_hour', 'sleep_minute', 'local_hour', 'local_minute',
        'weekdays_mask', 'one_time_local_date',
        'bedtime_reminder_lead_minutes', 'prewake_lead_minutes',
        'wake_audio_kind', 'wake_audio_reference', 'display_order',
        'snooze_minutes', 'enabled_intent', 'revision'
      ]::text[] <> '{}'::jsonb
        or not (p_payload ?& array[
          'id', 'owner_user_id', 'local_hour', 'local_minute',
          'weekdays_mask', 'enabled_intent', 'revision'
        ])
        or (p_payload ->> 'revision')::bigint is distinct from p_entity_revision then
        raise exception 'malformed alarm payload' using errcode = '22023';
      end if;

      v_has_schedule_shape := p_payload ? 'schedule_kind'
        or p_payload ? 'schedule_name'
        or p_payload ? 'wake_audio_kind'
        or p_payload ? 'wake_audio_reference';

      if v_has_schedule_shape and not (p_payload ?& array[
        'schedule_name', 'schedule_kind', 'local_hour', 'local_minute',
        'weekdays_mask', 'wake_audio_kind', 'wake_audio_reference',
        'display_order', 'enabled_intent', 'revision'
      ]) then
        raise exception 'malformed alarm payload' using errcode = '22023';
      end if;

      v_schedule_name := case
        when p_payload ? 'schedule_name' then p_payload ->> 'schedule_name'
        else 'Sleep schedule'
      end;
      v_schedule_kind := case
        when p_payload ? 'schedule_kind' then p_payload ->> 'schedule_kind'
        else 'sleep'
      end;
      v_local_hour := (p_payload ->> 'local_hour')::smallint;
      v_local_minute := (p_payload ->> 'local_minute')::smallint;
      v_weekdays_mask := (p_payload ->> 'weekdays_mask')::smallint;
      v_sleep_hour := case
        when p_payload ? 'sleep_hour' then (p_payload ->> 'sleep_hour')::smallint
        when v_has_schedule_shape then null
        else v_local_hour
      end;
      v_sleep_minute := case
        when p_payload ? 'sleep_minute' then (p_payload ->> 'sleep_minute')::smallint
        when v_has_schedule_shape then null
        else v_local_minute
      end;
      v_one_time_local_date := case
        when p_payload ? 'one_time_local_date'
          then (p_payload ->> 'one_time_local_date')::date
        else null
      end;
      v_bedtime_reminder_lead_minutes := case
        when p_payload ? 'bedtime_reminder_lead_minutes'
          then (p_payload ->> 'bedtime_reminder_lead_minutes')::smallint
        else null
      end;
      v_prewake_lead_minutes := case
        when p_payload ? 'prewake_lead_minutes'
          then (p_payload ->> 'prewake_lead_minutes')::smallint
        else null
      end;
      v_wake_audio_kind := case
        when p_payload ? 'wake_audio_kind' then p_payload ->> 'wake_audio_kind'
        else 'bundled'
      end;
      v_wake_audio_reference := case
        when p_payload ? 'wake_audio_reference' then p_payload ->> 'wake_audio_reference'
        else 'system-default'
      end;
      v_display_order := case
        when p_payload ? 'display_order' then (p_payload ->> 'display_order')::integer
        else 0
      end;
      v_snooze_minutes := case
        when p_payload ? 'snooze_minutes' then (p_payload ->> 'snooze_minutes')::smallint
        else null
      end;

      if v_schedule_name is null
        or char_length(btrim(v_schedule_name)) not between 1 and 80
        or v_schedule_kind is null
        or v_schedule_kind not in ('sleep', 'wake_only')
        or v_local_hour is null or v_local_hour not between 0 and 23
        or v_local_minute is null or v_local_minute not between 0 and 59
        or v_weekdays_mask is null or v_weekdays_mask not between 0 and 127
        or (v_sleep_hour is null) is distinct from (v_sleep_minute is null)
        or (v_sleep_hour is not null and v_sleep_hour not between 0 and 23)
        or (v_sleep_minute is not null and v_sleep_minute not between 0 and 59)
        or v_display_order is null or v_display_order not between 0 and 100000
        or v_wake_audio_kind is null
        or v_wake_audio_kind not in ('bundled', 'catalog', 'personal')
        or v_wake_audio_reference is null
        or char_length(btrim(v_wake_audio_reference)) not between 1 and 255
        or (v_bedtime_reminder_lead_minutes is not null
          and v_bedtime_reminder_lead_minutes not in (0, 5, 10, 15, 30, 60))
        or (v_prewake_lead_minutes is not null
          and v_prewake_lead_minutes not in (5, 10, 15, 30))
        or (v_snooze_minutes is not null and v_snooze_minutes not in (5, 10, 15))
        or (
          v_schedule_kind = 'sleep'
          and (
            v_sleep_hour is null
            or v_sleep_minute is null
            or v_weekdays_mask = 0
            or v_one_time_local_date is not null
          )
        )
        or (
          v_schedule_kind = 'wake_only'
          and (
            v_sleep_hour is not null
            or v_sleep_minute is not null
            or (v_one_time_local_date is null and v_weekdays_mask = 0)
            or (v_one_time_local_date is not null and v_weekdays_mask <> 0)
            or v_bedtime_reminder_lead_minutes is not null
          )
        ) then
        raise exception 'malformed alarm payload' using errcode = '22023';
      end if;

      if exists (
        select 1
        from public.deletion_tombstones
        where owner_user_id = v_owner_user_id
          and entity_type = 'alarm'
          and entity_id = p_entity_id
      ) then
        raise exception 'tombstoned alarm cannot be resurrected' using errcode = '23514';
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
        or p_payload ->> 'entity_type' not in ('checkin', 'alarm')
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
      select v_existing.id, v_existing.entity_revision,
        v_acknowledged_at, v_purge_after;
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
        if exists (select 1 from public.app_profiles where id = p_entity_id)
          or p_base_revision <> 0 then
          raise exception 'profile revision conflict' using errcode = '40001';
        end if;
        insert into public.app_profiles (
          id, owner_user_id, profile_created_at, revision
        ) values (
          p_entity_id, v_owner_user_id,
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
        if exists (select 1 from public.app_settings where id = p_entity_id)
          or p_base_revision <> 0 then
          raise exception 'settings revision conflict' using errcode = '40001';
        end if;
        insert into public.app_settings (
          id, owner_user_id, preferred_grounding_asset_id,
          preferred_modality, haptics_enabled, revision
        ) values (
          p_entity_id, v_owner_user_id,
          p_payload ->> 'preferred_grounding_asset_id',
          p_payload ->> 'preferred_modality',
          (p_payload ->> 'haptics_enabled')::boolean,
          p_entity_revision
        );
      end if;
    when 'alarm' then
      update public.alarm_preferences
      set schedule_name = v_schedule_name,
          schedule_kind = v_schedule_kind,
          sleep_hour = v_sleep_hour,
          sleep_minute = v_sleep_minute,
          local_hour = v_local_hour,
          local_minute = v_local_minute,
          weekdays_mask = v_weekdays_mask,
          one_time_local_date = v_one_time_local_date,
          bedtime_reminder_lead_minutes = v_bedtime_reminder_lead_minutes,
          prewake_lead_minutes = v_prewake_lead_minutes,
          wake_audio_kind = v_wake_audio_kind,
          wake_audio_reference = v_wake_audio_reference,
          display_order = v_display_order,
          snooze_minutes = v_snooze_minutes,
          enabled_intent = (p_payload ->> 'enabled_intent')::boolean,
          revision = p_entity_revision
      where id = p_entity_id
        and owner_user_id = v_owner_user_id
        and revision = p_base_revision;
      if not found then
        if exists (select 1 from public.alarm_preferences where id = p_entity_id)
          or p_base_revision <> 0 then
          raise exception 'alarm revision conflict' using errcode = '40001';
        end if;
        if (
          select count(*)
          from public.alarm_preferences
          where owner_user_id = v_owner_user_id
        ) >= 8 then
          raise exception 'maximum alarm schedules reached' using errcode = '23514';
        end if;
        insert into public.alarm_preferences (
          id, owner_user_id, schedule_name, schedule_kind,
          sleep_hour, sleep_minute, local_hour, local_minute,
          weekdays_mask, one_time_local_date,
          bedtime_reminder_lead_minutes, prewake_lead_minutes,
          wake_audio_kind, wake_audio_reference, display_order,
          snooze_minutes, enabled_intent, revision
        ) values (
          p_entity_id, v_owner_user_id, v_schedule_name, v_schedule_kind,
          v_sleep_hour, v_sleep_minute, v_local_hour, v_local_minute,
          v_weekdays_mask, v_one_time_local_date,
          v_bedtime_reminder_lead_minutes, v_prewake_lead_minutes,
          v_wake_audio_kind, v_wake_audio_reference, v_display_order,
          v_snooze_minutes, (p_payload ->> 'enabled_intent')::boolean,
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
        if exists (select 1 from public.submitted_checkins where id = p_entity_id)
          or p_base_revision <> 0 then
          raise exception 'check-in revision conflict' using errcode = '40001';
        end if;
        insert into public.submitted_checkins (
          id, owner_user_id, reported_for_local_date, reported_timezone_id,
          occurrence, perceived_intensity, present_state, note,
          created_at, updated_at, revision, deleted_at
        ) values (
          p_entity_id, v_owner_user_id,
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
      v_deleted_entity_id := (p_payload ->> 'entity_id')::uuid;

      if p_payload ->> 'entity_type' = 'checkin' then
        select revision, deleted_at
        into v_current_revision, v_current_deleted_at
        from public.submitted_checkins
        where owner_user_id = v_owner_user_id
          and id = v_deleted_entity_id
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
            and id = v_deleted_entity_id;
        elsif found and v_current_revision <> p_entity_revision then
          raise exception 'delete revision conflict' using errcode = '40001';
        elsif not found and p_base_revision <> 0 then
          raise exception 'delete revision conflict' using errcode = '40001';
        end if;
      else
        select revision
        into v_current_revision
        from public.alarm_preferences
        where owner_user_id = v_owner_user_id
          and id = v_deleted_entity_id
        for update;

        if found then
          if v_current_revision <> p_base_revision then
            raise exception 'delete revision conflict' using errcode = '40001';
          end if;
          delete from public.alarm_preferences
          where owner_user_id = v_owner_user_id
            and id = v_deleted_entity_id;
        elsif p_base_revision <> 0 then
          raise exception 'delete revision conflict' using errcode = '40001';
        end if;
      end if;

      v_acknowledged_at := statement_timestamp();
      v_purge_after := v_acknowledged_at + interval '30 days';
      insert into public.deletion_tombstones (
        id, owner_user_id, entity_type, entity_id, deleted_revision,
        deleted_at, acknowledged_at, purge_after
      ) values (
        p_entity_id, v_owner_user_id, p_payload ->> 'entity_type',
        v_deleted_entity_id, (p_payload ->> 'deleted_revision')::bigint,
        (p_payload ->> 'deleted_at')::timestamptz,
        v_acknowledged_at, v_purge_after
      );
    else
      raise exception 'unsupported entity type' using errcode = '22023';
  end case;

  return query
    select p_receipt_id, p_entity_revision,
      v_acknowledged_at, v_purge_after;
end;
$$;

revoke all on table public.alarm_preferences from anon, authenticated;
grant select on table public.alarm_preferences to authenticated;

revoke all on function private.apply_sync_mutation_legacy(
  uuid, uuid, text, uuid, text, bigint, bigint, jsonb
) from public, anon;
grant usage on schema private to authenticated;
grant execute on function private.apply_sync_mutation_legacy(
  uuid, uuid, text, uuid, text, bigint, bigint, jsonb
) to authenticated;

commit;
