begin;

create extension if not exists pgtap with schema extensions;
select plan(61);

select has_table('public', 'app_profiles', 'app_profiles exists');
select has_table('public', 'app_settings', 'app_settings exists');
select has_table('public', 'alarm_preferences', 'alarm_preferences exists');
select has_table('public', 'submitted_checkins', 'submitted_checkins exists');
select has_table('public', 'deletion_tombstones', 'deletion_tombstones exists');
select has_table('public', 'mutation_receipts', 'mutation_receipts exists');
select has_table('public', 'account_deletion_audit', 'account_deletion_audit exists');

select ok(c.relrowsecurity, c.relname || ' has RLS enabled')
from pg_class as c
join pg_namespace as n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relname in (
    'app_profiles',
    'app_settings',
    'alarm_preferences',
    'submitted_checkins',
    'deletion_tombstones',
    'mutation_receipts',
    'account_deletion_audit'
  )
order by c.relname;

select ok(c.relforcerowsecurity, c.relname || ' forces RLS')
from pg_class as c
join pg_namespace as n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relname in (
    'app_profiles',
    'app_settings',
    'alarm_preferences',
    'submitted_checkins',
    'deletion_tombstones',
    'mutation_receipts',
    'account_deletion_audit'
  )
order by c.relname;

select ok(
  not has_table_privilege('anon', 'public.app_profiles', 'select'),
  'anon has no profile SELECT grant'
);
select ok(
  not has_table_privilege('anon', 'public.submitted_checkins', 'insert'),
  'anon has no check-in INSERT grant'
);
select ok(
  has_table_privilege('authenticated', 'public.submitted_checkins', 'select'),
  'authenticated receives explicit check-in SELECT'
);
select ok(
  not has_column_privilege('authenticated', 'public.submitted_checkins', 'note', 'insert'),
  'authenticated cannot directly insert the approved note field'
);
select ok(
  not has_column_privilege(
    'authenticated',
    'public.submitted_checkins',
    'server_updated_at',
    'insert'
  ),
  'authenticated cannot over-post server_updated_at'
);
select ok(
  not has_column_privilege(
    'authenticated',
    'public.submitted_checkins',
    'owner_user_id',
    'update'
  ),
  'authenticated cannot update owner_user_id'
);
select ok(
  not has_table_privilege('authenticated', 'public.account_deletion_audit', 'select'),
  'account deletion audit is unavailable to authenticated clients'
);

select is(
  (
    select count(*)::integer
    from pg_policies
    where schemaname = 'public'
      and tablename in (
        'app_profiles',
        'app_settings',
        'alarm_preferences',
        'submitted_checkins',
        'deletion_tombstones'
      )
      and cmd = 'UPDATE'
      and qual is not null
      and with_check is not null
  ),
  5,
  'every owned entity retains UPDATE USING and WITH CHECK as defense in depth'
);

select ok(
  not exists (
    select 1
    from pg_proc as p
    join pg_namespace as n on n.oid = p.pronamespace
    where n.nspname in ('public', 'graphql_public')
      and p.prosecdef
      and (
        has_function_privilege('anon', p.oid, 'execute')
        or has_function_privilege('authenticated', p.oid, 'execute')
      )
  ),
  'no public security-definer function is executable by API users'
);

insert into auth.users (
  instance_id,
  id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  created_at,
  updated_at
) values
  (
    '00000000-0000-0000-0000-000000000000',
    '11111111-1111-4111-8111-111111111111',
    'authenticated',
    'authenticated',
    'owner-one@example.invalid',
    '',
    now(),
    now(),
    now()
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '22222222-2222-4222-8222-222222222222',
    'authenticated',
    'authenticated',
    'owner-two@example.invalid',
    '',
    now(),
    now(),
    now()
  );

set local role authenticated;
select set_config('request.jwt.claim.sub', '11111111-1111-4111-8111-111111111111', true);
select set_config('request.jwt.claim.role', 'authenticated', true);

select throws_ok(
  $test$
  insert into public.app_profiles (id, owner_user_id, profile_created_at, revision)
  values (
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    '11111111-1111-4111-8111-111111111111',
    '2026-07-28T00:00:00Z',
    1
  )
  $test$,
  '42501',
  null,
  'owner direct profile INSERT is denied'
);

select throws_ok(
  $test$
  insert into public.app_settings (
    id, owner_user_id, preferred_grounding_asset_id,
    preferred_modality, haptics_enabled, revision
  ) values (
    'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
    '11111111-1111-4111-8111-111111111111',
    null,
    'silent',
    false,
    1
  )
  $test$,
  '42501',
  null,
  'owner direct settings INSERT is denied'
);

