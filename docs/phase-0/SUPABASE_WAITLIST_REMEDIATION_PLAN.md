# Supabase Waitlist Remediation Plan

**Plan ID:** `SUPA-P0-002`  
**Project reference:** `nfzvlvukbeapcnlmyecf`  
**Prepared:** 28 July 2026  
**Status:** Review-only; not applied  
**Production changes authorized:** No

## 1. Confirmed dependency and safety boundary

Satyam Shree confirmed on 28 July 2026 that `public.waitlist` serves a live
website. Existing submissions must be preserved and the form must remain
available.

The website source, deployed URL, Supabase client version, request payload, and
response handling are not present in this repository. Recent Supabase API logs
showed one browser `HEAD /rest/v1/waitlist?select=*` request in the available
24-hour window, but that single request does not identify the live form or
prove its production contract. It may have been a manual inspection.

Therefore anonymous `SELECT` cannot be removed safely until one of these is
verified:

- the website inserts without chaining `.select()` and performs no anonymous
  read or duplicate check; or
- the website is first changed and deployed to use a write-only response.

Supabase JavaScript v2 does not return inserted rows unless `.select()` is
chained. The target website contract should therefore accept a successful
write with no returned row.

## 2. Additional read-only findings

The live table-level access-control list grants **all table privileges** to
`anon`, `authenticated`, and `service_role`. RLS currently prevents some
operations, but the grants are not least privilege. In particular:

- `anon` can request `SELECT` and `INSERT`;
- `anon` has insert privilege on `email`, `id`, and `created_at`;
- `authenticated` also has all table privileges even though the waitlist has
  no approved signed-in-user contract; and
- default privileges for new `public` tables, sequences, and functions also
  grant broad access to `anon` and `authenticated`.

`public.rls_auto_enable()` is `SECURITY DEFINER` and directly executable by
`PUBLIC`, `anon`, and `authenticated`. The `ensure_rls` event trigger does not
require those API roles to call the function directly.

Aggregate preflight checks did not read or copy email values. All four existing
rows:

- are nonblank;
- are at most 254 characters;
- contain no control characters;
- contain a non-leading `@`;
- are already lowercased and trimmed; and
- have no collision after lowercase-and-trim normalization.

The only current constraints are the primary key and a case-sensitive unique
constraint on `email`. There are no user-defined table triggers.

## 3. Required rollout order

### Stage A — verify and, if needed, update the website

1. Obtain the exact deployed URL and source revision.
2. Confirm the form submits only an `email` field.
3. Remove `.select()`, `head: true`, anonymous duplicate lookup, and any
   client-supplied `id` or `created_at`.
4. Normalize with trim plus lowercase before submission.
5. Treat both a new submission and an already-registered address with neutral
   copy that does not reveal whether an address exists.
6. Deploy and capture a successful live submission plus duplicate/error
   behavior without reading waitlist rows.

If Stage A already describes the deployed client, record the source line,
commit, deployment, and observed request as evidence; no client change is
required.

### Stage B — apply one reviewed, versioned database migration

The migration must:

1. preserve all existing rows;
2. drop the anonymous `SELECT` policy;
3. revoke all table privileges from `anon` and `authenticated`;
4. grant `anon` only column-level `INSERT (email)`;
5. replace `WITH CHECK (true)` with a bounded email-shape predicate;
6. revoke direct execution of `public.rls_auto_enable()` from `PUBLIC`,
   `anon`, and `authenticated`; and
7. correct default privileges so future tables/functions do not silently
   inherit broad API-role access.

`service_role` remains server-only and must never be present in the website.
Any change to its grants requires a separate dependency review.

### Stage C — add abuse protection

RLS and an email-shape check are not rate limiting or bot protection. Move the
public form behind a reviewed server endpoint or Supabase Edge Function with:

- bounded request size and content type;
- origin policy appropriate to the deployed site;
- CAPTCHA or equivalent bot challenge;
- per-IP and global rate limits;
- generic success/duplicate responses;
- no email values in ordinary logs; and
- monitoring and an incident/disable path.

After that endpoint is proven, revoke direct `anon` insert access entirely.

## 4. Candidate migration shape

