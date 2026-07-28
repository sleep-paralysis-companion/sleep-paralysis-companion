begin;

create extension if not exists pgtap with schema extensions;
select plan(57);

select has_table('public', 'persona_answer_aggregates', 'complete persona aggregate exists remotely');
select ok((select relrowsecurity from pg_class where oid = 'public.persona_answer_aggregates'::regclass), 'persona aggregate enables RLS');
select ok((select relforcerowsecurity from pg_class where oid = 'public.persona_answer_aggregates'::regclass), 'persona aggregate forces RLS');
select ok(to_regclass('public.personal_audio_clip_metadata') is null, 'no remote personal-audio metadata table exists');
select ok(not exists (select 1 from storage.buckets where id ilike '%personal%audio%'), 'no personal-audio Storage bucket row exists');
select ok(not exists (select 1 from storage.objects where bucket_id ilike '%personal%audio%' or name ilike '%personal%audio%'), 'no personal-audio Storage object/reference exists');
select ok(not exists (select 1 from pg_policies where schemaname = 'storage' and tablename in ('buckets', 'objects') and policyname ilike '%personal%audio%'), 'no personal-audio Storage policy exists');
select ok(not exists (select 1 from information_schema.columns where table_schema = 'public' and column_name ilike '%audio%' and table_name not in ('audio_catalog')), 'no remote personal-audio columns exist');

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at
) values
  ('00000000-0000-0000-0000-000000000000', 'a1000000-0000-4000-8000-000000000001', 'authenticated', 'authenticated', 'persona-owner@example.invalid', '', now(), now(), now()),
  ('00000000-0000-0000-0000-000000000000', 'a2000000-0000-4000-8000-000000000002', 'authenticated', 'authenticated', 'persona-other@example.invalid', '', now(), now(), now());

set local role authenticated;
select set_config('request.jwt.claim.sub', 'a1000000-0000-4000-8000-000000000001', true);
select set_config('request.jwt.claim.role', 'authenticated', true);

select lives_ok(
  $test$
  select * from public.apply_sync_mutation(
    'b1000000-0000-4000-8000-000000000001',
    'b2000000-0000-4000-8000-000000000002',
    'persona',
    'a3000000-0000-4000-8000-000000000003',
    'upsert', 0, 1,
    '{
      "id":"a3000000-0000-4000-8000-000000000003",
      "owner_user_id":"a1000000-0000-4000-8000-000000000001",
      "episode_frequency":"weekly",
      "post_episode_feeling":"awake_scared",
      "calming_person_context":"alone",
      "routing_rule_version":"2026-07-29-v1",
      "calculated_at":"2026-07-29T00:00:00Z",
      "updated_at":"2026-07-29T00:00:00Z",
      "revision":1
    }'::jsonb
  )
  $test$,
  'owner can create a complete persona through the trusted mutation boundary'
);

select results_eq(
  $test$select derived_persona from public.persona_answer_aggregates$test$,
  array['frequent_intense_no_calming_person'::text],
  'database derives the persona and does not accept it as a payload authority'
);

select throws_ok(
  $test$
  insert into public.persona_answer_aggregates (
    id, owner_user_id, episode_frequency, post_episode_feeling, calming_person_context,
    routing_rule_version, calculated_at, updated_at, revision
  ) values (
    'a5000000-0000-4000-8000-000000000005', 'a1000000-0000-4000-8000-000000000001',
    'weekly', 'awake_scared', 'alone', '2026-07-29-v1', now(), now(), 1
  )
  $test$, '42501', null, 'direct persona INSERT cannot bypass receipts'
);
select throws_ok($test$update public.persona_answer_aggregates set revision = 2 where id = 'a3000000-0000-4000-8000-000000000003'$test$, '42501', null, 'direct persona UPDATE cannot bypass receipts');
select throws_ok($test$delete from public.persona_answer_aggregates where id = 'a3000000-0000-4000-8000-000000000003'$test$, '42501', null, 'direct persona DELETE cannot bypass tombstones');

select set_config('request.jwt.claim.sub', 'a2000000-0000-4000-8000-000000000002', true);
select is((select count(*)::integer from public.persona_answer_aggregates), 0, 'cross-user SELECT hides an existing owner persona row');
select throws_ok($test$update public.persona_answer_aggregates set revision = 2 where id = 'a3000000-0000-4000-8000-000000000003'$test$, '42501', null, 'cross-user UPDATE is denied');
select throws_ok($test$delete from public.persona_answer_aggregates where id = 'a3000000-0000-4000-8000-000000000003'$test$, '42501', null, 'cross-user DELETE is denied');
select set_config('request.jwt.claim.sub', 'a1000000-0000-4000-8000-000000000001', true);

