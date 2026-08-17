# Supabase retention purge

The migration `20260815191637_purge_expired_deletion_metadata.sql` adds the
server-only retention job for deletion metadata. It creates the private
`private.purge_expired_deletion_metadata()` function and schedules it with
Supabase Cron.

The function deletes only rows whose retention boundary has passed:

1. `public.mutation_receipts` where `expires_at <= now()`
2. `public.deletion_tombstones` where `purge_after <= now()`
3. `public.account_deletion_audit` where `purge_after <= now()`

This order removes expired idempotency receipts before the deletion markers,
and removes the account-deletion audit record last. Each delete is committed as
one function invocation and is safe to repeat.

## Boundary and schedule

The function is in the unexposed `private` schema, is `SECURITY DEFINER`, is
owned by `postgres`, and grants `EXECUTE` only to `service_role`. `anon` and
`authenticated` cannot invoke it. The job does not accept a service-role key,
and no service-role key belongs in source, app configuration, tests, or logs.

The migration enables `pg_cron` and creates this job through
`cron.schedule`:

- job name: `purge-expired-deletion-metadata`
- schedule: `15 3 * * *` (daily at 03:15 UTC)
- command: `select private.purge_expired_deletion_metadata();`

Do not edit `cron.job` directly. If the schedule must change, update the
migration before applying it to a target or use the documented `cron.schedule`,
`cron.alter_job`, and `cron.unschedule` functions in a controlled deployment.

Hosted deployment is still required. This checkout has not been linked to or
mutated against a live Supabase project; applying the migration to a hosted or
production target, confirming the job in `cron.job`, and observing successful
runs in `cron.job_run_details` remain deployment checks.

## Local verification

The repository's supported isolated backend entrypoint is
`bash scripts/verify_backend_ci.sh`. It uses the pinned CLI version from
`scripts/versions.env`, excludes optional services, resets only the local
database, runs all pgTAP files (including this one), and then runs lint and
secret checks.

For a targeted local run with Docker available, use the same supported CLI
flags and the repository's pinned version:

```text
npx.cmd --yes supabase@2.110.0 start -x studio,imgproxy,mailpit,storage-api,edge-runtime,logflare,vector,supavisor
npx.cmd --yes supabase@2.110.0 db reset --local
npx.cmd --yes supabase@2.110.0 test db --local supabase/tests/retention_purge_test.sql
```

The pgTAP test covers expired-row removal, future-row preservation, repeated
execution, the service-role boundary, unauthorized API roles, and the Cron
command. These commands start/reset/test only the local database; they do not
link or target a hosted project. The `db reset --local` step is intentionally
local-only and is not a production deployment command.
