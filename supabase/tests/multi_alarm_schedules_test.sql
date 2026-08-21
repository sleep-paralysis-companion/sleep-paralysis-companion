begin;

create extension if not exists pgtap with schema extensions;
select plan(29);

select has_table('public', 'alarm_preferences', 'alarm_preferences remains the schedule table');
select ok(
  c.relrowsecurity,
  'alarm_preferences keeps RLS enabled'
)
from pg_class as c
join pg_namespace as n on n.oid = c.relnamespace
where n.nspname = 'public' and c.relname = 'alarm_preferences';
select ok(
  c.relforcerowsecurity,
  'alarm_preferences keeps forced RLS'
)
from pg_class as c
join pg_namespace as n on n.oid = c.relnamespace
where n.nspname = 'public' and c.relname = 'alarm_preferences';
select table_privs_are(
  'public', 'alarm_preferences', 'authenticated', array['SELECT'],
  'authenticated has explicit SELECT only'
);
select ok(
  not has_table_privilege('authenticated', 'public.alarm_preferences', 'INSERT'),
  'authenticated has no direct INSERT'
);
select ok(
  not has_table_privilege('authenticated', 'public.alarm_preferences', 'UPDATE'),
  'authenticated has no direct UPDATE'
);
select ok(
  not has_table_privilege('authenticated', 'public.alarm_preferences', 'DELETE'),
  'authenticated has no direct DELETE'
);

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, created_at, updated_at
) values
  (
    '00000000-0000-0000-0000-000000000000',
    '11111111-1111-4111-8111-111111111111',
    'authenticated', 'authenticated', 'schedule-owner@example.invalid', '',
    now(), now(), now()
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '22222222-2222-4222-8222-222222222222',
    'authenticated', 'authenticated', 'schedule-other@example.invalid', '',
    now(), now(), now()
  );

set local role authenticated;
select set_config('request.jwt.claim.sub', '11111111-1111-4111-8111-111111111111', true);
select set_config('request.jwt.claim.role', 'authenticated', true);

select lives_ok(
  $test$
  select * from public.apply_sync_mutation(
    'a1000000-0000-4000-8000-000000000001',
    'a2000000-0000-4000-8000-000000000001',
    'alarm',
    'a3000000-0000-4000-8000-000000000001',
    'upsert',
    0,
    1,
    '{
      "id":"a3000000-0000-4000-8000-000000000001",
      "owner_user_id":"11111111-1111-4111-8111-111111111111",
      "schedule_name":"Everyday sleep",
      "schedule_kind":"sleep",
      "sleep_hour":22,
      "sleep_minute":30,
      "local_hour":6,
      "local_minute":30,
      "weekdays_mask":127,
      "one_time_local_date":null,
      "bedtime_reminder_lead_minutes":15,
      "prewake_lead_minutes":15,
      "wake_audio_kind":"bundled",
      "wake_audio_reference":"soft-rise",
      "display_order":0,
      "enabled_intent":true,
      "revision":1
    }'::jsonb
  )
  $test$,
  'owner creates a recurring sleep schedule'
);
select is(
  (select schedule_kind from public.alarm_preferences where id = 'a3000000-0000-4000-8000-000000000001'),
  'sleep',
  'sleep schedule kind is persisted'
);

select lives_ok(
  $test$
  select * from public.apply_sync_mutation(
    'a1000000-0000-4000-8000-000000000002',
    'a2000000-0000-4000-8000-000000000002',
    'alarm',
    'a3000000-0000-4000-8000-000000000002',
    'upsert',
    0,
    1,
    '{
      "id":"a3000000-0000-4000-8000-000000000002",
      "owner_user_id":"11111111-1111-4111-8111-111111111111",
      "schedule_name":"Workday wake",
      "schedule_kind":"wake_only",
      "sleep_hour":null,
      "sleep_minute":null,
      "local_hour":7,
      "local_minute":0,
      "weekdays_mask":62,
      "one_time_local_date":null,
      "bedtime_reminder_lead_minutes":null,
      "prewake_lead_minutes":10,
      "wake_audio_kind":"catalog",
      "wake_audio_reference":"catalog-calm-bell",
      "display_order":1,
      "enabled_intent":true,
      "revision":1
    }'::jsonb
  )
  $test$,
  'owner creates a recurring wake-only schedule'
);
select is(
  (select wake_audio_kind from public.alarm_preferences where id = 'a3000000-0000-4000-8000-000000000002'),
  'catalog',
  'catalog audio choice is persisted independently'
);