select throws_ok(
  $test$
  select * from public.apply_sync_mutation(
    'b3000000-0000-4000-8000-000000000003',
    'b4000000-0000-4000-8000-000000000004',
    'persona',
    'a3000000-0000-4000-8000-000000000003',
    'upsert', 1, 2,
    '{
      "id":"a3000000-0000-4000-8000-000000000003",
      "owner_user_id":"a1000000-0000-4000-8000-000000000001",
      "episode_frequency":"weekly",
      "post_episode_feeling":"awake_scared",
      "calming_person_context":"alone",
      "derived_persona":"general_default",
      "routing_rule_version":"2026-07-29-v1",
      "calculated_at":"2026-07-29T00:01:00Z",
      "updated_at":"2026-07-29T00:01:00Z",
      "revision":2
    }'::jsonb
  )
  $test$,
  '22023',
  'malformed persona payload',
  'client-forged persona is rejected before receipt insertion'
);

select is((select count(*)::integer from public.mutation_receipts where idempotency_key = 'b4000000-0000-4000-8000-000000000004'), 0, 'forged persona leaves no receipt');

select throws_ok(
  $test$
  select * from public.apply_sync_mutation(
    'c1000000-0000-4000-8000-000000000001', 'c2000000-0000-4000-8000-000000000002', 'persona',
    'a3000000-0000-4000-8000-000000000003', 'upsert', 1, 2,
    '{"id":"a3000000-0000-4000-8000-000000000003","owner_user_id":"a2000000-0000-4000-8000-000000000002","episode_frequency":"weekly","post_episode_feeling":"awake_scared","calming_person_context":"alone","routing_rule_version":"2026-07-29-v1","calculated_at":"2026-07-29T00:01:00Z","updated_at":"2026-07-29T00:01:00Z","revision":2}'::jsonb
  )
  $test$, '42501', null, 'forged owner_user_id is rejected by the trusted boundary'
);
select is((select count(*)::integer from public.mutation_receipts where idempotency_key = 'c2000000-0000-4000-8000-000000000002'), 0, 'forged owner leaves no receipt');

select throws_ok(
  $test$
  select * from public.apply_sync_mutation(
    'c3000000-0000-4000-8000-000000000003', 'c4000000-0000-4000-8000-000000000004', 'persona',
    'a3000000-0000-4000-8000-000000000003', 'upsert', 1, 2,
    '{"id":"a3000000-0000-4000-8000-000000000003","owner_user_id":"a1000000-0000-4000-8000-000000000001","episode_frequency":"future","post_episode_feeling":"awake_scared","calming_person_context":"alone","routing_rule_version":"2026-07-29-v1","calculated_at":"2026-07-29T00:01:00Z","updated_at":"2026-07-29T00:01:00Z","revision":2}'::jsonb
  )
  $test$, '22023', null, 'invalid episode_frequency is rejected'
);
select is((select count(*)::integer from public.mutation_receipts where idempotency_key = 'c4000000-0000-4000-8000-000000000004'), 0, 'invalid episode_frequency leaves no receipt');

select throws_ok(
  $test$
  select * from public.apply_sync_mutation(
    'c5000000-0000-4000-8000-000000000005', 'c6000000-0000-4000-8000-000000000006', 'persona',
    'a3000000-0000-4000-8000-000000000003', 'upsert', 1, 2,
    '{"id":"a3000000-0000-4000-8000-000000000003","owner_user_id":"a1000000-0000-4000-8000-000000000001","episode_frequency":"weekly","post_episode_feeling":"future","calming_person_context":"alone","routing_rule_version":"2026-07-29-v1","calculated_at":"2026-07-29T00:01:00Z","updated_at":"2026-07-29T00:01:00Z","revision":2}'::jsonb
  )
  $test$, '22023', null, 'invalid post_episode_feeling is rejected'
);
select is((select count(*)::integer from public.mutation_receipts where idempotency_key = 'c6000000-0000-4000-8000-000000000006'), 0, 'invalid post_episode_feeling leaves no receipt');

select throws_ok(
  $test$
  select * from public.apply_sync_mutation(
    'c7000000-0000-4000-8000-000000000007', 'c8000000-0000-4000-8000-000000000008', 'persona',
    'a3000000-0000-4000-8000-000000000003', 'upsert', 1, 2,
    '{"id":"a3000000-0000-4000-8000-000000000003","owner_user_id":"a1000000-0000-4000-8000-000000000001","episode_frequency":"weekly","post_episode_feeling":"awake_scared","calming_person_context":"future","routing_rule_version":"2026-07-29-v1","calculated_at":"2026-07-29T00:01:00Z","updated_at":"2026-07-29T00:01:00Z","revision":2}'::jsonb
  )
  $test$, '22023', null, 'invalid calming_person_context is rejected'
);
select is((select count(*)::integer from public.mutation_receipts where idempotency_key = 'c8000000-0000-4000-8000-000000000008'), 0, 'invalid calming_person_context leaves no receipt');

