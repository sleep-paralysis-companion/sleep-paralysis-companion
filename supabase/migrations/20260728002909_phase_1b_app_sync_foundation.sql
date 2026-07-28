begin;

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

alter default privileges for role postgres in schema public
  revoke select, insert, update, delete on tables from anon, authenticated, service_role;
alter default privileges for role postgres in schema public
  revoke usage, select on sequences from anon, authenticated, service_role;
alter default privileges for role postgres in schema public
  revoke execute on functions from public, anon, authenticated;

create table public.app_profiles (
  id uuid primary key,
  owner_user_id uuid not null unique references auth.users(id) on delete cascade,
  profile_created_at timestamptz not null,
  revision bigint not null check (revision > 0),
  server_updated_at timestamptz not null default statement_timestamp(),
  constraint app_profiles_id_owner_unique unique (id, owner_user_id)
);

create table public.app_settings (
  id uuid primary key,
  owner_user_id uuid not null unique references auth.users(id) on delete cascade,
  preferred_grounding_asset_id text,
  preferred_modality text not null
    check (preferred_modality in ('audio', 'visual', 'silent')),
  haptics_enabled boolean not null,
  revision bigint not null check (revision > 0),
  server_updated_at timestamptz not null default statement_timestamp(),
  constraint app_settings_asset_id_length
    check (preferred_grounding_asset_id is null or char_length(preferred_grounding_asset_id) between 1 and 128)
);

create table public.alarm_preferences (
  id uuid primary key,
  owner_user_id uuid not null references auth.users(id) on delete cascade,
  local_hour smallint not null check (local_hour between 0 and 23),
  local_minute smallint not null check (local_minute between 0 and 59),
  weekdays_mask smallint not null check (weekdays_mask between 0 and 127),
  snooze_minutes smallint check (snooze_minutes in (5, 10, 15)),
  enabled_intent boolean not null,
  revision bigint not null check (revision > 0),
  server_updated_at timestamptz not null default statement_timestamp(),
  constraint alarm_preferences_owner_id_unique unique (owner_user_id, id)
);

create table public.submitted_checkins (
  id uuid primary key,
  owner_user_id uuid not null references auth.users(id) on delete cascade,
  reported_for_local_date date not null,
  reported_timezone_id text not null,
  occurrence text not null check (occurrence in ('yes', 'no')),
  perceived_intensity text
    check (perceived_intensity in ('mild', 'moderate', 'severe', 'extreme')),
  present_state text
    check (present_state in ('fine_now', 'still_shaken', 'exhausted')),
  note text,
  created_at timestamptz not null,
  updated_at timestamptz not null,
  revision bigint not null check (revision > 0),
  deleted_at timestamptz,
  server_updated_at timestamptz not null default statement_timestamp(),
  constraint submitted_checkins_owner_date_unique
    unique (owner_user_id, reported_for_local_date),
  constraint submitted_checkins_owner_id_unique unique (owner_user_id, id),
  constraint submitted_checkins_timezone_length
    check (char_length(reported_timezone_id) between 1 and 128),
  constraint submitted_checkins_intensity_requires_occurrence
    check (occurrence = 'yes' or perceived_intensity is null),
  constraint submitted_checkins_note_length
    check (note is null or char_length(note) between 1 and 500),
  constraint submitted_checkins_timestamp_order
    check (updated_at >= created_at)
);

create table public.deletion_tombstones (
  id uuid primary key,
  owner_user_id uuid not null references auth.users(id) on delete cascade,
  entity_type text not null
    check (entity_type in ('profile', 'settings', 'alarm', 'checkin')),
  entity_id uuid not null,
  deleted_revision bigint not null check (deleted_revision > 0),
  deleted_at timestamptz not null,
  acknowledged_at timestamptz,
  purge_after timestamptz not null,
  server_updated_at timestamptz not null default statement_timestamp(),
  constraint deletion_tombstones_semantic_unique
    unique (owner_user_id, entity_type, entity_id),
  constraint deletion_tombstones_ack_order
    check (acknowledged_at is null or acknowledged_at >= deleted_at),
  constraint deletion_tombstones_purge_order
    check (purge_after >= coalesce(acknowledged_at, deleted_at))
);

