# Privacy, Network, and Permission Evidence

## Onboarding allowlist

The production onboarding boundary accepts exactly five values:

| Value | Purpose | Created |
|---|---|---:|
| Local profile ID | stable local identity | after summary Continue |
| Profile created time | lifecycle/audit ordering | same transaction |
| Product notice version | deterministic notice routing | same transaction |
| Product notice seen time | avoid repeated display | same transaction |
| Onboarding completion time | deterministic launch routing | same transaction |

No onboarding code accepts name, age, diagnosis, medication, episode frequency, emotions, voice
preference, location, health data, marketing consent, account credential, alarm setting, or
check-in answer.

## Local and network boundary

- Onboarding composition creates a local GRDB actor only.
- Welcome performs no write.
- Continue creates one local guest row with no settings row or sync operation.
- Ordinary guest launch reads only the local profile.
- Sync is a user-selected explanatory route and starts no provider flow or upload.
- The Phase 1C App, Features, and onboarding store import neither Supabase nor a networking API.
- Authentication and synchronization code from Phase 1B is not composed into onboarding or
  ordinary guest launch.

## Permission boundary

- No permission usage-description or entitlement was added.
- No notification, alarm, microphone, health, tracking, or other permission framework is
  imported by Phase 1C.
- No request API is reachable.
- The permission screen is education/recovery presentation only and reports `notRequested`.
- Alarm status explicitly says no alarm is scheduled.

## Copy and legal boundary

Welcome and the boundary summary use the owner-approved CLM-001 and CLM-002 strings exactly.
Repository checks scan for prohibited product, commerce, framework, permission, credential,
entitlement, secret, and network-boundary patterns.

Privacy/help/legal screens use bundled local content only. They do not invent an address, email,
governing law, final legal approval, price, trial eligibility, or provider configuration.

## Supabase boundary

No live Supabase project was linked, reset, migrated, or queried. The hosted backend job is the
existing isolated local-Supabase regression suite. The repository Supabase instructions governed
that boundary; Phase 1C introduces no database/Auth server change.
