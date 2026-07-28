begin;

create extension if not exists pgtap with schema extensions;

select plan(7);

select is(
  (
    select count(*)
    from pg_class
    where oid = any(array[
      'public.app_profiles'::regclass,
      'public.app_settings'::regclass,
      'public.alarm_preferences'::regclass,
      'public.submitted_checkins'::regclass,
      'public.deletion_tombstones'::regclass,
      'public.mutation_receipts'::regclass,
      'public.account_deletion_audit'::regclass
    ])
      and not relrowsecurity
  ),
  0::bigint,
  'security advisor: every app table has RLS enabled'
);

select is(
  (
    select count(*)
    from pg_class
    where oid = any(array[
      'public.app_profiles'::regclass,
      'public.app_settings'::regclass,
      'public.alarm_preferences'::regclass,
      'public.submitted_checkins'::regclass,
      'public.deletion_tombstones'::regclass,
      'public.mutation_receipts'::regclass,
      'public.account_deletion_audit'::regclass
    ])
      and not relforcerowsecurity
  ),
  0::bigint,
  'security advisor: every app table forces RLS'
);

select is(
  (
    select count(*)
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.prosecdef
  ),
  0::bigint,
  'security advisor: the app API schema contains no SECURITY DEFINER functions'
);

select is(
  (
    select count(*)
    from pg_policies
    where schemaname = 'public'
      and tablename = any(array[
        'app_profiles',
        'app_settings',
        'alarm_preferences',
        'submitted_checkins',
        'deletion_tombstones',
        'mutation_receipts'
      ])
      and (
        (qual like '%auth.uid()%' and qual not like '%SELECT auth.uid()%')
        or (with_check like '%auth.uid()%' and with_check not like '%SELECT auth.uid()%')
      )
  ),
  0::bigint,
  'performance advisor: RLS auth.uid calls use init-plan SELECT form'
);

select is(
  (
    select count(*)
    from pg_constraint constraint_record
    join pg_class table_record on table_record.oid = constraint_record.conrelid
    join pg_namespace schema_record on schema_record.oid = table_record.relnamespace
    where schema_record.nspname = 'public'
      and table_record.relname = any(array[
        'app_profiles',
        'app_settings',
        'alarm_preferences',
        'submitted_checkins',
        'deletion_tombstones',
        'mutation_receipts'
      ])
      and constraint_record.contype = 'f'
      and not exists (
        select 1
        from pg_index index_record
        where index_record.indrelid = constraint_record.conrelid
          and constraint_record.conkey <@ index_record.indkey::smallint[]
          and index_record.indisvalid
      )
  ),
  0::bigint,
  'performance advisor: every app foreign key has a valid covering index'
);

select is(
  (
    select count(*)
    from pg_class table_record
    join pg_namespace schema_record on schema_record.oid = table_record.relnamespace
    where schema_record.nspname = 'public'
      and table_record.relname = any(array[
        'app_profiles',
        'app_settings',
        'alarm_preferences',
        'submitted_checkins',
        'deletion_tombstones',
        'mutation_receipts',
        'account_deletion_audit'
      ])
      and not exists (
        select 1
        from pg_constraint
        where conrelid = table_record.oid
          and contype = 'p'
      )
  ),
  0::bigint,
  'security advisor: every app table has an explicit primary key'
);

select is(
  (
    select count(*)
    from pg_index index_record
    join pg_class table_record on table_record.oid = index_record.indrelid
    join pg_namespace schema_record on schema_record.oid = table_record.relnamespace
    where schema_record.nspname = 'public'
      and table_record.relname = any(array[
        'app_profiles',
        'app_settings',
        'alarm_preferences',
        'submitted_checkins',
        'deletion_tombstones',
        'mutation_receipts',
        'account_deletion_audit'
      ])
      and not index_record.indisvalid
  ),
  0::bigint,
  'performance advisor: app schema contains no invalid indexes'
);

select * from finish();

rollback;