create table public.mutation_receipts (
  id uuid primary key,
  owner_user_id uuid not null references auth.users(id) on delete cascade,
  idempotency_key uuid not null,
  entity_type text not null
    check (entity_type in ('profile', 'settings', 'alarm', 'checkin', 'tombstone')),
  entity_id uuid not null,
  operation text not null check (operation in ('upsert', 'delete', 'convert')),
  entity_revision bigint not null check (entity_revision > 0),
  received_at timestamptz not null default statement_timestamp(),
  expires_at timestamptz not null,
  constraint mutation_receipts_idempotency_unique unique (owner_user_id, idempotency_key),
  constraint mutation_receipts_semantic_unique
    unique (owner_user_id, entity_type, entity_id, operation, entity_revision),
  constraint mutation_receipts_expiry_order check (expires_at > received_at)
);

create table public.account_deletion_audit (
  request_id uuid primary key,
  completed_at timestamptz not null,
  outcome text not null check (outcome in ('completed', 'failed_recoverable')),
  purge_after timestamptz not null,
  constraint account_deletion_audit_purge_order check (purge_after > completed_at)
);
alter table public.account_deletion_audit enable row level security;
alter table public.account_deletion_audit force row level security;

create index app_profiles_owner_idx on public.app_profiles (owner_user_id);
create index app_settings_owner_idx on public.app_settings (owner_user_id);
create index alarm_preferences_owner_idx on public.alarm_preferences (owner_user_id);
create index submitted_checkins_owner_active_date_idx
  on public.submitted_checkins (owner_user_id, reported_for_local_date desc)
  where deleted_at is null;
create index deletion_tombstones_owner_ack_idx
  on public.deletion_tombstones (owner_user_id, acknowledged_at, purge_after);
create index mutation_receipts_owner_expiry_idx
  on public.mutation_receipts (owner_user_id, expires_at);

create function private.enforce_owned_revision()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    if new.revision <> 1 then
      raise exception 'initial revision must be 1' using errcode = '23514';
    end if;
  else
    if new.owner_user_id <> old.owner_user_id then
      raise exception 'owner is immutable' using errcode = '42501';
    end if;
    if new.revision <> old.revision + 1 then
      raise exception 'revision must advance by one' using errcode = '23514';
    end if;
  end if;
  new.server_updated_at := statement_timestamp();
  return new;
end;
$$;

create function private.enforce_immutable_owner()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if tg_op = 'UPDATE' and new.owner_user_id <> old.owner_user_id then
    raise exception 'owner is immutable' using errcode = '42501';
  end if;
  new.server_updated_at := statement_timestamp();
  return new;
end;
$$;

create function private.prevent_checkin_resurrection()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if old.deleted_at is not null and new.deleted_at is null then
    raise exception 'deleted check-in cannot be resurrected' using errcode = '23514';
  end if;
  return new;
end;
$$;

create trigger app_profiles_revision_guard
before insert or update on public.app_profiles
for each row execute function private.enforce_owned_revision();
create trigger app_settings_revision_guard
before insert or update on public.app_settings
for each row execute function private.enforce_owned_revision();
create trigger alarm_preferences_revision_guard
before insert or update on public.alarm_preferences
for each row execute function private.enforce_owned_revision();
create trigger submitted_checkins_revision_guard
before insert or update on public.submitted_checkins
for each row execute function private.enforce_owned_revision();
create trigger submitted_checkins_no_resurrection
before update on public.submitted_checkins
for each row execute function private.prevent_checkin_resurrection();
create trigger deletion_tombstones_owner_guard
before update on public.deletion_tombstones
for each row execute function private.enforce_immutable_owner();

revoke all on function private.enforce_owned_revision() from public, anon, authenticated;
revoke all on function private.enforce_immutable_owner() from public, anon, authenticated;
revoke all on function private.prevent_checkin_resurrection() from public, anon, authenticated;

alter table public.app_profiles enable row level security;
alter table public.app_profiles force row level security;
alter table public.app_settings enable row level security;
alter table public.app_settings force row level security;
alter table public.alarm_preferences enable row level security;
alter table public.alarm_preferences force row level security;
alter table public.submitted_checkins enable row level security;
alter table public.submitted_checkins force row level security;
alter table public.deletion_tombstones enable row level security;
alter table public.deletion_tombstones force row level security;
alter table public.mutation_receipts enable row level security;
alter table public.mutation_receipts force row level security;

