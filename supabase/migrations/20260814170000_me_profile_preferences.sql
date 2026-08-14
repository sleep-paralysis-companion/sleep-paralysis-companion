begin;

alter table public.app_profiles add column display_name text
  check (display_name is null or char_length(btrim(display_name)) between 1 and 80);
alter table public.app_settings add column default_sleep_support text not null default 'quickSleep'
  check (default_sleep_support in ('quickSleep', 'longSleepAid'));
alter table public.app_settings add column default_post_episode_support text not null default 'calmingAudio'
  check (default_post_episode_support in ('callPartner', 'calmingAudio', 'partnerVoice'));

create function private.apply_me_profile_settings_mutation(
  p_receipt_id uuid, p_idempotency_key uuid, p_entity_type text, p_entity_id uuid,
  p_operation text, p_base_revision bigint, p_entity_revision bigint, p_payload jsonb
)
returns table (server_mutation_id uuid, accepted_revision bigint, acknowledged_at timestamptz, purge_after timestamptz)
language plpgsql security definer set search_path = '' as $$
declare
  v_owner uuid := auth.uid();
  v_existing public.mutation_receipts%rowtype;
  v_hash text;
begin
  if v_owner is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;
  if p_operation <> 'upsert' or p_entity_type not in ('profile', 'settings')
    or p_entity_revision <> p_base_revision + 1 or p_payload is null then
    raise exception 'invalid mutation envelope' using errcode = '22023';
  end if;
  if (p_payload ->> 'id')::uuid is distinct from p_entity_id
    or (p_payload ->> 'owner_user_id')::uuid is distinct from v_owner then
    raise exception 'payload ownership or identity mismatch' using errcode = '42501';
  end if;
  v_hash := encode(extensions.digest(convert_to(p_payload::text, 'UTF8'), 'sha256'), 'hex');
  select * into v_existing from public.mutation_receipts
  where owner_user_id = v_owner and idempotency_key = p_idempotency_key;
  if found then
    if v_existing.entity_type <> p_entity_type or v_existing.entity_id <> p_entity_id
      or v_existing.operation <> p_operation or v_existing.base_revision <> p_base_revision
      or v_existing.entity_revision <> p_entity_revision or v_existing.payload_hash <> v_hash then
      raise exception 'idempotency key payload mismatch' using errcode = '23505';
    end if;
    return query select v_existing.id, v_existing.entity_revision, null::timestamptz, null::timestamptz;
    return;
  end if;
  if p_entity_type = 'profile' then
    if p_payload - array['id','owner_user_id','profile_created_at','display_name','revision']::text[] <> '{}'::jsonb
      or not (p_payload ?& array['id','owner_user_id','profile_created_at','revision'])
      or (p_payload ->> 'revision')::bigint is distinct from p_entity_revision
      or (p_payload ->> 'profile_created_at')::timestamptz is null
      or (p_payload ? 'display_name' and p_payload ->> 'display_name' is not null
        and char_length(btrim(p_payload ->> 'display_name')) not between 1 and 80) then
      raise exception 'malformed profile payload' using errcode = '22023';
    end if;
    update public.app_profiles set profile_created_at = (p_payload ->> 'profile_created_at')::timestamptz,
      display_name = nullif(btrim(p_payload ->> 'display_name'), ''), revision = p_entity_revision
    where id = p_entity_id and owner_user_id = v_owner and revision = p_base_revision;
    if not found then
      if exists (select 1 from public.app_profiles where id = p_entity_id) or p_base_revision <> 0 then
        raise exception 'profile revision conflict' using errcode = '40001';
      end if;
      insert into public.app_profiles (id, owner_user_id, profile_created_at, display_name, revision)
      values (p_entity_id, v_owner, (p_payload ->> 'profile_created_at')::timestamptz,
        nullif(btrim(p_payload ->> 'display_name'), ''), p_entity_revision);
    end if;
  else
    if p_payload - array['id','owner_user_id','preferred_grounding_asset_id','preferred_modality','haptics_enabled','default_sleep_support','default_post_episode_support','revision']::text[] <> '{}'::jsonb
      or not (p_payload ?& array['id','owner_user_id','preferred_grounding_asset_id','preferred_modality','haptics_enabled','revision'])
      or (p_payload ->> 'preferred_modality') not in ('audio','visual','silent')
      or (p_payload ? 'default_sleep_support'
        and (p_payload ->> 'default_sleep_support') not in ('quickSleep','longSleepAid'))
      or (p_payload ? 'default_post_episode_support'
        and (p_payload ->> 'default_post_episode_support') not in ('callPartner','calmingAudio','partnerVoice'))
      or (p_payload ->> 'revision')::bigint is distinct from p_entity_revision then
      raise exception 'malformed settings payload' using errcode = '22023';
    end if;
    update public.app_settings set preferred_grounding_asset_id = p_payload ->> 'preferred_grounding_asset_id',
      preferred_modality = p_payload ->> 'preferred_modality', haptics_enabled = (p_payload ->> 'haptics_enabled')::boolean,
      default_sleep_support = coalesce(p_payload ->> 'default_sleep_support', default_sleep_support),
      default_post_episode_support = coalesce(p_payload ->> 'default_post_episode_support', default_post_episode_support),
      revision = p_entity_revision
    where id = p_entity_id and owner_user_id = v_owner and revision = p_base_revision;
    if not found then
      if exists (select 1 from public.app_settings where id = p_entity_id) or p_base_revision <> 0 then raise exception 'settings revision conflict' using errcode = '40001'; end if;
      insert into public.app_settings (id, owner_user_id, preferred_grounding_asset_id, preferred_modality, haptics_enabled, default_sleep_support, default_post_episode_support, revision)
      values (p_entity_id, v_owner, p_payload ->> 'preferred_grounding_asset_id', p_payload ->> 'preferred_modality',
        (p_payload ->> 'haptics_enabled')::boolean, coalesce(p_payload ->> 'default_sleep_support', 'quickSleep'),
        coalesce(p_payload ->> 'default_post_episode_support', 'calmingAudio'), p_entity_revision);
    end if;
  end if;
  insert into public.mutation_receipts (id, owner_user_id, idempotency_key, entity_type, entity_id, operation, base_revision, entity_revision, payload_hash, expires_at)
  values (p_receipt_id, v_owner, p_idempotency_key, p_entity_type, p_entity_id, p_operation, p_base_revision, p_entity_revision, v_hash, statement_timestamp() + interval '30 days');
  return query select p_receipt_id, p_entity_revision, null::timestamptz, null::timestamptz;
