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
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
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
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
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
  has_column_privilege('authenticated', 'public.submitted_checkins', 'note', 'insert'),
  'authenticated may insert the approved note field'
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
  'every client-updatable entity has UPDATE USING and WITH CHECK'
);

select ok(
  not exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
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

select lives_ok(
  $test$
  insert into public.app_profiles (id, owner_user_id, profile_created_at, revision)
  values (
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    '11111111-1111-4111-8111-111111111111',
    '2026-07-28T00:00:00Z',
    1
  )
  $test$,
  'owner can insert a profile'
);

select lives_ok(
  $test$
  insert into public.app_settings (
    id,
    owner_user_id,
    preferred_grounding_asset_id,
    preferred_modality,
    haptics_enabled,
    revision
  ) values (
    'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
    '11111111-1111-4111-8111-111111111111',
    null,
    'silent',
    false,
    1
  )
  $test$,
  'owner can insert settings'
);

select lives_ok(
  $test$
  insert into public.alarm_preferences (
    id,
    owner_user_id,
    local_hour,
    local_minute,
    weekdays_mask,
    snooze_minutes,
    enabled_intent,
    revision
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
  'owner can insert an alarm preference'
);

select lives_ok(
  $test$
  insert into public.submitted_checkins (
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
  'owner can insert an approved check-in'
);

select results_eq(
  $test$select count(*)::bigint from public.submitted_checkins$test$,
  array[1::bigint],
  'owner can select own check-in'
);

select lives_ok(
  $test$
  update public.submitted_checkins
  set note = 'synthetic edit', revision = 2, updated_at = '2026-07-28T00:01:00Z'
  where id = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd'
  $test$,
  'owner can update an approved field with the next revision'
);

select throws_ok(
  $test$
  update public.submitted_checkins
  set note = 'bad revision', revision = 4, updated_at = '2026-07-28T00:02:00Z'
  where id = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd'
  $test$,
  '23514',
  'revision must advance by one',
  'malformed revision is rejected'
);

select throws_ok(
  $test$
  insert into public.app_profiles (id, owner_user_id, profile_created_at, revision)
  values (
    'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
    '11111111-1111-4111-8111-111111111111',
    '2026-07-28T00:00:00Z',
    9
  )
  $test$,
  '23514',
  'initial revision must be 1',
  'invalid initial revision is rejected'
);

select throws_ok(
  $test$
  insert into public.app_profiles (
    id,
    owner_user_id,
    profile_created_at,
    revision,
    server_updated_at
  ) values (
    'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
    '11111111-1111-4111-8111-111111111111',
    '2026-07-28T00:00:00Z',
    1,
    '2030-01-01T00:00:00Z'
  )
  $test$,
  '42501',
  null,
  'over-posting server-owned fields is denied'
);

select throws_ok(
  $test$
  update public.submitted_checkins
  set owner_user_id = '22222222-2222-4222-8222-222222222222'
  where id = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd'
  $test$,
  '42501',
  null,
  'owner reassignment is denied'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '22222222-2222-4222-8222-222222222222', true);

select results_eq(
  $test$select count(*)::bigint from public.submitted_checkins$test$,
  array[0::bigint],
  'another authenticated user cannot read owner rows'
);

select results_eq(
  $test$
  update public.submitted_checkins
  set note = 'cross-account write', revision = 3
  where id = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd'
  returning 1::bigint
  $test$,
  array[]::bigint[],
  'another authenticated user cannot update owner rows'
);

select results_eq(
  $test$
  delete from public.submitted_checkins
  where id = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd'
  returning 1::bigint
  $test$,
  array[]::bigint[],
  'another authenticated user cannot delete owner rows'
);

select throws_ok(
  $test$
  insert into public.submitted_checkins (
    id, owner_user_id, reported_for_local_date, reported_timezone_id,
    occurrence, created_at, updated_at, revision
  ) values (
    'ffffffff-ffff-4fff-8fff-ffffffffffff',
    '11111111-1111-4111-8111-111111111111',
    '2026-07-26',
    'UTC',
    'no',
    now(),
    now(),
    1
  )
  $test$,
  '42501',
  null,
  'forged owner insert fails RLS'
);

set local role anon;
select throws_ok(
  $test$select * from public.submitted_checkins$test$,
  '42501',
  null,
  'anon cannot select app-owned rows'
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
  'anon cannot insert app-owned rows'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '', true);
select results_eq(
  $test$select count(*)::bigint from public.submitted_checkins$test$,
  array[0::bigint],
  'missing or invalid subject cannot read rows'
);

select set_config('request.jwt.claim.sub', '11111111-1111-4111-8111-111111111111', true);
select lives_ok(
  $test$
  update public.submitted_checkins
  set deleted_at = '2026-07-28T00:03:00Z',
      updated_at = '2026-07-28T00:03:00Z',
      revision = 3
  where id = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd'
  $test$,
  'owner can tombstone a check-in'
);

select throws_ok(
  $test$
  update public.submitted_checkins
  set deleted_at = null,
      updated_at = '2026-07-28T00:04:00Z',
      revision = 4
  where id = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd'
  $test$,
  '23514',
  'deleted check-in cannot be resurrected',
  'a tombstoned check-in cannot be resurrected'
);

select lives_ok(
  $test$
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
    '99999999-9999-4999-8999-999999999999',
    '11111111-1111-4111-8111-111111111111',
    'checkin',
    'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
    3,
    '2026-07-28T00:03:00Z',
    null,
    '2026-08-27T00:03:00Z'
  )
  $test$,
  'owner can create a deletion tombstone'
);

select lives_ok(
  $test$
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
    '88888888-8888-4888-8888-888888888888',
    '11111111-1111-4111-8111-111111111111',
    '77777777-7777-4777-8777-777777777777',
    'tombstone',
    '99999999-9999-4999-8999-999999999999',
    'delete',
    2,
    3,
    repeat('0', 64),
    now() + interval '30 days'
  )
  $test$,
  'owner can create an idempotency receipt'
);

select throws_ok(
  $test$
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
    '66666666-6666-4666-8666-666666666666',
    '11111111-1111-4111-8111-111111111111',
    '77777777-7777-4777-8777-777777777777',
    'tombstone',
    '99999999-9999-4999-8999-999999999999',
    'delete',
    2,
    3,
    repeat('0', 64),
    now() + interval '30 days'
  )
  $test$,
  '23505',
  null,
  'replayed idempotency key cannot duplicate a semantic mutation'
);

