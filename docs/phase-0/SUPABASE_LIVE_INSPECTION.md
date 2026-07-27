# Supabase Live Inspection Evidence

**Evidence ID:** `SUPA-P0-001`
**Project reference:** `nfzvlvukbeapcnlmyecf`
**Observed:** 28 July 2026
**Method:** OAuth-authenticated, repository-scoped `supabase_spc` MCP
**Scope:** Read-only metadata, catalog, advisor, and recent-log inspection
**Remote changes made:** None

## 1. Project identity

- The MCP returned
  `https://nfzvlvukbeapcnlmyecf.supabase.co` as the project API URL.
- Recent API health requests returned HTTP 200 for Auth and PostgREST
  readiness.
- The repository-local Codex configuration disables the pre-existing global
  Supabase MCP entry while this repository is active and enables only
  `supabase_spc`.
- The Supabase region was not exposed by the available MCP tools. Database
  settings tested for `cloud.region`, `supabase.region`, and `aws.region`
  returned null. Region therefore remains unknown and must not be inferred.

## 2. Live inventory

| Surface | Observed state |
|---|---|
| `public` tables | One table: `public.waitlist` |
| `public.waitlist` rows | Four; no email values were read or copied into evidence |
| Columns | `id uuid` primary key; `email text` unique/not-null; `created_at timestamptz` not-null |
| RLS | Enabled |
| Recorded migrations | None |
| Edge Functions | None |
| Storage buckets | None |
| Auth identities | None; this does not prove that providers are disabled |
| Performance advisors | No findings |
| Development branches | Unverified; the branch-list tool returned `Project reference is missing when validating permissions` |

This is not the approved Phase 1 synchronization schema. No evidence currently
links `public.waitlist` to the native iPhone data model.

## 3. RLS and privacy findings

The live table has two policies:

| Policy | Role/operation | Expression | Evidence result |
|---|---|---|---|
| `Allow anonymous inserts` | `anon` / `INSERT` | `WITH CHECK (true)` | Supabase Security Advisor warning: unrestricted anonymous inserts |
| `Allow anonymous select` | `anon` / `SELECT` | `USING (true)` | Every anonymous client can read all waitlist rows, including email addresses |

The public-select policy is a direct privacy exposure even though the Supabase
advisor intentionally does not flag public `SELECT USING (true)` policies.
Phase 0 cannot accept this table as a model for any app-owned record.

Advisor reference:
[Permissive RLS policy remediation](https://supabase.com/docs/guides/database/database-linter?lint=0024_permissive_rls_policy).

## 4. Privileged function finding

`public.rls_auto_enable()`:

- is `SECURITY DEFINER`;
- can be executed by both `anon` and `authenticated`;
- is exposed from the `public` schema;
- is called by the enabled `ensure_rls` event trigger after `CREATE TABLE`,
  `CREATE TABLE AS`, or `SELECT INTO`; and
- attempts to enable RLS automatically on newly created `public` tables.

Supabase Security Advisor reported separate warnings for anonymous and
authenticated execution:

- [Anonymous execution remediation](https://supabase.com/docs/guides/database/database-linter?lint=0028_anon_security_definer_function_executable)
- [Authenticated execution remediation](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable)

Automatic RLS enablement is not a substitute for explicit least-privilege
policies and tests. The function may have an administrative purpose, but
ordinary API roles do not need direct execute privilege for the event trigger
to invoke it.

## 5. Auth/log observations

- No Auth identities currently exist.
- Apple and Google provider enablement, redirect URLs, secrets, and callback
  configuration remain unverified because the available MCP tools do not
  expose Auth provider configuration.
- Recent Auth logs contained normal startup/reload activity and two platform
  deprecation notices for unsupported legacy GoTrue group-name settings.
- No application sign-in, callback, linking, revocation, or deletion evidence
  exists.

## 6. Required closure

Before Backend/Security approval:

1. Identify the owner and purpose of `public.waitlist`.
2. Remove anonymous read access to waitlist email addresses unless a documented
   purpose and privacy approval explicitly require it.
3. Replace unrestricted inserts with the minimum intended write contract plus
   abuse controls; RLS alone is not rate limiting or bot protection.
4. Revoke direct API-role execution of `public.rls_auto_enable()` or replace
   the design through a reviewed migration.
5. Capture the existing database state in version-controlled migration history
   or replace it in an isolated development branch; do not mutate the remote
   project ad hoc.
6. Configure and verify only Sign in with Apple and Sign in with Google,
   including callbacks, linking/collision, reauthentication, revocation, and
   account deletion.
7. Implement the approved Phase 1 tables and storage through versioned
   migrations with owner-positive and anonymous/other-user/forged-owner/
   expired-session/over-post/deletion negative tests.
8. Verify the project region from an authoritative dashboard or account
   metadata surface.

No item above authorizes a remote migration. A proposed remediation must be
reviewed and tested locally or on an isolated development branch before the
live test project changes.