This SQL is a review artifact, not an executable migration. Object names and
default-privilege owner roles must be rechecked immediately before execution.

```sql
begin;

drop policy if exists "Allow anonymous select"
  on public.waitlist;

revoke all privileges on table public.waitlist
  from anon, authenticated;

grant insert (email) on public.waitlist
  to anon;

drop policy if exists "Allow anonymous inserts"
  on public.waitlist;

create policy "Allow bounded anonymous waitlist inserts"
  on public.waitlist
  for insert
  to anon
  with check (
    email = lower(btrim(email))
    and char_length(email) between 3 and 254
    and position('@' in email) > 1
    and email !~ '[[:cntrl:]]'
  );

revoke execute on function public.rls_auto_enable()
  from public, anon, authenticated;

alter default privileges for role postgres in schema public
  revoke all on tables from anon, authenticated;
alter default privileges for role postgres in schema public
  revoke all on sequences from anon, authenticated;
alter default privileges for role postgres in schema public
  revoke execute on functions from public, anon, authenticated;

commit;
```

The default-privilege clauses affect only objects created in the future by the
specified owner role. Each Phase 1 migration must still grant its exact
required privileges explicitly after enabling RLS and defining reviewed
policies. The observed `supabase_admin` default ACL is intentionally absent
from the candidate SQL: it is a platform-managed role and must be changed only
through a confirmed Supabase Data API/default-privilege control or after an
explicit platform-impact review.

## 5. Isolation test matrix

Run the candidate migration locally or on an isolated Supabase development
branch with synthetic addresses only.

| ID | Test | Required result |
|---|---|---|
| `T-SUPA-WAIT-001` | Existing-row count and identifiers before/after migration | Preserved exactly |
| `T-SUPA-WAIT-002` | Anonymous valid normalized email insert | Succeeds without returned row |
| `T-SUPA-WAIT-003` | Anonymous `SELECT`, `HEAD`, and count | Permission denied; no row/count disclosure |
| `T-SUPA-WAIT-004` | Anonymous insert supplying `id` or `created_at` | Permission denied |
| `T-SUPA-WAIT-005` | Authenticated select/insert/update/delete | Permission denied unless a later approved contract grants it |
| `T-SUPA-WAIT-006` | Blank, oversized, control-character, non-normalized, and malformed email shapes | Rejected |
| `T-SUPA-WAIT-007` | Duplicate address | Neutral client response; no existence disclosure |
| `T-SUPA-WAIT-008` | `anon`/`authenticated` direct call to `rls_auto_enable()` | Permission denied |
| `T-SUPA-WAIT-009` | Authorized DDL invokes `ensure_rls` on an isolated synthetic table | RLS is enabled; cleanup succeeds |
| `T-SUPA-WAIT-010` | New synthetic public table/function under each relevant owner | No unintended `anon`/`authenticated` default privilege |
| `T-SUPA-WAIT-011` | Rate, oversized-body, invalid-origin, and bot-challenge tests | Denied without email logging |
| `T-SUPA-WAIT-012` | Live-site smoke test after staged deployment | Submission works; no anonymous read is possible |

After the isolated run, rerun Supabase Security Advisor. Any remaining
`rls_policy_always_true`, anonymous/authenticated `SECURITY DEFINER`, exposed
email, or broad default-grant finding fails Backend/Security acceptance.

## 6. Evidence required before live execution

- deployed website URL and source revision;
- exact current and target network requests;
- isolated migration output for `T-SUPA-WAIT-001`–`012`;
- backup/recovery point and rollback procedure;
- named Backend and Security approval with date and migration hash;
- explicit action-time approval to apply the migration to the live project;
  and
- immediate post-deployment form, privilege, policy, log, and advisor checks.

No SQL in this artifact authorizes a production change.

## 7. Primary references

- [Supabase Row Level Security](https://supabase.com/docs/guides/database/postgres/row-level-security)
- [Supabase column-level security](https://supabase.com/docs/guides/database/postgres/column-level-security)
- [Supabase database function privileges](https://supabase.com/docs/guides/database/functions)
- [Supabase JavaScript insert behavior](https://supabase.com/docs/reference/javascript/insert)
- [Supabase secure-data guidance](https://supabase.com/docs/guides/database/secure-data)