end;
$$;

create or replace function public.apply_sync_mutation(
  p_receipt_id uuid, p_idempotency_key uuid, p_entity_type text, p_entity_id uuid,
  p_operation text, p_base_revision bigint, p_entity_revision bigint, p_payload jsonb
)
returns table (server_mutation_id uuid, accepted_revision bigint, acknowledged_at timestamptz, purge_after timestamptz)
language sql security invoker set search_path = '' as $$
  select * from private.apply_me_profile_settings_mutation(p_receipt_id, p_idempotency_key, p_entity_type, p_entity_id, p_operation, p_base_revision, p_entity_revision, p_payload)
  where p_entity_type in ('profile', 'settings') and p_operation = 'upsert'
  union all
  select * from private.apply_sync_mutation_trusted(p_receipt_id, p_idempotency_key, p_entity_type, p_entity_id, p_operation, p_base_revision, p_entity_revision, p_payload)
  where p_entity_type not in ('profile', 'settings') or p_operation <> 'upsert';
$$;

revoke all on function private.apply_me_profile_settings_mutation(uuid, uuid, text, uuid, text, bigint, bigint, jsonb) from public, anon;
grant usage on schema private to authenticated;
grant execute on function private.apply_me_profile_settings_mutation(uuid, uuid, text, uuid, text, bigint, bigint, jsonb) to authenticated;
revoke all on function public.apply_sync_mutation(uuid, uuid, text, uuid, text, bigint, bigint, jsonb) from public, anon;
grant execute on function public.apply_sync_mutation(uuid, uuid, text, uuid, text, bigint, bigint, jsonb) to authenticated;

commit;
