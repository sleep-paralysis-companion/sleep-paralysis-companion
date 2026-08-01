begin;

create extension if not exists pgtap with schema extensions;
select plan(34);

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
    '10101010-1010-4010-8010-101010101010',
    'authenticated',
    'authenticated',
    'mutation-owner-one@example.invalid',
    '',
    now(),
    now(),
    now()
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '20202020-2020-4020-8020-202020202020',
    'authenticated',
    'authenticated',
    'mutation-owner-two@example.invalid',
    '',
    now(),
    now(),
    now()
  );

set local role authenticated;
select set_config('request.jwt.claim.sub', '10101010-1010-4010-8010-101010101010', true);
select set_config('request.jwt.claim.role', 'authenticated', true);

select lives_ok(
  $test$
  select * from public.apply_sync_mutation(
    '30000000-0000-4000-8000-000000000001',
    '40000000-0000-4000-8000-000000000001',
    'profile',
    '50000000-0000-4000-8000-000000000001',
    'upsert',
    0,
    1,
    '{
      "id":"50000000-0000-4000-8000-000000000001",
      "owner_user_id":"10101010-1010-4010-8010-101010101010",
      "profile_created_at":"2026-07-28T00:00:00Z",
      "revision":1
    }'::jsonb
  )
  $test$,
  'upsert accepts profile payloads'
);

select lives_ok(
  $test$
  select * from public.apply_sync_mutation(
    '30000000-0000-4000-8000-000000000002',
    '40000000-0000-4000-8000-000000000002',
    'settings',
    '50000000-0000-4000-8000-000000000001',
    'upsert',
    0,
    1,
    '{
      "id":"50000000-0000-4000-8000-000000000001",
      "owner_user_id":"10101010-1010-4010-8010-101010101010",
      "preferred_grounding_asset_id":null,
      "preferred_modality":"silent",
      "haptics_enabled":false,
      "revision":1
    }'::jsonb
  )
  $test$,
  'upsert accepts settings payloads'
);

select lives_ok(
  $test$
  select * from public.apply_sync_mutation(
    '30000000-0000-4000-8000-000000000003',
    '40000000-0000-4000-8000-000000000003',
    'alarm',
    '50000000-0000-4000-8000-000000000003',
    'upsert',
    0,
    1,
    '{
      "id":"50000000-0000-4000-8000-000000000003",
      "owner_user_id":"10101010-1010-4010-8010-101010101010",
      "local_hour":22,
      "local_minute":30,
      "weekdays_mask":62,
      "snooze_minutes":10,
      "enabled_intent":true,
      "revision":1
    }'::jsonb
  )
  $test$,
  'upsert accepts alarm payloads'
);

select lives_ok(
  $test$
  select * from public.apply_sync_mutation(
    '30000000-0000-4000-8000-000000000004',
    '40000000-0000-4000-8000-000000000004',
    'checkin',
    '50000000-0000-4000-8000-000000000004',
    'upsert',
    0,
    1,
    '{
      "id":"50000000-0000-4000-8000-000000000004",
      "owner_user_id":"10101010-1010-4010-8010-101010101010",
      "reported_for_local_date":"2026-07-28",
      "reported_timezone_id":"UTC",
      "occurrence":"no",
      "perceived_intensity":null,
      "present_state":null,
      "note":null,
      "created_at":"2026-07-28T00:00:00Z",
      "updated_at":"2026-07-28T00:00:00Z",
      "revision":1,
      "deleted_at":null
    }'::jsonb
  )
  $test$,
  'upsert accepts check-in payloads'
);

select set_config('request.jwt.claim.sub', '20202020-2020-4020-8020-202020202020', true);

select lives_ok(
  $test$
  select * from public.apply_sync_mutation(
    '60000000-0000-4000-8000-000000000001',
    '70000000-0000-4000-8000-000000000001',
    'profile',
    '80000000-0000-4000-8000-000000000001',
    'convert',
    0,
    1,
    '{
      "id":"80000000-0000-4000-8000-000000000001",
      "owner_user_id":"20202020-2020-4020-8020-202020202020",
      "profile_created_at":"2026-07-28T00:00:00Z",
      "revision":1
    }'::jsonb
  )
  $test$,
  'convert accepts profile payloads'
);