select throws_ok(
  $test$
  insert into public.alarm_preferences (
    id, owner_user_id, local_hour, local_minute, weekdays_mask,
    snooze_minutes, enabled_intent, revision
  ) values (
    'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
    '11111111-1111-4111-8111-111111111111',
    22,
    30,
    62,
    10,
    true,
    1
  )
  $test$,
  '42501',
  null,
  'owner direct alarm INSERT is denied'
);

select throws_ok(
  $test$
  insert into public.submitted_checkins (
    id, owner_user_id, reported_for_local_date, reported_timezone_id,
    occurrence, perceived_intensity, present_state, note,
    created_at, updated_at, revision, deleted_at
  ) values (
    'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
    '11111111-1111-4111-8111-111111111111',
    '2026-07-27',
    'Asia/Calcutta',
    'yes',
    'mild',
    'fine_now',
    'synthetic note',
    '2026-07-28T00:00:00Z',
    '2026-07-28T00:00:00Z',
    1,
    null
  )
  $test$,
  '42501',
  null,
  'owner direct check-in INSERT is denied'
);

select lives_ok(
  $test$
  select * from public.apply_sync_mutation(
    '31000000-0000-4000-8000-000000000001',
    '32000000-0000-4000-8000-000000000001',
    'profile',
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    'upsert',
    0,
    1,
    '{
      "id":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
      "owner_user_id":"11111111-1111-4111-8111-111111111111",
      "profile_created_at":"2026-07-28T00:00:00Z",
      "revision":1
    }'::jsonb
  )
  $test$,
  'owner creates a profile through the mutation RPC'
);

select lives_ok(
  $test$
  select * from public.apply_sync_mutation(
    '31000000-0000-4000-8000-000000000002',
    '32000000-0000-4000-8000-000000000002',
    'settings',
    'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
    'upsert',
    0,
    1,
    '{
      "id":"bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb",
      "owner_user_id":"11111111-1111-4111-8111-111111111111",
      "preferred_grounding_asset_id":null,
      "preferred_modality":"silent",
      "haptics_enabled":false,
      "revision":1
    }'::jsonb
  )
  $test$,
  'owner creates settings through the mutation RPC'
);

select lives_ok(
  $test$
  select * from public.apply_sync_mutation(
    '31000000-0000-4000-8000-000000000003',
    '32000000-0000-4000-8000-000000000003',
    'alarm',
    'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
    'upsert',
    0,
    1,
    '{
      "id":"cccccccc-cccc-4ccc-8ccc-cccccccccccc",
      "owner_user_id":"11111111-1111-4111-8111-111111111111",
      "local_hour":22,
      "local_minute":30,
      "weekdays_mask":62,
      "snooze_minutes":10,
      "enabled_intent":true,
      "revision":1
    }'::jsonb
  )
  $test$,
  'owner creates an alarm through the mutation RPC'
);

select lives_ok(
  $test$
  select * from public.apply_sync_mutation(
    '31000000-0000-4000-8000-000000000004',
    '32000000-0000-4000-8000-000000000004',
    'checkin',
    'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
    'upsert',
    0,
    1,
    '{
      "id":"dddddddd-dddd-4ddd-8ddd-dddddddddddd",
      "owner_user_id":"11111111-1111-4111-8111-111111111111",
      "reported_for_local_date":"2026-07-27",
      "reported_timezone_id":"Asia/Calcutta",
      "occurrence":"yes",
      "perceived_intensity":"mild",
      "present_state":"fine_now",
      "note":"synthetic note",
      "created_at":"2026-07-28T00:00:00Z",
      "updated_at":"2026-07-28T00:00:00Z",
      "revision":1,
      "deleted_at":null
    }'::jsonb
  )
  $test$,
  'owner creates a check-in through the mutation RPC'
);

select results_eq(
  $test$select count(*)::bigint from public.submitted_checkins$test$,
  array[1::bigint],
  'owner-scoped SELECT exposes the RPC-created check-in'
);

select throws_ok(
  $test$
  update public.submitted_checkins
  set note = 'direct edit', revision = 2, updated_at = '2026-07-28T00:01:00Z'
  where id = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd'
  $test$,
  '42501',
  null,
  'owner direct UPDATE is denied'
);

select throws_ok(
  $test$
  delete from public.submitted_checkins
  where id = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd'
  $test$,
  '42501',
  null,
  'owner direct DELETE is denied'
);

select set_config('request.jwt.claim.sub', '22222222-2222-4222-8222-222222222222', true);

