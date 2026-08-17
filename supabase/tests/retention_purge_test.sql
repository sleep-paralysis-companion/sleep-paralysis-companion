begin;

create extension if not exists pgtap with schema extensions;
select plan(20);

select ok(
  to_regprocedure('private.purge_expired_deletion_metadata()') is not null,
  'private retention purge function exists'
);
select ok(
  (
    select prosecdef
    from pg_proc
    where oid = 'private.purge_expired_deletion_metadata()'::regprocedure
  ),
  'retention purge function is SECURITY DEFINER'
);
select ok(
  has_function_privilege(
    'service_role',
    'private.purge_expired_deletion_metadata()',
    'execute'
  ),
  'service_role can invoke the retention purge'
);
select ok(
  not has_function_privilege(
    'anon',
    'private.purge_expired_deletion_metadata()',
    'execute'
  ),
  'anon cannot invoke the retention purge'
);
select ok(
  not has_function_privilege(
    'authenticated',
    'private.purge_expired_deletion_metadata()',
    'execute'
  ),
  'authenticated cannot invoke the retention purge'
);

select is(
  (
    select count(*)::integer
    from cron.job
    where jobname = 'purge-expired-deletion-metadata'
  ),
  1,
  'one daily retention purge job is scheduled'
);
select ok(
  exists (
    select 1
    from cron.job
    where jobname = 'purge-expired-deletion-metadata'
      and schedule = '15 3 * * *'
      and command = 'select private.purge_expired_deletion_metadata();'
  ),
  'retention purge schedule invokes only the private function'
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
) values (
  '00000000-0000-0000-0000-000000000000',
  '81818181-8181-4818-8818-818181818181',
  'authenticated',
  'authenticated',
  'retention-purge-owner@example.invalid',
  '',
  now(),
  now(),
  now()
);

insert into public.account_deletion_audit (
  request_id,
  request_binding,
  completed_at,
  outcome,
  purge_after
) values
  (
    '91919191-9191-4919-8919-919191919191',
    repeat('a', 64),
    '1999-01-01T00:00:00Z',
    'completed',
    '2000-01-01T00:00:00Z'
  ),
  (
    '92929292-9292-4929-8929-929292929292',
    repeat('b', 64),
    '2998-01-01T00:00:00Z',
    'completed',
    '2999-01-01T00:00:00Z'
  );

insert into public.deletion_tombstones (
  id,
  owner_user_id,
  entity_type,
  entity_id,
  deleted_revision,
  deleted_at,
  acknowledged_at,
  purge_after
) values
  (
    'a1919191-9191-4919-8919-919191919191',
    '81818181-8181-4818-8818-818181818181',
    'checkin',
    'a2929292-9292-4929-8929-929292929292',
    1,
    '1999-01-01T00:00:00Z',
    '1999-01-02T00:00:00Z',
    '2000-01-01T00:00:00Z'
  ),
  (
    'a3939393-9393-4939-8939-939393939393',
    '81818181-8181-4818-8818-818181818181',
    'checkin',
    'a4949494-9494-4949-8949-949494949494',
    1,
    '2998-01-01T00:00:00Z',
    '2998-01-02T00:00:00Z',
    '2999-01-01T00:00:00Z'
  );

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
  received_at,
  expires_at
) values
  (
    'b1919191-9191-4919-8919-919191919191',
    '81818181-8181-4818-8818-818181818181',
    'b2929292-9292-4929-8929-929292929292',
    'profile',
    'b3939393-9393-4939-8939-939393939393',
    'upsert',
    0,
    1,
    repeat('c', 64),
    '1999-01-01T00:00:00Z',
    '2000-01-01T00:00:00Z'
  ),
  (
    'b4949494-9494-4949-8949-949494949494',
    '81818181-8181-4818-8818-818181818181',
    'b5959595-9595-4959-8959-959595959595',
    'profile',
    'b6969696-9696-4969-8969-969696969696',
    'upsert',
    0,
    1,
    repeat('d', 64),
    '2998-01-01T00:00:00Z',
    '2999-01-01T00:00:00Z'
  );

set local role service_role;
select lives_ok(
  $test$select private.purge_expired_deletion_metadata()$test$,
  'service_role purge removes expired metadata'
);
reset role;

select is(
  (select count(*)::integer from public.account_deletion_audit),
  1,
  'expired account-deletion audit rows are removed'
);
select is(
  (select count(*)::integer from public.deletion_tombstones),
  1,
  'expired deletion tombstones are removed'
);
select is(
  (select count(*)::integer from public.mutation_receipts),
  1,
  'expired mutation receipts are removed'
);
select is(
  (
    select count(*)::integer
    from public.account_deletion_audit
    where purge_after > now()
  ),
  1,
  'future account-deletion audit rows remain'
);
select is(
  (
    select count(*)::integer
    from public.deletion_tombstones
    where purge_after > now()
  ),
  1,
  'future deletion tombstones remain'
);
select is(
  (
    select count(*)::integer
    from public.mutation_receipts
    where expires_at > now()
  ),
  1,
  'future mutation receipts remain'
);

set local role service_role;
select lives_ok(
  $test$select private.purge_expired_deletion_metadata()$test$,
  'repeated purge execution is safe'
);
reset role;

select is(
  (select count(*)::integer from public.account_deletion_audit),
  1,
  'repeated execution leaves the future audit row intact'
);
select is(
  (select count(*)::integer from public.deletion_tombstones),
  1,
  'repeated execution leaves the future tombstone intact'
);
select is(
  (select count(*)::integer from public.mutation_receipts),
  1,
  'repeated execution leaves the future receipt intact'
);

set local role anon;
select throws_ok(
  $test$select private.purge_expired_deletion_metadata()$test$,
  '42501',
  null,
  'anon invocation is rejected'
);
reset role;

set local role authenticated;
select throws_ok(
  $test$select private.purge_expired_deletion_metadata()$test$,
  '42501',
  null,
  'authenticated invocation is rejected'
);
reset role;

select * from finish();
rollback;