select throws_ok(
  $test$
  select * from public.apply_sync_mutation(
    'c9000000-0000-4000-8000-000000000009', 'ca000000-0000-4000-8000-00000000000a', 'persona',
    'a3000000-0000-4000-8000-000000000003', 'upsert', 1, 2,
    '{"id":"a3000000-0000-4000-8000-000000000003","owner_user_id":"a1000000-0000-4000-8000-000000000001","episode_frequency":"weekly","post_episode_feeling":"awake_scared","calming_person_context":"alone","routing_rule_version":"future","calculated_at":"2026-07-29T00:01:00Z","updated_at":"2026-07-29T00:01:00Z","revision":2}'::jsonb
  )
  $test$, '22023', null, 'invalid routing_rule_version is rejected'
);
select is((select count(*)::integer from public.mutation_receipts where idempotency_key = 'ca000000-0000-4000-8000-00000000000a'), 0, 'invalid routing version leaves no receipt');

select throws_ok(
  $test$
  select * from public.apply_sync_mutation(
    'cb000000-0000-4000-8000-00000000000b', 'cc000000-0000-4000-8000-00000000000c', 'persona',
    'a3000000-0000-4000-8000-000000000003', 'upsert', 1, 2,
    '{"id":"a3000000-0000-4000-8000-000000000003","owner_user_id":"a1000000-0000-4000-8000-000000000001","episode_frequency":"weekly","post_episode_feeling":"awake_scared","routing_rule_version":"2026-07-29-v1","calculated_at":"2026-07-29T00:01:00Z","updated_at":"2026-07-29T00:01:00Z","revision":2}'::jsonb
  )
  $test$, '22023', null, 'incomplete persona payload is rejected'
);
select is((select count(*)::integer from public.mutation_receipts where idempotency_key = 'cc000000-0000-4000-8000-00000000000c'), 0, 'incomplete payload leaves no receipt');

select throws_ok(
  $test$
  select * from public.apply_sync_mutation(
    'cd000000-0000-4000-8000-00000000000d', 'ce000000-0000-4000-8000-00000000000e', 'persona',
    'a3000000-0000-4000-8000-000000000003', 'upsert', 0, 1,
    '{"id":"a3000000-0000-4000-8000-000000000003","owner_user_id":"a1000000-0000-4000-8000-000000000001","episode_frequency":"weekly","post_episode_feeling":"awake_scared","calming_person_context":"alone","routing_rule_version":"2026-07-29-v1","calculated_at":"2026-07-29T00:01:00Z","updated_at":"2026-07-29T00:01:00Z","revision":1}'::jsonb
  )
  $test$, '40001', null, 'stale persona base/entity revision conflicts'
);
select is((select count(*)::integer from public.mutation_receipts where idempotency_key = 'ce000000-0000-4000-8000-00000000000e'), 0, 'revision conflict leaves no receipt');

select throws_ok(
  $test$
  select * from public.apply_sync_mutation(
    'b3100000-0000-4000-8000-000000000003', 'b2000000-0000-4000-8000-000000000002', 'persona',
    'a3000000-0000-4000-8000-000000000003', 'upsert', 0, 1,
    '{"id":"a3000000-0000-4000-8000-000000000003","owner_user_id":"a1000000-0000-4000-8000-000000000001","episode_frequency":"monthly","post_episode_feeling":"awake_scared","calming_person_context":"alone","routing_rule_version":"2026-07-29-v1","calculated_at":"2026-07-29T00:00:00Z","updated_at":"2026-07-29T00:00:00Z","revision":1}'::jsonb
  )
  $test$, '23505', null, 'changed payload replay is denied'
);
select throws_ok(
  $test$
  select * from public.apply_sync_mutation(
    'b3200000-0000-4000-8000-000000000003', 'b2000000-0000-4000-8000-000000000002', 'persona',
    'a3000000-0000-4000-8000-000000000003', 'delete', 0, 1,
    '{"id":"a3000000-0000-4000-8000-000000000003","owner_user_id":"a1000000-0000-4000-8000-000000000001","episode_frequency":"weekly","post_episode_feeling":"awake_scared","calming_person_context":"alone","routing_rule_version":"2026-07-29-v1","calculated_at":"2026-07-29T00:00:00Z","updated_at":"2026-07-29T00:00:00Z","revision":1}'::jsonb
  )
  $test$, '22023', null, 'changed operation replay is denied'
);