select lives_ok(
  $test$
  select * from public.apply_sync_mutation(
    '60000000-0000-4000-8000-000000000002',
    '70000000-0000-4000-8000-000000000002',
    'settings',
    '80000000-0000-4000-8000-000000000001',
    'convert',
    0,
    1,
    '{
      "id":"80000000-0000-4000-8000-000000000001",
      "owner_user_id":"20202020-2020-4020-8020-202020202020",
      "preferred_grounding_asset_id":null,
      "preferred_modality":"visual",
      "haptics_enabled":true,
      "revision":1
    }'::jsonb
  )
  $test$,
  'convert accepts settings payloads'
);

select lives_ok(
  $test$
  select * from public.apply_sync_mutation(
    '60000000-0000-4000-8000-000000000003',
    '70000000-0000-4000-8000-000000000003',
    'alarm',
    '80000000-0000-4000-8000-000000000003',
    'convert',
    0,
    1,
    '{
      "id":"80000000-0000-4000-8000-000000000003",
      "owner_user_id":"20202020-2020-4020-8020-202020202020",
      "local_hour":7,
      "local_minute":15,
      "weekdays_mask":127,
      "snooze_minutes":null,
      "enabled_intent":false,
      "revision":1
    }'::jsonb
  )
  $test$,
  'convert accepts alarm payloads'
);

select lives_ok(
  $test$
  select * from public.apply_sync_mutation(
    '60000000-0000-4000-8000-000000000004',
    '70000000-0000-4000-8000-000000000004',
    'checkin',
    '80000000-0000-4000-8000-000000000004',
    'convert',
    0,
    1,
    '{
      "id":"80000000-0000-4000-8000-000000000004",
      "owner_user_id":"20202020-2020-4020-8020-202020202020",
      "reported_for_local_date":"2026-07-27",
      "reported_timezone_id":"UTC",
      "occurrence":"yes",
      "perceived_intensity":"mild",
      "present_state":"fine_now",
      "note":null,
      "created_at":"2026-07-27T00:00:00Z",
      "updated_at":"2026-07-27T00:00:00Z",
      "revision":1,
      "deleted_at":null
    }'::jsonb
  )
  $test$,
  'convert accepts check-in payloads'
);

select set_config('request.jwt.claim.sub', '10101010-1010-4010-8010-101010101010', true);

select lives_ok(
  $test$
  select * from public.apply_sync_mutation(
    '90000000-0000-4000-8000-000000000001',
    '91000000-0000-4000-8000-000000000001',
    'tombstone',
    '92000000-0000-4000-8000-000000000001',
    'delete',
    1,
    2,
    '{
      "id":"92000000-0000-4000-8000-000000000001",
      "owner_user_id":"10101010-1010-4010-8010-101010101010",
      "entity_type":"checkin",
      "entity_id":"50000000-0000-4000-8000-000000000004",
      "deleted_revision":2,
      "deleted_at":"2026-07-28T01:00:00Z"
    }'::jsonb
  )
  $test$,
  'delete accepts a tombstone payload'
);

select throws_ok(
  $test$
  select * from public.apply_sync_mutation(
    'a0000000-0000-4000-8000-000000000001',
    'a1000000-0000-4000-8000-000000000001',
    'tombstone',
    'a2000000-0000-4000-8000-000000000001',
    'upsert',
    0,
    1,
    '{}'::jsonb
  )
  $test$,
  '22023',
  'incompatible operation and entity type',
  'upsert rejects tombstone entities'
);

select throws_ok(
  $test$
  select * from public.apply_sync_mutation(
    'a0000000-0000-4000-8000-000000000002',
    'a1000000-0000-4000-8000-000000000002',
    'tombstone',
    'a2000000-0000-4000-8000-000000000002',
    'convert',
    0,
    1,
    '{}'::jsonb
  )
  $test$,
  '22023',
  'incompatible operation and entity type',
  'convert rejects tombstone entities'
);