create policy app_profiles_owner_select on public.app_profiles
for select to authenticated
using ((select auth.uid()) = owner_user_id);
create policy app_profiles_owner_insert on public.app_profiles
for insert to authenticated
with check ((select auth.uid()) = owner_user_id);
create policy app_profiles_owner_update on public.app_profiles
for update to authenticated
using ((select auth.uid()) = owner_user_id)
with check ((select auth.uid()) = owner_user_id);
create policy app_profiles_owner_delete on public.app_profiles
for delete to authenticated
using ((select auth.uid()) = owner_user_id);

create policy app_settings_owner_select on public.app_settings
for select to authenticated
using ((select auth.uid()) = owner_user_id);
create policy app_settings_owner_insert on public.app_settings
for insert to authenticated
with check ((select auth.uid()) = owner_user_id);
create policy app_settings_owner_update on public.app_settings
for update to authenticated
using ((select auth.uid()) = owner_user_id)
with check ((select auth.uid()) = owner_user_id);
create policy app_settings_owner_delete on public.app_settings
for delete to authenticated
using ((select auth.uid()) = owner_user_id);

create policy alarm_preferences_owner_select on public.alarm_preferences
for select to authenticated
using ((select auth.uid()) = owner_user_id);
create policy alarm_preferences_owner_insert on public.alarm_preferences
for insert to authenticated
with check ((select auth.uid()) = owner_user_id);
create policy alarm_preferences_owner_update on public.alarm_preferences
for update to authenticated
using ((select auth.uid()) = owner_user_id)
with check ((select auth.uid()) = owner_user_id);
create policy alarm_preferences_owner_delete on public.alarm_preferences
for delete to authenticated
using ((select auth.uid()) = owner_user_id);

create policy submitted_checkins_owner_select on public.submitted_checkins
for select to authenticated
using ((select auth.uid()) = owner_user_id);
create policy submitted_checkins_owner_insert on public.submitted_checkins
for insert to authenticated
with check ((select auth.uid()) = owner_user_id);
create policy submitted_checkins_owner_update on public.submitted_checkins
for update to authenticated
using ((select auth.uid()) = owner_user_id)
with check ((select auth.uid()) = owner_user_id);
create policy submitted_checkins_owner_delete on public.submitted_checkins
for delete to authenticated
using ((select auth.uid()) = owner_user_id);

create policy deletion_tombstones_owner_select on public.deletion_tombstones
for select to authenticated
using ((select auth.uid()) = owner_user_id);
create policy deletion_tombstones_owner_insert on public.deletion_tombstones
for insert to authenticated
with check ((select auth.uid()) = owner_user_id);
create policy deletion_tombstones_owner_update on public.deletion_tombstones
for update to authenticated
using ((select auth.uid()) = owner_user_id)
with check ((select auth.uid()) = owner_user_id);
create policy deletion_tombstones_owner_delete on public.deletion_tombstones
for delete to authenticated
using ((select auth.uid()) = owner_user_id);

create policy mutation_receipts_owner_select on public.mutation_receipts
for select to authenticated
using ((select auth.uid()) = owner_user_id);
create policy mutation_receipts_owner_insert on public.mutation_receipts
for insert to authenticated
with check ((select auth.uid()) = owner_user_id);
create policy mutation_receipts_owner_delete on public.mutation_receipts
for delete to authenticated
using ((select auth.uid()) = owner_user_id);

create function public.apply_sync_mutation(
  p_receipt_id uuid,
  p_idempotency_key uuid,
  p_entity_type text,
  p_entity_id uuid,
  p_operation text,
  p_entity_revision bigint,
  p_payload jsonb
)
returns table (server_mutation_id uuid, accepted_revision bigint)
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_owner_user_id uuid := auth.uid();
  v_existing public.mutation_receipts%rowtype;
