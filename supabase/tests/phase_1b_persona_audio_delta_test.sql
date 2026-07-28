begin;

create extension if not exists pgtap with schema extensions;
select plan(17);

select has_table('public', 'persona_answer_aggregates', 'complete persona aggregate exists remotely');
select ok((select relrowsecurity from pg_class where oid = 'public.persona_answer_aggregates'::regclass), 'persona aggregate enables RLS');
select ok((select relforcerowsecurity from pg_class where oid = 'public.persona_answer_aggregates'::regclass), 'persona aggregate forces RLS');
select ok(to_regclass('public.personal_audio_clip_metadata') is null, 'no remote personal-audio metadata table exists');
select ok(to_regclass('storage.personal_audio') is null, 'no personal-audio bucket representation exists');
select ok(not exists (
  select 1 from pg_policies
  where schemaname in ('public', 'storage') and policyname ilike '%personal%audio%'
), 'no personal-audio policy exists');

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
    'delete', 1, 2,
    '{
      "id":"a4000000-0000-4000-8000-000000000004",
      "owner_user_id":"a1000000-0000-4000-8000-000000000001",
      "entity_type":"persona",
      "entity_id":"a3000000-0000-4000-8000-000000000003",
      "deleted_revision":2,
      "deleted_at":"2026-07-29T00:02:00Z"
    }'::jsonb
  )
  $test$,
  'persona deletion is tombstoned through the trusted mutation boundary'
);
select is((select count(*)::integer from public.persona_answer_aggregates), 0, 'persona deletion removes the aggregate');
select is((select count(*)::integer from public.deletion_tombstones where entity_type = 'persona'), 1, 'persona deletion records one tombstone');

select set_config('request.jwt.claim.sub', 'a2000000-0000-4000-8000-000000000002', true);
select results_eq($test$select count(*)::bigint from public.persona_answer_aggregates$test$, array[0::bigint], 'cross-user select is denied by RLS');

set local role anon;
select throws_ok($test$select * from public.persona_answer_aggregates$test$, '42501', null, 'anon cannot select persona rows');

select * from finish();
rollback;