select lives_ok(
  $test$
  select * from public.apply_sync_mutation(
    '12121212-1212-4212-8212-121212121212',
    '13131313-1313-4313-8313-131313131313',
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
  'atomic mutation RPC applies the entity and receipt together'
);

select results_eq(
  $test$
  select accepted_revision from public.apply_sync_mutation(
    '14141414-1414-4414-8414-141414141414',
    '13131313-1313-4313-8313-131313131313',
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
  'RPC replay returns the committed acknowledgment without reapplying'
);

select throws_ok(
  $test$
  select * from public.apply_sync_mutation(
    '15151515-1515-4515-8515-151515151515',
    '16161616-1616-4616-8616-161616161616',
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

select throws_ok(
  $test$
  select * from public.apply_sync_mutation(
    '17171717-1717-4717-8717-171717171717',
    '18181818-1818-4818-8818-181818181818',
    'settings',
    'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
    'upsert',
    2,
    3,
    '{
      "id":"bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb",
      "owner_user_id":"22222222-2222-4222-8222-222222222222",
      "preferred_modality":"silent",
      "haptics_enabled":true,
      "revision":3
    }'::jsonb
  )
  $test$,
  '42501',
  'payload ownership or identity mismatch',
  'RPC rejects forged ownership'
);

select ok(
  not has_function_privilege(
    'anon',
    'public.apply_sync_mutation(uuid,uuid,text,uuid,text,bigint,bigint,jsonb)',
    'execute'
  ),
  'anon cannot execute the mutation RPC'
);

reset role;
create table public.future_privilege_probe (id bigint primary key);
select ok(
  not has_table_privilege('anon', 'public.future_privilege_probe', 'select')
  and not has_table_privilege('authenticated', 'public.future_privilege_probe', 'select'),
  'default privileges do not expose future tables'
);
drop table public.future_privilege_probe;

set local role authenticated;
select set_config('request.jwt.claim.sub', '11111111-1111-4111-8111-111111111111', true);
select lives_ok(
  $test$
  delete from public.alarm_preferences
  where id = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc'
  $test$,
  'owner can delete an alarm preference'
);

reset role;
delete from auth.users where id = '11111111-1111-4111-8111-111111111111';
set local role authenticated;
select set_config('request.jwt.claim.sub', '11111111-1111-4111-8111-111111111111', true);
select results_eq(
  $test$select count(*)::bigint from public.submitted_checkins$test$,
  array[0::bigint],
  'deleted account has no remaining rows'
);
select throws_ok(
  $test$
  insert into public.app_profiles (id, owner_user_id, profile_created_at, revision)
  values (
    '55555555-5555-4555-8555-555555555555',
    '11111111-1111-4111-8111-111111111111',
    now(),
    1
  )
  $test$,
  '23503',
  null,
  'deleted account cannot create new owned rows'
);

select * from finish();
rollback;