select lives_ok(
  $test$
  select * from public.apply_sync_mutation(
    'b3300000-0000-4000-8000-000000000003', 'b3400000-0000-4000-8000-000000000004', 'persona',
    'a3000000-0000-4000-8000-000000000003', 'upsert', 1, 2,
    '{"id":"a3000000-0000-4000-8000-000000000003","owner_user_id":"a1000000-0000-4000-8000-000000000001","episode_frequency":"monthly","post_episode_feeling":"shake_it_off","calming_person_context":"beside_me","routing_rule_version":"2026-07-29-v1","calculated_at":"2026-07-29T00:01:00Z","updated_at":"2026-07-29T00:01:00Z","revision":2}'::jsonb
  )
  $test$, 'trusted boundary updates persona exactly once'
);
select is((select revision from public.persona_answer_aggregates where id = 'a3000000-0000-4000-8000-000000000003'), 2::bigint, 'trusted update advances revision exactly once');

select throws_ok(
  $test$
  select * from public.apply_sync_mutation(
    'b5000000-0000-4000-8000-000000000005',
    'b6000000-0000-4000-8000-000000000006',
    'audio',
    'a3000000-0000-4000-8000-000000000003',
    'upsert', 0, 1,
    '{"id":"a3000000-0000-4000-8000-000000000003","owner_user_id":"a1000000-0000-4000-8000-000000000001","revision":1}'::jsonb
  )
  $test$,
  '22023',
  null,
  'audio mutations are rejected'
);
select is((select count(*)::integer from public.mutation_receipts where idempotency_key = 'b6000000-0000-4000-8000-000000000006'), 0, 'audio rejection leaves no receipt');

select lives_ok(
  $test$
  select * from public.apply_sync_mutation(
    'b7000000-0000-4000-8000-000000000007',
    'b8000000-0000-4000-8000-000000000008',
    'tombstone',
    'a4000000-0000-4000-8000-000000000004',
    'delete', 2, 3,
    '{
      "id":"a4000000-0000-4000-8000-000000000004",
      "owner_user_id":"a1000000-0000-4000-8000-000000000001",
      "entity_type":"persona",
      "entity_id":"a3000000-0000-4000-8000-000000000003",
      "deleted_revision":3,
      "deleted_at":"2026-07-29T00:02:00Z"
    }'::jsonb
  )
  $test$,
  'persona deletion is tombstoned through the trusted mutation boundary'
);
select is((select count(*)::integer from public.persona_answer_aggregates where owner_user_id = 'a1000000-0000-4000-8000-000000000001'), 0, 'persona deletion removes the first owner aggregate');
select is((select count(*)::integer from public.deletion_tombstones where owner_user_id = 'a1000000-0000-4000-8000-000000000001' and entity_type = 'persona'), 1, 'persona deletion records one first-owner tombstone');

select lives_ok(
  $test$
  select * from public.apply_sync_mutation(
    'b7000000-0000-4000-8000-000000000007', 'b8000000-0000-4000-8000-000000000008', 'tombstone',
    'a4000000-0000-4000-8000-000000000004', 'delete', 2, 3,
    '{"id":"a4000000-0000-4000-8000-000000000004","owner_user_id":"a1000000-0000-4000-8000-000000000001","entity_type":"persona","entity_id":"a3000000-0000-4000-8000-000000000003","deleted_revision":3,"deleted_at":"2026-07-29T00:02:00Z"}'::jsonb
  )
  $test$, 'identical tombstone retry is idempotent'
);
select throws_ok(
  $test$
  select * from public.apply_sync_mutation(
    'b9000000-0000-4000-8000-000000000009', 'ba000000-0000-4000-8000-00000000000a', 'persona',
    'a3000000-0000-4000-8000-000000000003', 'upsert', 3, 4,
    '{"id":"a3000000-0000-4000-8000-000000000003","owner_user_id":"a1000000-0000-4000-8000-000000000001","episode_frequency":"weekly","post_episode_feeling":"awake_scared","calming_person_context":"alone","routing_rule_version":"2026-07-29-v1","calculated_at":"2026-07-29T00:03:00Z","updated_at":"2026-07-29T00:03:00Z","revision":4}'::jsonb
  )
  $test$, '23514', null, 'tombstone prevents stale persona resurrection'
);