begin
  if v_owner_user_id is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;
  if (p_payload ->> 'id')::uuid <> p_entity_id
    or (p_payload ->> 'owner_user_id')::uuid <> v_owner_user_id then
    raise exception 'payload ownership mismatch' using errcode = '42501';
  end if;
  if p_entity_type <> 'tombstone'
    and (p_payload ->> 'revision')::bigint <> p_entity_revision then
    raise exception 'payload revision mismatch' using errcode = '23514';
  end if;

  select * into v_existing
  from public.mutation_receipts
  where owner_user_id = v_owner_user_id
    and idempotency_key = p_idempotency_key;

  if found then
    if v_existing.entity_type <> p_entity_type
      or v_existing.entity_id <> p_entity_id
      or v_existing.operation <> p_operation
      or v_existing.entity_revision <> p_entity_revision then
      raise exception 'idempotency key payload mismatch' using errcode = '23505';
    end if;
    return query select v_existing.id, v_existing.entity_revision;
    return;
  end if;

  insert into public.mutation_receipts (
    id, owner_user_id, idempotency_key, entity_type, entity_id,
    operation, entity_revision, expires_at
  ) values (
    p_receipt_id, v_owner_user_id, p_idempotency_key, p_entity_type, p_entity_id,
    p_operation, p_entity_revision, statement_timestamp() + interval '30 days'
  );

  case p_entity_type
    when 'profile' then
      if p_payload - array[
        'id', 'owner_user_id', 'profile_created_at', 'revision'
      ]::text[] <> '{}'::jsonb then
        raise exception 'unsupported profile field' using errcode = '42501';
      end if;
      update public.app_profiles set
        profile_created_at = (p_payload ->> 'profile_created_at')::timestamptz,
        revision = p_entity_revision
      where id = p_entity_id;
      if not found then
        insert into public.app_profiles (
          id, owner_user_id, profile_created_at, revision
        ) values (
          p_entity_id, v_owner_user_id,
          (p_payload ->> 'profile_created_at')::timestamptz, p_entity_revision
        );
      end if;
    when 'settings' then
      if p_payload - array[
        'id', 'owner_user_id', 'preferred_grounding_asset_id',
        'preferred_modality', 'haptics_enabled', 'revision'
      ]::text[] <> '{}'::jsonb then
        raise exception 'unsupported settings field' using errcode = '42501';
      end if;
      update public.app_settings set
        preferred_grounding_asset_id = p_payload ->> 'preferred_grounding_asset_id',
        preferred_modality = p_payload ->> 'preferred_modality',
        haptics_enabled = (p_payload ->> 'haptics_enabled')::boolean,
        revision = p_entity_revision
      where id = p_entity_id;
      if not found then
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
      if p_payload - array[
        'id', 'owner_user_id', 'local_hour', 'local_minute',
        'weekdays_mask', 'snooze_minutes', 'enabled_intent', 'revision'
      ]::text[] <> '{}'::jsonb then
        raise exception 'unsupported alarm field' using errcode = '42501';
      end if;
      update public.alarm_preferences set
        local_hour = (p_payload ->> 'local_hour')::smallint,
        local_minute = (p_payload ->> 'local_minute')::smallint,
        weekdays_mask = (p_payload ->> 'weekdays_mask')::smallint,
        snooze_minutes = (p_payload ->> 'snooze_minutes')::smallint,
        enabled_intent = (p_payload ->> 'enabled_intent')::boolean,
        revision = p_entity_revision
      where id = p_entity_id;
      if not found then
        insert into public.alarm_preferences (
          id, owner_user_id, local_hour, local_minute, weekdays_mask,
          snooze_minutes, enabled_intent, revision
        ) values (
          p_entity_id, v_owner_user_id,
          (p_payload ->> 'local_hour')::smallint,
          (p_payload ->> 'local_minute')::smallint,
          (p_payload ->> 'weekdays_mask')::smallint,
          (p_payload ->> 'snooze_minutes')::smallint,
          (p_payload ->> 'enabled_intent')::boolean,
          p_entity_revision
        );
      end if;
    when 'checkin' then
      if p_payload - array[
        'id', 'owner_user_id', 'reported_for_local_date', 'reported_timezone_id', 'occurrence',
        'perceived_intensity', 'present_state', 'note', 'created_at',
        'updated_at', 'revision', 'deleted_at'
      ]::text[] <> '{}'::jsonb then
        raise exception 'unsupported check-in field' using errcode = '42501';
      end if;
      update public.submitted_checkins set
        reported_for_local_date = (p_payload ->> 'reported_for_local_date')::date,
        reported_timezone_id = p_payload ->> 'reported_timezone_id',
        occurrence = p_payload ->> 'occurrence',
        perceived_intensity = p_payload ->> 'perceived_intensity',
        present_state = p_payload ->> 'present_state',
        note = p_payload ->> 'note',
        updated_at = (p_payload ->> 'updated_at')::timestamptz,
        revision = p_entity_revision,
        deleted_at = (p_payload ->> 'deleted_at')::timestamptz
      where id = p_entity_id;
      if not found then
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
          (p_payload ->> 'deleted_at')::timestamptz
        );
      end if;
    when 'tombstone' then
      if p_payload - array[
        'id', 'owner_user_id', 'entity_type', 'entity_id', 'deleted_revision',
        'deleted_at', 'acknowledged_at', 'purge_after'
      ]::text[] <> '{}'::jsonb then
        raise exception 'unsupported tombstone field' using errcode = '42501';
      end if;
      update public.deletion_tombstones set
        acknowledged_at = (p_payload ->> 'acknowledged_at')::timestamptz,
        purge_after = (p_payload ->> 'purge_after')::timestamptz
      where id = p_entity_id;
      if not found then
        insert into public.deletion_tombstones (
          id, owner_user_id, entity_type, entity_id, deleted_revision,
          deleted_at, acknowledged_at, purge_after
        ) values (
          p_entity_id, v_owner_user_id,
          p_payload ->> 'entity_type',
          (p_payload ->> 'entity_id')::uuid,
          (p_payload ->> 'deleted_revision')::bigint,
          (p_payload ->> 'deleted_at')::timestamptz,
          (p_payload ->> 'acknowledged_at')::timestamptz,
          (p_payload ->> 'purge_after')::timestamptz
        );
      end if;
    else
      raise exception 'unsupported entity type' using errcode = '22023';
  end case;

  return query select p_receipt_id, p_entity_revision;