select throws_ok(
  $test$
  select * from public.apply_sync_mutation(
    'a0000000-0000-4000-8000-000000000003',
    'a1000000-0000-4000-8000-000000000003',
    'profile',
    'a2000000-0000-4000-8000-000000000003',
    'delete',
    0,
    1,
    '{}'::jsonb
  )
  $test$,
  '22023',
  'incompatible operation and entity type',
  'delete rejects profile entities'
);

select throws_ok(
  $test$
  select * from public.apply_sync_mutation(
    'a0000000-0000-4000-8000-000000000004',
    'a1000000-0000-4000-8000-000000000004',
    'settings',
    'a2000000-0000-4000-8000-000000000004',
    'delete',
    0,
    1,
    '{}'::jsonb
  )
  $test$,
  '22023',
  'incompatible operation and entity type',
  'delete rejects settings entities'
);

select throws_ok(
  $test$
  select * from public.apply_sync_mutation(
    'a0000000-0000-4000-8000-000000000005',
    'a1000000-0000-4000-8000-000000000005',
    'alarm',
    'a2000000-0000-4000-8000-000000000005',
    'delete',
    0,
    1,
    '{}'::jsonb
  )
  $test$,
  '22023',
  'incompatible operation and entity type',
  'delete rejects alarm entities'
);

select throws_ok(
  $test$
  select * from public.apply_sync_mutation(
    'a0000000-0000-4000-8000-000000000006',
    'a1000000-0000-4000-8000-000000000006',
    'checkin',
    'a2000000-0000-4000-8000-000000000006',
    'delete',
    0,
    1,
    '{}'::jsonb
  )
  $test$,
  '22023',
  'incompatible operation and entity type',
  'delete rejects check-in entities'
);

select throws_ok(
  $test$
  select * from public.apply_sync_mutation(
    'b0000000-0000-4000-8000-000000000001',
    'b1000000-0000-4000-8000-000000000001',
    'tombstone',
    'b2000000-0000-4000-8000-000000000001',
    'delete',
    1,
    2,
    '{
      "id":"b2000000-0000-4000-8000-000000000001",
      "owner_user_id":"10101010-1010-4010-8010-101010101010",
      "entity_type":"checkin",
      "deleted_revision":2,
      "deleted_at":"2026-07-28T01:00:00Z"
    }'::jsonb
  )
  $test$,
  '22023',
  'malformed tombstone payload',
  'tombstones require a target entity ID'
);

select throws_ok(
  $test$
  select * from public.apply_sync_mutation(
    'b0000000-0000-4000-8000-000000000002',
    'b1000000-0000-4000-8000-000000000002',
    'tombstone',
    'b2000000-0000-4000-8000-000000000002',
    'delete',
    1,
    2,
    '{
      "id":"b2000000-0000-4000-8000-000000000002",
      "owner_user_id":"10101010-1010-4010-8010-101010101010",
      "entity_type":"profile",
      "entity_id":"50000000-0000-4000-8000-000000000004",
      "deleted_revision":2,
      "deleted_at":"2026-07-28T01:00:00Z"
    }'::jsonb
  )
  $test$,
  '22023',
  'malformed tombstone payload',
  'Phase 1B tombstones target submitted check-ins only'
);

select throws_ok(
  $test$
  select * from public.apply_sync_mutation(
    'b0000000-0000-4000-8000-000000000003',
    'b1000000-0000-4000-8000-000000000003',
    'tombstone',
    'b2000000-0000-4000-8000-000000000003',
    'delete',
    1,
    2,
    '{
      "id":"b2000000-0000-4000-8000-000000000003",
      "owner_user_id":"10101010-1010-4010-8010-101010101010",
      "entity_type":"checkin",
      "entity_id":"50000000-0000-4000-8000-000000000004",
      "deleted_revision":3,
      "deleted_at":"2026-07-28T01:00:00Z"
    }'::jsonb
  )
  $test$,
  '22023',
  'malformed tombstone payload',
  'tombstone revision must match the mutation revision'
);