select throws_ok(
  $test$
  select * from public.apply_sync_mutation(
    'a1000000-0000-4000-8000-000000000003',
    'a2000000-0000-4000-8000-000000000003',
    'alarm',
    'a3000000-0000-4000-8000-000000000003',
    'upsert',
    0,
    1,
    '{
      "id":"a3000000-0000-4000-8000-000000000003",
      "owner_user_id":"11111111-1111-4111-8111-111111111111",
      "schedule_name":"One-time alarm",
      "schedule_kind":"wake_only",
      "sleep_hour":null,
      "sleep_minute":null,
      "local_hour":6,
      "local_minute":0,
      "weekdays_mask":0,
      "one_time_local_date":"2026-08-24",
      "bedtime_reminder_lead_minutes":null,
      "prewake_lead_minutes":null,
      "wake_audio_kind":"personal",
      "wake_audio_reference":"00000000-0000-0000-0000-000000000001",
      "display_order":2,
      "enabled_intent":false,
      "revision":1
    }'::jsonb
  )
  $test$,
  '22023', 'malformed alarm payload',
  'personal audio remains device-local and cannot cross the sync boundary'
);
select is(
  (select count(*)::integer from public.alarm_preferences),
  2,
  'multiple schedules coexist for one owner'
);
select is(
  (select count(*)::integer from public.alarm_preferences where id = 'a3000000-0000-4000-8000-000000000003'),
  0,
  'personal audio schedule is not persisted remotely'
);

select throws_ok(
  $test$
  select * from public.apply_sync_mutation(
    'a1000000-0000-4000-8000-000000000004',
    'a2000000-0000-4000-8000-000000000004',
    'alarm',
    'a3000000-0000-4000-8000-000000000004',
    'upsert', 0, 1,
    '{
      "id":"a3000000-0000-4000-8000-000000000004",
      "owner_user_id":"11111111-1111-4111-8111-111111111111",
      "schedule_name":"Missing sleep time",
      "schedule_kind":"sleep",
      "sleep_hour":null,
      "sleep_minute":null,
      "local_hour":6,
      "local_minute":30,
      "weekdays_mask":127,
      "bedtime_reminder_lead_minutes":15,
      "wake_audio_kind":"bundled",
      "wake_audio_reference":"soft-rise",
      "display_order":3,
      "enabled_intent":true,
      "revision":1
    }'::jsonb
  )
  $test$,
  '22023', 'malformed alarm payload',
  'sleep schedule requires both sleep time components'
);

select throws_ok(
  $test$
  select * from public.apply_sync_mutation(
    'a1000000-0000-4000-8000-000000000005',
    'a2000000-0000-4000-8000-000000000005',
    'alarm',
    'a3000000-0000-4000-8000-000000000005',
    'upsert', 0, 1,
    '{
      "id":"a3000000-0000-4000-8000-000000000005",
      "owner_user_id":"11111111-1111-4111-8111-111111111111",
      "schedule_name":"Sleep with date",
      "schedule_kind":"sleep",
      "sleep_hour":22,
      "sleep_minute":30,
      "local_hour":6,
      "local_minute":30,
      "weekdays_mask":127,
      "one_time_local_date":"2026-08-24",
      "wake_audio_kind":"bundled",
      "wake_audio_reference":"soft-rise",
      "display_order":3,
      "enabled_intent":true,
      "revision":1
    }'::jsonb
  )
  $test$,
  '22023', 'malformed alarm payload',
  'sleep schedule cannot carry a one-time date'
);

select throws_ok(
  $test$
  select * from public.apply_sync_mutation(
    'a1000000-0000-4000-8000-000000000006',
    'a2000000-0000-4000-8000-000000000006',
    'alarm',
    'a3000000-0000-4000-8000-000000000006',
    'upsert', 0, 1,
    '{
      "id":"a3000000-0000-4000-8000-000000000006",
      "owner_user_id":"11111111-1111-4111-8111-111111111111",
      "schedule_name":"Wake with bedtime reminder",
      "schedule_kind":"wake_only",
      "sleep_hour":null,
      "sleep_minute":null,
      "local_hour":6,
      "local_minute":30,
      "weekdays_mask":62,
      "one_time_local_date":null,
      "bedtime_reminder_lead_minutes":15,
      "wake_audio_kind":"bundled",
      "wake_audio_reference":"soft-rise",
      "display_order":3,
      "enabled_intent":true,
      "revision":1
    }'::jsonb
  )
  $test$,
  '22023', 'malformed alarm payload',
  'wake-only schedule cannot carry a bedtime reminder'
);