end;
$$;

revoke all on function public.apply_sync_mutation(
  uuid, uuid, text, uuid, text, bigint, jsonb
) from public, anon;
grant execute on function public.apply_sync_mutation(
  uuid, uuid, text, uuid, text, bigint, jsonb
) to authenticated;

revoke all on table
  public.app_profiles,
  public.app_settings,
  public.alarm_preferences,
  public.submitted_checkins,
  public.deletion_tombstones,
  public.mutation_receipts
from anon, authenticated;

grant select, delete on table public.app_profiles to authenticated;
grant insert (id, owner_user_id, profile_created_at, revision)
  on public.app_profiles to authenticated;
grant update (profile_created_at, revision)
  on public.app_profiles to authenticated;

grant select, delete on table public.app_settings to authenticated;
grant insert (
  id,
  owner_user_id,
  preferred_grounding_asset_id,
  preferred_modality,
  haptics_enabled,
  revision
) on public.app_settings to authenticated;
grant update (
  preferred_grounding_asset_id,
  preferred_modality,
  haptics_enabled,
  revision
) on public.app_settings to authenticated;

grant select, delete on table public.alarm_preferences to authenticated;
grant insert (
  id,
  owner_user_id,
  local_hour,
  local_minute,
  weekdays_mask,
  snooze_minutes,
  enabled_intent,
  revision
) on public.alarm_preferences to authenticated;
grant update (
  local_hour,
  local_minute,
  weekdays_mask,
  snooze_minutes,
  enabled_intent,
  revision
) on public.alarm_preferences to authenticated;

grant select, delete on table public.submitted_checkins to authenticated;
grant insert (
  id,
  owner_user_id,
  reported_for_local_date,
  reported_timezone_id,
  occurrence,
  perceived_intensity,
  present_state,
  note,
  created_at,
  updated_at,
  revision,
  deleted_at
) on public.submitted_checkins to authenticated;
grant update (
  reported_for_local_date,
  reported_timezone_id,
  occurrence,
  perceived_intensity,
  present_state,
  note,
  updated_at,
  revision,
  deleted_at
) on public.submitted_checkins to authenticated;

grant select, delete on table public.deletion_tombstones to authenticated;
grant insert (
  id,
  owner_user_id,
  entity_type,
  entity_id,
  deleted_revision,
  deleted_at,
  acknowledged_at,
  purge_after
) on public.deletion_tombstones to authenticated;
grant update (acknowledged_at, purge_after)
  on public.deletion_tombstones to authenticated;

grant select, delete on table public.mutation_receipts to authenticated;
grant insert (
  id,
  owner_user_id,
  idempotency_key,
  entity_type,
  entity_id,
  operation,
  entity_revision,
  expires_at
) on public.mutation_receipts to authenticated;

revoke all on table public.account_deletion_audit from public, anon, authenticated;
grant select, insert, update, delete on table public.account_deletion_audit to service_role;

commit;