select throws_ok(
  $test$
  select * from public.apply_sync_mutation(
    'b0000000-0000-4000-8000-000000000004',
    'b1000000-0000-4000-8000-000000000004',
    'tombstone',
    'b2000000-0000-4000-8000-000000000004',
    'delete',
    1,
    2,
    '{
      "id":"b2000000-0000-4000-8000-000000000004",
      "owner_user_id":"10101010-1010-4010-8010-101010101010",
      "entity_type":"checkin",
      "entity_id":"50000000-0000-4000-8000-000000000004",
      "deleted_revision":2,
      "deleted_at":"2026-07-28T01:00:00Z",
      "acknowledged_at":"2026-07-28T01:00:01Z"
    }'::jsonb
  )
  $test$,
  '22023',
  'malformed tombstone payload',
  'clients cannot set tombstone acknowledgment fields'
);

select throws_ok(
  $test$
  select * from public.apply_sync_mutation(
    'c0000000-0000-4000-8000-000000000001',
    '40000000-0000-4000-8000-000000000002',
    'settings',
    '50000000-0000-4000-8000-000000000001',
    'convert',
    0,
    1,
    '{
      "id":"50000000-0000-4000-8000-000000000001",
      "owner_user_id":"10101010-1010-4010-8010-101010101010",
      "preferred_grounding_asset_id":null,
      "preferred_modality":"silent",
      "haptics_enabled":false,
      "revision":1
    }'::jsonb
  )
  $test$,
  '23505',
  'idempotency key payload mismatch',
  'replay cannot change the operation'
);

select throws_ok(
  $test$
  select * from public.apply_sync_mutation(
    'c0000000-0000-4000-8000-000000000002',
    '40000000-0000-4000-8000-000000000002',
    'settings',
    '50000000-0000-4000-8000-000000000001',
    'upsert',
    0,
    1,
    '{
      "id":"50000000-0000-4000-8000-000000000001",
      "owner_user_id":"10101010-1010-4010-8010-101010101010",
      "preferred_grounding_asset_id":null,
      "preferred_modality":"audio",
      "haptics_enabled":false,
      "revision":1
    }'::jsonb
  )
  $test$,
  '23505',
  'idempotency key payload mismatch',
  'replay cannot change the payload'
);

select results_eq(
  $test$
  select accepted_revision from public.apply_sync_mutation(
    'c0000000-0000-4000-8000-000000000003',
    '40000000-0000-4000-8000-000000000002',
    'settings',
    '50000000-0000-4000-8000-000000000001',
    'upsert',
    0,
    1,
    '{
      "id":"50000000-0000-4000-8000-000000000001",
      "owner_user_id":"10101010-1010-4010-8010-101010101010",
      "preferred_grounding_asset_id":null,
      "preferred_modality":"silent",
      "haptics_enabled":false,
      "revision":1
    }'::jsonb
  )
  $test$,
  array[1::bigint],
  'an exact replay returns its original acknowledgment'
);

select is(
  (
    select count(*)::integer
    from public.mutation_receipts
    where idempotency_key = '40000000-0000-4000-8000-000000000002'
  ),
  1,
  'changed and exact replays leave one receipt'
);

select throws_ok(
  $test$
  select * from public.apply_sync_mutation(
    'd0000000-0000-4000-8000-000000000001',
    'd1000000-0000-4000-8000-000000000001',
    'checkin',
    'd2000000-0000-4000-8000-000000000001',
    'upsert',
    0,
    1,
    jsonb_build_object(
      'id', 'd2000000-0000-4000-8000-000000000001',
      'owner_user_id', '10101010-1010-4010-8010-101010101010',
      'reported_for_local_date', '2026-07-26',
      'reported_timezone_id', 'UTC',
      'occurrence', 'yes',
      'perceived_intensity', 'mild',
      'present_state', 'fine_now',
      'note', repeat('x', 501),
      'created_at', '2026-07-26T00:00:00Z',
      'updated_at', '2026-07-26T00:00:00Z',
      'revision', 1,
      'deleted_at', null
    )
  )
  $test$,
  '23514',
  null,
  'entity constraint failure rolls the mutation back'
);