select throws_ok(
  $test$
  select * from public.apply_sync_mutation(
    'a1000000-0000-4000-8000-000000000007',
    'a2000000-0000-4000-8000-000000000007',
    'alarm',
    'a3000000-0000-4000-8000-000000000007',
    'upsert', 0, 1,
    '{
      "id":"a3000000-0000-4000-8000-000000000007",
      "owner_user_id":"11111111-1111-4111-8111-111111111111",
      "schedule_name":"Conflicting one-time shape",
      "schedule_kind":"wake_only",
      "sleep_hour":null,
      "sleep_minute":null,
      "local_hour":6,
      "local_minute":30,
      "weekdays_mask":62,
      "one_time_local_date":"2026-08-24",
      "wake_audio_kind":"bundled",
      "wake_audio_reference":"soft-rise",
      "display_order":3,
      "enabled_intent":true,
      "revision":1
    }'::jsonb
  )
  $test$,
  '22023', 'malformed alarm payload',
  'one-time wake-only schedule cannot carry repeat days'
);

select throws_ok(
  $test$
  select * from public.apply_sync_mutation(
    'a1000000-0000-4000-8000-000000000008',
    'a2000000-0000-4000-8000-000000000008',
    'alarm',
    'a3000000-0000-4000-8000-000000000008',
    'upsert', 0, 1,
    '{
      "id":"a3000000-0000-4000-8000-000000000008",
      "owner_user_id":"11111111-1111-4111-8111-111111111111",
      "schedule_name":"No repeat or date",
      "schedule_kind":"wake_only",
      "sleep_hour":null,
      "sleep_minute":null,
      "local_hour":6,
      "local_minute":30,
      "weekdays_mask":0,
      "one_time_local_date":null,
      "wake_audio_kind":"bundled",
      "wake_audio_reference":"soft-rise",
      "display_order":3,
      "enabled_intent":true,
      "revision":1
    }'::jsonb
  )
  $test$,
  '22023', 'malformed alarm payload',
  'wake-only schedule needs repeat days or a one-time date'
);

select throws_ok(
  $test$
  select * from public.apply_sync_mutation(
    'a1000000-0000-4000-8000-000000000009',
    'a2000000-0000-4000-8000-000000000009',
    'alarm',
    'a3000000-0000-4000-8000-000000000009',
    'upsert', 0, 1,
    '{
      "id":"a3000000-0000-4000-8000-000000000009",
      "owner_user_id":"11111111-1111-4111-8111-111111111111",
      "schedule_name":"Unknown field",
      "schedule_kind":"wake_only",
      "sleep_hour":null,
      "sleep_minute":null,
      "local_hour":6,
      "local_minute":30,
      "weekdays_mask":62,
      "one_time_local_date":null,
      "wake_audio_kind":"bundled",
      "wake_audio_reference":"soft-rise",
      "display_order":3,
      "enabled_intent":true,
      "revision":1,
      "server_updated_at":"2030-01-01T00:00:00Z"
    }'::jsonb
  )
  $test$,
  '22023', 'malformed alarm payload',
  'strict alarm allow-list rejects server-owned fields'
);

select throws_ok(
  $test$
  select * from public.apply_sync_mutation(
    'a1000000-0000-4000-8000-00000000000a',
    'a2000000-0000-4000-8000-00000000000a',
    'alarm',
    'a3000000-0000-4000-8000-00000000000a',
    'upsert', 0, 1,
    '{
      "id":"a3000000-0000-4000-8000-00000000000a",
      "owner_user_id":"22222222-2222-4222-8222-222222222222",
      "schedule_name":"Foreign owner",
      "schedule_kind":"wake_only",
      "sleep_hour":null,
      "sleep_minute":null,
      "local_hour":6,
      "local_minute":30,
      "weekdays_mask":62,
      "one_time_local_date":null,
      "wake_audio_kind":"bundled",
      "wake_audio_reference":"soft-rise",
      "display_order":3,
      "enabled_intent":true,
      "revision":1
    }'::jsonb
  )
  $test$,
  '42501', 'payload ownership or identity mismatch',
  'foreign owner payload is rejected'
);

select lives_ok(
  $test$
  select * from public.apply_sync_mutation(
    'a1000000-0000-4000-8000-00000000000b',
    'a2000000-0000-4000-8000-00000000000b',
    'alarm',
    'a3000000-0000-4000-8000-000000000001',
    'upsert', 1, 2,
    '{
      "id":"a3000000-0000-4000-8000-000000000001",
      "owner_user_id":"11111111-1111-4111-8111-111111111111",
      "schedule_name":"Everyday sleep updated",
      "schedule_kind":"sleep",
      "sleep_hour":22,
      "sleep_minute":30,
      "local_hour":6,
      "local_minute":45,
      "weekdays_mask":127,
      "one_time_local_date":null,
      "bedtime_reminder_lead_minutes":15,
      "prewake_lead_minutes":15,
      "wake_audio_kind":"bundled",
      "wake_audio_reference":"soft-rise",
      "display_order":0,
      "enabled_intent":true,
      "revision":2
    }'::jsonb
  )
  $test$,
  'schedule update advances revision'
);