select results_eq(
  $test$select count(*)::bigint from public.submitted_checkins$test$,
  array[0::bigint],
  'another authenticated owner cannot read owner-one rows'
);

select throws_ok(
  $test$
  select * from public.apply_sync_mutation(
    '33000000-0000-4000-8000-000000000001',
    '34000000-0000-4000-8000-000000000001',
    'settings',
    'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
    'upsert',
    1,
    2,
    '{
      "id":"bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb",
      "owner_user_id":"11111111-1111-4111-8111-111111111111",
      "preferred_grounding_asset_id":null,
      "preferred_modality":"silent",
      "haptics_enabled":true,
      "revision":2
    }'::jsonb
  )
  $test$,
  '42501',
  'payload ownership or identity mismatch',
  'another owner cannot forge an RPC payload for owner one'
);

select throws_ok(
  $test$
  update public.submitted_checkins
  set note = 'cross-account direct edit', revision = 2
  where id = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd'
  $test$,
  '42501',
  null,
  'another owner has no direct UPDATE privilege'
);

set local role anon;
select set_config('request.jwt.claim.sub', '', true);
select set_config('request.jwt.claim.role', 'anon', true);

select throws_ok(
  $test$select * from public.submitted_checkins$test$,
  '42501',
  null,
  'anon cannot SELECT app-owned rows'
);

select throws_ok(
  $test$
  insert into public.app_profiles (id, owner_user_id, profile_created_at, revision)
  values (
    'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
    '11111111-1111-4111-8111-111111111111',
    now(),
    1
  )
  $test$,
  '42501',
  null,
  'anon cannot INSERT app-owned rows'
);

select throws_ok(
  $test$
  select * from public.apply_sync_mutation(
    '35000000-0000-4000-8000-000000000001',
    '36000000-0000-4000-8000-000000000001',
    'profile',
    'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
    'upsert',
    0,
    1,
    '{
      "id":"eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee",
      "owner_user_id":"11111111-1111-4111-8111-111111111111",
      "profile_created_at":"2026-07-28T00:00:00Z",
      "revision":1
    }'::jsonb
  )
  $test$,
  '42501',
  null,
  'anon cannot execute the mutation RPC'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '', true);
select set_config('request.jwt.claim.role', 'authenticated', true);

select results_eq(
  $test$select count(*)::bigint from public.submitted_checkins$test$,
  array[0::bigint],
  'missing or invalid subject cannot read rows'
);

select throws_ok(
  $test$
  select * from public.apply_sync_mutation(
    '37000000-0000-4000-8000-000000000001',
    '38000000-0000-4000-8000-000000000001',
    'profile',
    'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
    'upsert',
    0,
    1,
    '{
      "id":"eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee",
      "owner_user_id":"11111111-1111-4111-8111-111111111111",
      "profile_created_at":"2026-07-28T00:00:00Z",
      "revision":1
    }'::jsonb
  )
  $test$,
  '42501',
  'authentication required',
  'missing subject cannot cross the trusted mutation boundary'
);

select set_config('request.jwt.claim.sub', '11111111-1111-4111-8111-111111111111', true);

select lives_ok(
  $test$
  select * from public.apply_sync_mutation(
    '39000000-0000-4000-8000-000000000001',
    '3a000000-0000-4000-8000-000000000001',
    'settings',
    'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
    'upsert',
    1,
    2,
    '{
      "id":"bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb",
      "owner_user_id":"11111111-1111-4111-8111-111111111111",
      "preferred_grounding_asset_id":null,
      "preferred_modality":"silent",
      "haptics_enabled":true,
      "revision":2
    }'::jsonb
  )
  $test$,
  'owner updates settings through the mutation RPC'
);

select results_eq(
  $test$
  select accepted_revision from public.apply_sync_mutation(
    '3b000000-0000-4000-8000-000000000001',
    '3a000000-0000-4000-8000-000000000001',
    'settings',
    'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
    'upsert',
    1,
    2,
    '{
      "id":"bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb",
      "owner_user_id":"11111111-1111-4111-8111-111111111111",
      "preferred_grounding_asset_id":null,
      "preferred_modality":"silent",
      "haptics_enabled":true,
      "revision":2
    }'::jsonb
  )
  $test$,
  array[2::bigint],
  'RPC replay returns the committed settings revision'
);

