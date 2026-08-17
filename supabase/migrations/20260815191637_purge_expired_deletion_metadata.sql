begin;

-- Supabase Cron executes this database-local job without an HTTP endpoint or
-- a client-visible credential. The extension must also be enabled in a
-- hosted target before this migration is applied there.
create extension if not exists pg_cron;

create or replace function private.purge_expired_deletion_metadata()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- Receipts are the idempotency window for sync mutations. Remove them
  -- first, then deletion markers, and finally the account-deletion audit
  -- record, so a retry window is never removed after its tombstone evidence.
  delete from public.mutation_receipts
  where expires_at <= pg_catalog.now();

  delete from public.deletion_tombstones
  where purge_after <= pg_catalog.now();

  delete from public.account_deletion_audit
  where purge_after <= pg_catalog.now();
end;
$$;

-- Keep the definer owned by the server administrator role. No API role gets
-- execute access; the scheduled database job runs in the trusted database
-- scheduler context, and server-side service_role callers are explicit.
alter function private.purge_expired_deletion_metadata() owner to postgres;
revoke all on function private.purge_expired_deletion_metadata()
  from public, anon, authenticated;
grant usage on schema private to service_role;
grant execute on function private.purge_expired_deletion_metadata()
  to service_role;

-- A daily UTC run is sufficient for the 30-day metadata windows. Calling
-- cron.schedule with this stable name is safe if an isolated database is
-- rebuilt or the migration is replayed through its normal migration flow.
select cron.schedule(
  'purge-expired-deletion-metadata',
  '15 3 * * *',
  $$select private.purge_expired_deletion_metadata();$$
);

commit;