select throws_ok(
  $test$
  select * from public.apply_sync_mutation(
    'a1000000-0000-4000-8000-00000000000c',
    'a2000000-0000-4000-8000-00000000000c',
    'alarm',
    'a3000000-0000-4000-8000-000000000001',
    'upsert', 0, 1,
    '{
      "id":"a3000000-0000-4000-8000-000000000001",
      "owner_user_id":"11111111-1111-4111-8111-111111111111",
      "schedule_name":"Stale update",
      "schedule_kind":"sleep",
      "sleep_hour":22,
      "sleep_minute":30,
      "local_hour":6,
      "local_minute":30,
      "weekdays_mask":127,
      "one_time_local_date":null,
      "bedtime_reminder_lead_minutes":15,
      "prewake_lead_minutes":15,
      "wake_audio_kind":"bundled",
      "wake_audio_reference":"soft-rise",
      "display_order":0,
      "enabled_intent":true,
      "revision":1
    }'::jsonb
  )
  $test$,
  '40001', 'alarm revision conflict',
  'stale schedule revision is rejected'
);

select lives_ok(
  $test$
  select * from public.apply_sync_mutation(
    'a1000000-0000-4000-8000-00000000000d',
    'a2000000-0000-4000-8000-00000000000d',
    'tombstone',
    'a4000000-0000-4000-8000-000000000001',
    'delete', 1, 2,
    '{
      "id":"a4000000-0000-4000-8000-000000000001",
      "owner_user_id":"11111111-1111-4111-8111-111111111111",
      "entity_type":"alarm",
      "entity_id":"a3000000-0000-4000-8000-000000000001",
      "deleted_revision":2,
      "deleted_at":"2026-08-21T00:00:00Z"
    }'::jsonb
  )
  $test$,
  'alarm deletion is accepted through the tombstone RPC'
);
select is(
  (select count(*)::integer from public.alarm_preferences),
  1,
  'deleted schedule is removed from the schedule list'
);
select is(
  (
    select count(*)::integer from public.deletion_tombstones
    where entity_type = 'alarm'
      and entity_id = 'a3000000-0000-4000-8000-000000000001'
  ),
  1,
  'deleted schedule has one alarm tombstone'
);

select throws_ok(
  $test$
  select * from public.apply_sync_mutation(
    'a1000000-0000-4000-8000-00000000000e',
    'a2000000-0000-4000-8000-00000000000e',
    'alarm',
    'a3000000-0000-4000-8000-000000000001',
    'upsert', 2, 3,
    '{
      "id":"a3000000-0000-4000-8000-000000000001",
      "owner_user_id":"11111111-1111-4111-8111-111111111111",
      "schedule_name":"Resurrection",
      "schedule_kind":"sleep",
      "sleep_hour":22,
      "sleep_minute":30,
      "local_hour":6,
      "local_minute":30,
      "weekdays_mask":127,
      "one_time_local_date":null,
      "wake_audio_kind":"bundled",
      "wake_audio_reference":"soft-rise",
      "display_order":0,
      "enabled_intent":true,
      "revision":3
    }'::jsonb
  )
  $test$,
  '23514', 'tombstoned alarm cannot be resurrected',
  'deleted schedule cannot be recreated with the same UUID'
);

select set_config('request.jwt.claim.sub', '22222222-2222-4222-8222-222222222222', true);
select results_eq(
  $test$select count(*)::bigint from public.alarm_preferences$test$,
  array[0::bigint],
  'another owner cannot read schedule rows'
);

select throws_ok(
  $test$
  select * from public.apply_sync_mutation(
    'a1000000-0000-4000-8000-00000000000f',
    'a2000000-0000-4000-8000-00000000000f',
    'alarm',
    'a3000000-0000-4000-8000-000000000001',
    'upsert', 2, 3,
    '{
      "id":"a3000000-0000-4000-8000-000000000001",
      "owner_user_id":"11111111-1111-4111-8111-111111111111",
      "schedule_name":"Cross-account update",
      "schedule_kind":"sleep",
      "sleep_hour":22,
      "sleep_minute":30,
      "local_hour":6,
      "local_minute":30,
      "weekdays_mask":127,
      "one_time_local_date":null,
      "bedtime_reminder_lead_minutes":15,
      "wake_audio_kind":"bundled",
      "wake_audio_reference":"soft-rise",
      "display_order":0,
      "enabled_intent":true,
      "revision":3
    }'::jsonb
  )
  $test$,
  '42501', 'payload ownership or identity mismatch',
  'another owner cannot forge a schedule mutation'
);

select * from finish();
rollback;
