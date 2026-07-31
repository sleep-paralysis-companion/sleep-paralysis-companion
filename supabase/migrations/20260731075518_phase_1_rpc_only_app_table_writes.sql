begin;

revoke insert, update, delete on table
  public.app_profiles,
  public.app_settings,
  public.alarm_preferences,
  public.submitted_checkins,
  public.deletion_tombstones,
  public.mutation_receipts,
  public.persona_answer_aggregates,
  public.account_deletion_audit
from authenticated;

revoke insert (id, owner_user_id, profile_created_at, revision),
  update (profile_created_at, revision)
on public.app_profiles from authenticated;

revoke insert (
  id, owner_user_id, preferred_grounding_asset_id, preferred_modality,
  haptics_enabled, revision
), update (
  preferred_grounding_asset_id, preferred_modality, haptics_enabled, revision
) on public.app_settings from authenticated;

revoke insert (
  id, owner_user_id, local_hour, local_minute, weekdays_mask,
  snooze_minutes, enabled_intent, revision
), update (
  local_hour, local_minute, weekdays_mask, snooze_minutes,
  enabled_intent, revision
) on public.alarm_preferences from authenticated;

revoke insert (
  id, owner_user_id, reported_for_local_date, reported_timezone_id,
  occurrence, perceived_intensity, present_state, note, created_at,
  updated_at, revision, deleted_at
), update (
  reported_for_local_date, reported_timezone_id, occurrence,
  perceived_intensity, present_state, note, updated_at, revision, deleted_at
) on public.submitted_checkins from authenticated;

revoke insert (
  id, owner_user_id, entity_type, entity_id, deleted_revision,
  deleted_at, acknowledged_at, purge_after
), update (acknowledged_at, purge_after)
on public.deletion_tombstones from authenticated;

revoke insert (
  id, owner_user_id, idempotency_key, entity_type, entity_id,
  operation, entity_revision, expires_at, base_revision, payload_hash
) on public.mutation_receipts from authenticated;

revoke insert (
  id, owner_user_id, episode_frequency, post_episode_feeling,
  calming_person_context, routing_rule_version, calculated_at,
  updated_at, revision
), update (
  episode_frequency, post_episode_feeling, calming_person_context,
  routing_rule_version, calculated_at, updated_at, revision
) on public.persona_answer_aggregates from authenticated;

grant select on table
  public.app_profiles,
  public.app_settings,
  public.alarm_preferences,
  public.submitted_checkins,
  public.deletion_tombstones,
  public.mutation_receipts,
  public.persona_answer_aggregates
to authenticated;

revoke all on table public.account_deletion_audit from authenticated;

do $$
declare
  app_table text;
begin
  foreach app_table in array array[
    'app_profiles',
    'app_settings',
    'alarm_preferences',
    'submitted_checkins',
    'deletion_tombstones',
    'mutation_receipts',
    'persona_answer_aggregates',
    'account_deletion_audit'
  ]
  loop
    if has_table_privilege('authenticated', format('public.%I', app_table), 'INSERT')
      or has_table_privilege('authenticated', format('public.%I', app_table), 'UPDATE')
      or has_table_privilege('authenticated', format('public.%I', app_table), 'DELETE')
      or exists (
        select 1
        from information_schema.column_privileges
        where grantee = 'authenticated'
          and table_schema = 'public'
          and table_name = app_table
          and privilege_type in ('INSERT', 'UPDATE')
      )
    then
      raise exception 'authenticated direct DML remains on public.%', app_table;
    end if;
  end loop;
end
$$;

commit;