select is(
  (
    select count(*)::integer
    from public.mutation_receipts
    where idempotency_key = 'd1000000-0000-4000-8000-000000000001'
  ),
  0,
  'entity failure leaves no receipt'
);

select results_eq(
  $test$
  select accepted_revision from public.apply_sync_mutation(
    'e0000000-0000-4000-8000-000000000001',
    '91000000-0000-4000-8000-000000000001',
    'tombstone',
    '92000000-0000-4000-8000-000000000001',
    'delete',
    1,
    2,
    '{
      "id":"92000000-0000-4000-8000-000000000001",
      "owner_user_id":"10101010-1010-4010-8010-101010101010",
      "entity_type":"checkin",
      "entity_id":"50000000-0000-4000-8000-000000000004",
      "deleted_revision":2,
      "deleted_at":"2026-07-28T01:00:00Z"
    }'::jsonb
  )
  $test$,
  array[2::bigint],
  'deletion retry returns the committed acknowledgment'
);

select is(
  (
    select count(*)::integer
    from public.mutation_receipts
    where idempotency_key = '91000000-0000-4000-8000-000000000001'
  ),
  1,
  'deletion retry leaves one receipt'
);

select is(
  (
    select count(*)::integer
    from public.deletion_tombstones
    where id = '92000000-0000-4000-8000-000000000001'
  ),
  1,
  'deletion retry leaves one tombstone'
);

select ok(
  (
    select deleted_at is not null and revision = 2
    from public.submitted_checkins
    where id = '50000000-0000-4000-8000-000000000004'
  ),
  'deletion atomically marks the remote check-in deleted'
);

select throws_ok(
  $test$
  select * from public.apply_sync_mutation(
    'f0000000-0000-4000-8000-000000000001',
    'f1000000-0000-4000-8000-000000000001',
    'checkin',
    '50000000-0000-4000-8000-000000000004',
    'upsert',
    2,
    3,
    '{
      "id":"50000000-0000-4000-8000-000000000004",
      "owner_user_id":"10101010-1010-4010-8010-101010101010",
      "reported_for_local_date":"2026-07-28",
      "reported_timezone_id":"UTC",
      "occurrence":"no",
      "perceived_intensity":null,
      "present_state":null,
      "note":"resurrection attempt",
      "created_at":"2026-07-28T00:00:00Z",
      "updated_at":"2026-07-28T02:00:00Z",
      "revision":3,
      "deleted_at":null
    }'::jsonb
  )
  $test$,
  '23514',
  'tombstoned check-in cannot be resurrected',
  'RPC rejects resurrection after a deletion'
);

select is(
  (
    select count(*)::integer
    from public.mutation_receipts
    where idempotency_key = 'f1000000-0000-4000-8000-000000000001'
  ),
  0,
  'resurrection failure leaves no receipt'
);

select is(
  (
    select count(*)::integer
    from public.deletion_tombstones
    where owner_user_id = '10101010-1010-4010-8010-101010101010'
      and entity_type = 'checkin'
      and entity_id = '50000000-0000-4000-8000-000000000004'
  ),
  1,
  'resurrection failure preserves the deletion fact'
);

select throws_ok(
  $test$
  update public.submitted_checkins
  set deleted_at = null,
      updated_at = '2026-07-28T02:00:00Z',
      revision = 3
  where id = '50000000-0000-4000-8000-000000000004'
  $test$,
  '42501',
  null,
  'direct update cannot bypass the RPC resurrection boundary'
);

select ok(
  (
    select deleted_at is not null and revision = 2
    from public.submitted_checkins
    where id = '50000000-0000-4000-8000-000000000004'
  ),
  'failed resurrection leaves the deleted row unchanged'
);

select * from finish();
rollback;