select ok(
  has_function_privilege(
    'authenticated',
    to_regprocedure('public.apply_sync_mutation(uuid,uuid,text,uuid,text,bigint,bigint,jsonb)'),
    'EXECUTE'
  ),
  'authenticated can invoke the public mutation wrapper'
);
select ok(
  not has_function_privilege(
    'anon',
    to_regprocedure('public.apply_sync_mutation(uuid,uuid,text,uuid,text,bigint,bigint,jsonb)'),
    'EXECUTE'
  ),
  'anon cannot invoke the public mutation wrapper'
);
select ok(
  not exists (
    select 1
    from pg_proc procedure
    join pg_namespace namespace on namespace.oid = procedure.pronamespace
    cross join lateral aclexplode(coalesce(procedure.proacl, acldefault('f', procedure.proowner))) privilege
    where namespace.nspname = 'public'
      and procedure.proname = 'apply_sync_mutation'
      and privilege.grantee = 0
      and privilege.privilege_type = 'EXECUTE'
  ),
  'PUBLIC execution is revoked from the public mutation wrapper'
);
select ok(
  to_regprocedure('public.apply_sync_mutation_trusted(uuid,uuid,text,uuid,text,bigint,bigint,jsonb)') is null,
  'private trusted mutation function is not exposed through the public API schema'
);
select ok(
  to_regprocedure('private.apply_sync_mutation_legacy(uuid,uuid,text,uuid,text,bigint,bigint,jsonb)') is not null,
  'legacy mutation implementation remains present for supported legacy entities'
);
select lives_ok(
  $test$
  select * from public.apply_sync_mutation(
    'd1000000-0000-4000-8000-000000000001', 'd2000000-0000-4000-8000-000000000002', 'profile',
    'd3000000-0000-4000-8000-000000000003', 'upsert', 0, 1,
    '{"id":"d3000000-0000-4000-8000-000000000003","owner_user_id":"a1000000-0000-4000-8000-000000000001","profile_created_at":"2026-07-29T00:00:00Z","revision":1}'::jsonb
  )
  $test$, 'legacy profile mutation remains compatible through the checked definer chain'
);

set local role anon;
select throws_ok(
  $test$
  select * from public.apply_sync_mutation(
    'cf000000-0000-4000-8000-00000000000f', 'd0000000-0000-4000-8000-000000000010', 'persona',
    'a3000000-0000-4000-8000-000000000003', 'upsert', 0, 1, '{}'::jsonb
  )
  $test$, '42501', null, 'anon execution of the public wrapper is denied'
);
set local role authenticated;

select set_config('request.jwt.claim.sub', 'a2000000-0000-4000-8000-000000000002', true);
select lives_ok(
  $test$
  select * from public.apply_sync_mutation(
    'e1000000-0000-4000-8000-000000000001', 'e2000000-0000-4000-8000-000000000002', 'persona',
    'e3000000-0000-4000-8000-000000000003', 'upsert', 0, 1,
    '{"id":"e3000000-0000-4000-8000-000000000003","owner_user_id":"a2000000-0000-4000-8000-000000000002","episode_frequency":"weekly","post_episode_feeling":"awake_scared","calming_person_context":"beside_me","routing_rule_version":"2026-07-29-v1","calculated_at":"2026-07-29T00:04:00Z","updated_at":"2026-07-29T00:04:00Z","revision":1}'::jsonb
  )
  $test$, 'cascade-test owner can create a live persona through the public mutation boundary'
);
select is(
  (select count(*)::integer from public.persona_answer_aggregates where owner_user_id = 'a2000000-0000-4000-8000-000000000002'),
  1,
  'cascade-test owner has one live persona immediately before account deletion'
);
select is(
  (select count(*)::integer from public.mutation_receipts where owner_user_id = 'a2000000-0000-4000-8000-000000000002'),
  1,
  'cascade-test owner has the corresponding mutation receipt before account deletion'
);

reset role;
delete from auth.users where id = 'a2000000-0000-4000-8000-000000000002';
select is((select count(*)::integer from public.persona_answer_aggregates where owner_user_id = 'a2000000-0000-4000-8000-000000000002'), 0, 'account deletion cascades the live cascade-test persona');
select is((select count(*)::integer from public.mutation_receipts where owner_user_id = 'a2000000-0000-4000-8000-000000000002'), 0, 'account deletion cascades the cascade-test mutation receipt');
select is((select count(*)::integer from public.deletion_tombstones where owner_user_id = 'a1000000-0000-4000-8000-000000000001' and entity_type = 'persona'), 1, 'account deletion preserves the first owner tombstone evidence');

set local role anon;
select throws_ok($test$select * from public.persona_answer_aggregates$test$, '42501', null, 'anon cannot select persona rows');

select * from finish();
rollback;
