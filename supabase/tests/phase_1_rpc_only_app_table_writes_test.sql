begin;

create extension if not exists pgtap with schema extensions;
select plan(21);

select table_privs_are(
  'public',
  'app_profiles',
  'authenticated',
  array['SELECT'],
  'app_profiles exposes owner-scoped SELECT only'
);
select table_privs_are('public', 'app_settings', 'authenticated', array['SELECT'], 'app_settings exposes SELECT only');
select table_privs_are('public', 'alarm_preferences', 'authenticated', array['SELECT'], 'alarm_preferences exposes SELECT only');
select table_privs_are('public', 'submitted_checkins', 'authenticated', array['SELECT'], 'submitted_checkins exposes SELECT only');
select table_privs_are('public', 'deletion_tombstones', 'authenticated', array['SELECT'], 'deletion_tombstones exposes SELECT only');
select table_privs_are('public', 'mutation_receipts', 'authenticated', array['SELECT'], 'mutation_receipts exposes SELECT only');
select table_privs_are('public', 'persona_answer_aggregates', 'authenticated', array['SELECT'], 'persona aggregates expose SELECT only');
select table_privs_are('public', 'account_deletion_audit', 'authenticated', array[]::text[], 'account deletion audit is not client-readable or writable');

select is(
  (
    select count(*)::integer
    from information_schema.column_privileges
    where grantee = 'authenticated'
      and table_schema = 'public'
      and table_name = 'app_profiles'
      and privilege_type in ('INSERT', 'UPDATE')
  ),
  0,
  'app_profiles has no column DML grants'
);
select is((select count(*)::integer from information_schema.column_privileges where grantee = 'authenticated' and table_schema = 'public' and table_name = 'app_settings' and privilege_type in ('INSERT', 'UPDATE')), 0, 'app_settings has no column DML grants');
select is((select count(*)::integer from information_schema.column_privileges where grantee = 'authenticated' and table_schema = 'public' and table_name = 'alarm_preferences' and privilege_type in ('INSERT', 'UPDATE')), 0, 'alarm_preferences has no column DML grants');
select is((select count(*)::integer from information_schema.column_privileges where grantee = 'authenticated' and table_schema = 'public' and table_name = 'submitted_checkins' and privilege_type in ('INSERT', 'UPDATE')), 0, 'submitted_checkins has no column DML grants');
select is((select count(*)::integer from information_schema.column_privileges where grantee = 'authenticated' and table_schema = 'public' and table_name = 'deletion_tombstones' and privilege_type in ('INSERT', 'UPDATE')), 0, 'deletion_tombstones has no column DML grants');
select is((select count(*)::integer from information_schema.column_privileges where grantee = 'authenticated' and table_schema = 'public' and table_name = 'mutation_receipts' and privilege_type in ('INSERT', 'UPDATE')), 0, 'mutation_receipts has no column DML grants');
select is((select count(*)::integer from information_schema.column_privileges where grantee = 'authenticated' and table_schema = 'public' and table_name = 'persona_answer_aggregates' and privilege_type in ('INSERT', 'UPDATE')), 0, 'persona aggregates have no column DML grants');
select is((select count(*)::integer from information_schema.column_privileges where grantee = 'authenticated' and table_schema = 'public' and table_name = 'account_deletion_audit' and privilege_type in ('INSERT', 'UPDATE')), 0, 'account deletion audit has no column DML grants');

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, created_at, updated_at
) values (
  '00000000-0000-0000-0000-000000000000',
  '13131313-1313-4313-8313-131313131313',
  'authenticated',
  'authenticated',
  'rpc-only-owner@example.invalid',
  '',
  now(),
  now(),
  now()
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '13131313-1313-4313-8313-131313131313', true);
select set_config('request.jwt.claim.role', 'authenticated', true);

select throws_ok(
  $test$
  insert into public.app_profiles (id, owner_user_id, profile_created_at, revision)
  values (
    '14141414-1414-4414-8414-141414141414',
    '13131313-1313-4313-8313-131313131313',
    now(),
    1
  )
  $test$,
  '42501',
  null,
  'authenticated direct INSERT is denied'
);

select lives_ok(
  $test$
  select * from public.apply_sync_mutation(
    '15151515-1515-4515-8515-151515151515',
    '16161616-1616-4616-8616-161616161616',
    'profile',
    '14141414-1414-4414-8414-141414141414',
    'upsert',
    0,
    1,
    '{
      "id":"14141414-1414-4414-8414-141414141414",
      "owner_user_id":"13131313-1313-4313-8313-131313131313",
      "profile_created_at":"2026-07-31T00:00:00Z",
      "revision":1
    }'::jsonb
  )
  $test$,
  'public RPC reaches the private trusted mutation boundary'
);

select is(
  (
    select count(*)::integer
    from public.app_profiles
    where id = '14141414-1414-4414-8414-141414141414'
      and owner_user_id = '13131313-1313-4313-8313-131313131313'
  ),
  1,
  'RPC write is visible through owner-scoped SELECT'
);

select throws_ok(
  $test$
  delete from public.app_profiles
  where id = '14141414-1414-4414-8414-141414141414'
  $test$,
  '42501',
  null,
  'authenticated direct DELETE is denied'
);

select throws_ok(
  $test$
  update public.app_profiles
  set revision = 2
  where id = '14141414-1414-4414-8414-141414141414'
  $test$,
  '42501',
  null,
  'authenticated direct UPDATE is denied'
);

select * from finish();
rollback;