select throws_ok(
  $test$
  select * from public.apply_sync_mutation(
    '3c000000-0000-4000-8000-000000000001',
    '3d000000-0000-4000-8000-000000000001',
    'settings',
    'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
    'upsert',
    2,
    3,
    '{
      "id":"bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb",
      "owner_user_id":"11111111-1111-4111-8111-111111111111",
      "preferred_modality":"silent",
      "haptics_enabled":true,
      "revision":3,
      "server_updated_at":"2030-01-01T00:00:00Z"
    }'::jsonb
  )
  $test$,
  '22023',
  'malformed settings payload',
  'RPC rejects over-posted server-owned fields'
);

select lives_ok(
  $test$
  select * from public.apply_sync_mutation(
    '3e000000-0000-4000-8000-000000000001',
    '3f000000-0000-4000-8000-000000000001',
    'tombstone',
    '40000000-0000-4000-8000-000000000001',
    'delete',
    1,
    2,
    '{
      "id":"40000000-0000-4000-8000-000000000001",
      "owner_user_id":"11111111-1111-4111-8111-111111111111",
      "entity_type":"checkin",
      "entity_id":"dddddddd-dddd-4ddd-8ddd-dddddddddddd",
      "deleted_revision":2,
      "deleted_at":"2026-07-28T00:03:00Z"
    }'::jsonb
  )
  $test$,
  'owner tombstones a check-in through the mutation RPC'
);

select throws_ok(
  $test$
  select * from public.apply_sync_mutation(
    '41000000-0000-4000-8000-000000000001',
    '42000000-0000-4000-8000-000000000001',
    'checkin',
    'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
    'upsert',
    2,
    3,
    '{
      "id":"dddddddd-dddd-4ddd-8ddd-dddddddddddd",
      "owner_user_id":"11111111-1111-4111-8111-111111111111",
      "reported_for_local_date":"2026-07-27",
      "reported_timezone_id":"Asia/Calcutta",
      "occurrence":"no",
      "perceived_intensity":null,
      "present_state":null,
      "note":"resurrection attempt",
      "created_at":"2026-07-28T00:00:00Z",
      "updated_at":"2026-07-28T00:04:00Z",
      "revision":3,
      "deleted_at":null
    }'::jsonb
  )
  $test$,
  '23514',
  'tombstoned check-in cannot be resurrected',
  'RPC rejects check-in resurrection'
);

select throws_ok(
  $test$
  update public.submitted_checkins
  set deleted_at = null,
      updated_at = '2026-07-28T00:04:00Z',
      revision = 3
  where id = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd'
  $test$,
  '42501',
  null,
  'direct UPDATE cannot bypass resurrection protection'
);

select results_eq(
  $test$select count(*)::bigint from public.deletion_tombstones$test$,
  array[1::bigint],
  'owner-scoped SELECT exposes the RPC-created tombstone'
);

select is(
  (select count(*)::integer from public.mutation_receipts),
  6,
  'successful RPC writes and tombstone create exactly six receipts'
);

select set_config('request.jwt.claim.sub', '22222222-2222-4222-8222-222222222222', true);
select results_eq(
  $test$select count(*)::bigint from public.deletion_tombstones$test$,
  array[0::bigint],
  'another authenticated owner cannot read owner-one tombstones'
);

reset role;
create table public.future_privilege_probe (id bigint primary key);
select ok(
  not has_table_privilege('anon', 'public.future_privilege_probe', 'select')
    and not has_table_privilege('authenticated', 'public.future_privilege_probe', 'select'),
  'default privileges do not expose future tables'
);
drop table public.future_privilege_probe;

delete from auth.users where id = '11111111-1111-4111-8111-111111111111';
set local role authenticated;
select set_config('request.jwt.claim.sub', '11111111-1111-4111-8111-111111111111', true);

select is(
  (
    select
      (select count(*) from public.app_profiles)
      + (select count(*) from public.app_settings)
      + (select count(*) from public.alarm_preferences)
      + (select count(*) from public.submitted_checkins)
      + (select count(*) from public.deletion_tombstones)
      + (select count(*) from public.mutation_receipts)
      + (select count(*) from public.persona_answer_aggregates)
  )::integer,
  0,
  'deleted account has no remaining owner-scoped app rows'
);

select throws_ok(
  $test$
  select * from public.apply_sync_mutation(
    '43000000-0000-4000-8000-000000000001',
    '44000000-0000-4000-8000-000000000001',
    'profile',
    'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
    'upsert',
    0,
    1,
    '{
      "id":"eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee",
      "owner_user_id":"11111111-1111-4111-8111-111111111111",
      "profile_created_at":"2026-07-28T00:00:00Z",
      "revision":1
    }'::jsonb
  )
  $test$,
  '23503',
  null,
  'deleted account cannot create rows through the mutation RPC'
);

select * from finish();
rollback;
