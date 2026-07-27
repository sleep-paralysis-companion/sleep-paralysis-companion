# Threat Model, Standards, Owners, and Sign-off

**Record ID:** `SEC-P1-001`  
**Status:** Initial threat model complete; named review and residual-risk
acceptance pending  
**Updated:** 24 July 2026

## 1. Security and safety objectives

- A guest's wellness data stays on that device unless the person explicitly
  creates/signs in to an account for sync.
- One authenticated account cannot read, overwrite, or delete another person's
  rows or objects.
- A locked/system surface does not reveal check-in values, notes, or the fact
  that a person reported an experience.
- Client compromise does not expose server-privileged credentials.
- Sync, retries, conflicts, sign-out, reinstall, and deletion do not silently
  lose or resurrect data.
- Only approved, intact audio/content executes or plays.
- Commercial state cannot be granted by device-clock change, database Boolean,
  or unverified transaction.
- Logs, analytics, diagnostics, support, and exports do not leak more data than
  their approved purpose.
- Claims and errors do not present a nonmedical app as medical or emergency
  support.

## 2. Assets

| Asset ID | Asset | Sensitivity/impact |
|---|---|---|
| `AST-001` | Check-in occurrence, intensity, present state, dates, notes | Highly sensitive wellness/free text |
| `AST-002` | Alarm schedule/preferences | Sensitive personal routine |
| `AST-003` | Local profile/settings | Pseudonymous personal configuration |
| `AST-004` | Supabase session plus Apple and Google authentication state | Account takeover |
| `AST-005` | Sync queue/revisions/tombstones | Integrity and deletion correctness |
| `AST-006` | RevenueCat entitlement/customer-information state backed by Apple transactions | Revenue/access integrity |
| `AST-007` | RevenueCat offering/entitlement plus App Store trial/subscription/lifetime configuration | Revenue/access and customer trust |
| `AST-008` | Audio assets, scripts, rights, manifest, hashes | Safety, IP, supply chain |
| `AST-009` | Privacy/legal/support copy and public URLs | App Review, legal, trust |
| `AST-010` | RLS/storage policies, Edge Functions, deployment credentials | Cross-user/system compromise |
| `AST-011` | Diagnostics and logs | Secondary sensitive-data exposure |
| `AST-012` | Export archives and temporary files | Bulk disclosure |

## 3. Actors and assumptions

| Actor | Capability |
|---|---|
| Legitimate guest | Full control of unlocked device/app data and local deletion |
| Legitimate account user | Authenticated access to own synced data |
| Another local device user | May see lock/system surfaces; should not see private content |
| Malicious user/client | Can modify network requests, IDs, clocks, local state, and replay calls |
| External attacker | Attempts credential theft, API abuse, content/policy tamper, interception |
| Compromised dependency/content pipeline | Injects code, tracking, or malicious/corrupt assets |
| Privileged operator | Has controlled backend/deployment access; insider misuse remains a risk |
| Apple/Supabase/approved processors | Platform/process data under their terms and configured controls |

Assumptions:

- iOS sandbox/Data Protection and TLS function as documented on supported,
  noncompromised devices;
- a jailbroken/fully compromised device is outside complete prevention, but
  server authorization still cannot trust the client;
- the person controls their Apple/Supabase authentication factors; and
- legal/compliance conclusions require counsel, not this technical model.

## 4. Trust boundaries

1. Person ↔ app UI/system surfaces.
2. Main app ↔ extension/App Group.
3. App process ↔ GRDB/protected files/Keychain.
4. App ↔ Apple AlarmKit/StoreKit and RevenueCat.
5. App ↔ network/TLS.
6. Public client ↔ Supabase Auth/API/Storage/Edge Functions.
7. Authenticated API ↔ Postgres/RLS.
8. Content administration ↔ manifest/object publication.
9. Commercial administration ↔ App Store Connect products/offers.
10. App/backend ↔ diagnostics processor, if approved.
11. App ↔ user-selected export destination.

No client-supplied owner, entitlement, rights, or admin claim crosses
a boundary as authority.

## 5. Threat register

| ID | Threat/abuse case | Initial | Required mitigations | Verification | Residual |
|---|---|---:|---|---|---:|
| `THR-001` | Modify owner ID to read/write another account | Critical | RLS on every table/object; immutable owner from `auth.uid()`; over-post rejection | Positive/negative/anonymous/forged-owner RLS tests | Low |
| `THR-002` | Expose service-role/signing/deployment secret in app, source, logs, or CI artifact | Critical | Server-only secret store; client uses public key only; secret/history/bundle/log scans; rotation runbook | Automated scans and extracted release-binary review | Low |
| `THR-003` | Session/token theft from SQLite, logs, extension, export, backup | High | Keychain; no token logging/export; minimal access group; revoke on sign-out/delete; file protection | Device inspection, backup/export/log scan, stolen-token tests | Medium |
| `THR-004` | Guest data uploads before explicit account/sync choice | High | No guest network path; conversion preconditions; egress test; schema rejects anonymous data | Clean-install traffic capture and offline/account conversion tests | Low |
| `THR-005` | Existing account silently claims/overwrites local data | High | Reauth; account binding; explicit merge choice; idempotent conversion; rollback | Multi-account/collision/interruption integration tests | Medium |
| `THR-006` | Concurrent sync loses edits or resurrects deletion | High | Revisions, explicit conflict rules, idempotency, tombstones, delete/edit conflict | Multi-device/offline/retry/clock-skew tests | Medium |
| `THR-007` | Note/check-in/alarm time leaks through analytics, crash logs, notifications, filenames, clipboard, support | High | Strict allowlists/redaction; neutral surfaces; no session replay; semantic privacy review | Captured traffic/device logs/notifications/export/support audit | Low |
| `THR-008` | Locked widget/AlarmKit/App Intent exposes episode association/history | High | Neutral title; minimal App Group; no note/history payload; locked-preview matrix | Physical locked-screen and notification-preview tests | Low |
| `THR-009` | Crafted/repeated deep link or intent creates duplicate record/audio/session | Medium | Route validation, no private parameters, idempotent current session, explicit Save for entry | Fuzz/malformed/repeated/terminated action tests | Low |
| `THR-010` | Malicious/corrupt/unlicensed audio is downloaded or played | High | Approved host/schema/status/rights; size/type/hash; temp + atomic install; revocation | Tamper, redirect, wrong-type/hash/size, expiry/revocation tests | Low |
| `THR-011` | Promotion extended/reopened or ended via clock/policy rollback | High | Server time; monotonic policy version; same-boot bounded cache; no wall-clock authority; audited writes | Clock, reboot, replay, old-policy, outage and boundary tests | Medium |
| `THR-012` | Premium unlock via local flag/unverified receipt/account claim | High | Pure access evaluator; active RevenueCat `premium_access` backed by Apple state; Supabase account claims are irrelevant; no client-writable premium field | Local tamper, unverified, refund/revoke/expiry, webhook replay, restore tests | Low |
| `THR-013` | Paywall or copy exploits a stressed user with fear/false urgency | High safety | Claims matrix; closable paywall; utility access; no countdown/streak/outcome claim; Product/UX approval | Content review and stressed-use usability test | Medium |
| `THR-014` | Export archive persists, leaks, or omits data while claiming completeness | High | Protected temp file, manifest/hash/scope, user-selected share, bounded cleanup | Field reconciliation, cancel/crash/relaunch/temp inspection | Low |
| `THR-015` | Local/account deletion partially completes or subscription consequence is misrepresented | High | Coordinator/status, idempotency, separate scopes, reauth, completion notice, Apple management route | Interrupted/offline/multi-device/account/StoreKit tests | Medium |
| `THR-016` | Dependency adds undeclared collection, required-reason API, vulnerable code, or supply-chain risk | High | Dependency minimization/lockfiles/provenance; SDK register; privacy manifest/signature; update review | SCA, binary/privacy report, traffic audit | Medium |
| `THR-017` | Wrong environment exposes/mutates production data during development/review | Critical | Separate Supabase projects/credentials/bundle config; startup assertions; least privilege | Build/config tests and negative production-resolution test | Low |
| `THR-018` | Local database/cache readable in locked/backup state inconsistent with promise | High | Select Data Protection and backup exclusions from use case; Keychain; minimal extension store | Physical pre/post-first-unlock, lock, restart, backup inspection | Medium pending spike |
| `THR-019` | Backend abuse causes cost/availability outage or enumeration | Medium | Auth, input limits, pagination, rate limit, idempotency, generic errors, monitoring | Load/abuse/rate/error tests | Medium |
| `THR-020` | Account deletion hijack or accidental deletion | High | Reauth, clear confirmation, CSRF/state protection, recent-auth rule, status notification | Wrong-session/replay/expired-token/concurrency tests | Low |
| `THR-021` | Sensitive content remains in database backups/operator logs beyond deletion promise | High | Approved retention, backup deletion/anonymization policy, log redaction, access audit | Restore/deletion reconciliation and operator-log audit | Medium pending Legal/ops |
| `THR-022` | Accessibility failure makes Stop, cancel, denial recovery, or destructive scope unavailable | High safety | Accessibility standard from first component; manual AT testing | VoiceOver/Voice/Switch/Dynamic Type physical matrix | Medium |
| `THR-023` | App state says alarm is set when system authorization/object disagrees | High safety/trust | System state is authority; foreground/restart reconciliation; honest fallback | Permission/restart/time-change/device matrix | Medium pending spike |
| `THR-024` | Audio continues/overlaps unexpectedly during alarm, call, route change, or lock | High safety/trust | Single playback owner; interruption state machine; physical matrix; reachable Stop | Alarm/call/Siri/headphone/background tests | Medium pending spike |

Residual ratings are proposed. Security, Privacy, Product Safety, and QA must
accept or lower every Medium residual before Gate 0/Release as assigned.

## 6. Mandatory engineering standards

### Architecture and code

- Swift 6 language mode and strict concurrency as defined by repository
  standards.
- SwiftUI feature ownership with explicit unidirectional state/actions.
- `@MainActor` only for UI state; no blocking I/O on main actor.
- protocol boundaries for database, clock, UUID, network, RevenueCat/StoreKit, AlarmKit,
  audio, auth, and policy clients.
- structured concurrency; cancellation and stale-response handling.
- typed errors and state machines; no Boolean soup for permission, sync,
  purchase, or deletion.
- GRDB migrations versioned/tested from every supported schema.
- local transactions and remote idempotency for multi-step operations.
- no production behavior hidden in previews, demo fixtures, or debug flags.

### Security

- least-privilege RLS/storage/Edge Functions and environment isolation;
- Keychain for tokens; approved iOS file protection for database/files;
- no certificate-pinning claim or custom crypto without a reviewed need;
- no secrets or permanent signed URLs in client/logs;
- dependency lock/provenance/vulnerability/privacy review;
- threat-driven negative tests in CI and before release; and
- documented incident, credential rotation, policy rollback, content
  revocation, and feature-disable paths.

### Privacy

- data allowlist, purpose, sensitivity, processor, retention, export, deletion,
  and disclosure agreed before schema/event creation;
- no forbidden permission/framework/SDK;
- privacy manifest and required-reason API register from first dependency;
- App Store privacy answers and public policy reconcile to observed traffic,
  storage, logs, and binary;
- no session replay, tracking, ads, brokerage, or marketing use of wellness
  data; and
- data-rights utilities available without premium.

### Claims and content safety

- every surface maps to `CLM-*`;
- conditional platform copy requires physical evidence;
- audio script/transcript and localization receive semantic review;
- no medical/emergency/outcome claim or inferred user state;
- errors and paywalls avoid fear, shame, urgency, or safety coercion; and
- no copied competitor privacy/legal/content text as launch authority.

### Accessibility and inclusive design

- VoiceOver semantics/focus/actions and meaningful announcements;
- all supported Dynamic Type accessibility sizes;
- Voice Control, Switch Control, Reduce Motion/Transparency, Increased
  Contrast, Differentiate Without Color;
- non-audio/non-color/non-motion equivalents;
- one-handed stressed-use review;
- accessible destructive/purchase/permission recovery; and
- physical-device manual evidence, not simulator/automated-only.

### Test and release

- requirement-derived `T-*` IDs and immutable `E-*` evidence;
- deterministic unit/integration/UI tests plus physical system tests;
- clean-install, migration, offline, interruption, retry, cancellation,
  deletion, clock/time-zone/locale, full storage, corrupt data, and backend
  outage coverage;
- RevenueCat, StoreKit Sandbox, and TestFlight lifecycle coverage;
- archive with current accepted stable Xcode/SDK;
- binary/manifest/permission/SDK/secret scan;
- App Store metadata/screenshots/privacy/review-notes reconciliation; and
- signed release/rollback/on-call/URL/backend readiness.

## 7. Operational controls

| Control | Required owner and evidence |
|---|---|
| Credential compromise | Security/Backend rotation runbook, tested without app update where possible |
| Content/rights issue | Content/Legal revocation process and catalog policy; minimum safe bundle plan |
| Promotion-policy error | Product/Finance/Release dual approval, audit, extend-free safe response, rollback |
| Backend outage | Backend on-call, monitoring, status, recovery; local core remains useful |
| RevenueCat/StoreKit incident | iOS/Product support runbook; refresh authoritative state and never invent or extend entitlement |
| Privacy incident | Privacy/Security assessment, containment, notification process |
| Harmful/misleading copy | Content/Product emergency removal or app update path |
| Release regression | Versioned database migrations, feature containment, app rollback where Apple permits, data-preserving recovery |

An incident switch may expand free access or disable a risky remote/content
capability. It may not disable alarm/data rights, silently delete data, make a
medical claim, or broaden collection.

## 8. Owner and sign-off matrix

### What “backend RLS design approval” means

RLS means Supabase/Postgres **Row Level Security**. Approval is not a
certificate from Supabase. It means the accountable backend/security reviewer
has inspected the SQL policies, storage policies, ownership model, service-role
boundary, migrations, and test plan and accepts the design for the named
artifact version. At minimum, automated tests must prove:

- the authenticated owner can perform each allowed operation;
- another authenticated account and an anonymous client cannot;
- a client cannot forge or change `owner_id`;
- expired/revoked sessions and over-posted fields are rejected; and
- deletion/tombstone and storage-object rules preserve isolation.

The result is recorded as a name, role, date, reviewed version/hash, test
evidence, exceptions, and residual risk.

### What “named sign-offs” means

This is accountable acceptance, not an external certification or a demand to
hire ten people. Each relevant role records the actual person who reviewed and
accepted a specific version and its evidence. On a small team, one person may
hold several roles; the matrix makes that explicit. Independent verification
should be separated from the person making a high-risk production policy
change when team size permits.

Named people are required; role labels alone do not pass Gate 0.

| Approval ID | Accountable role | Must approve | Name | Date/evidence |
|---|---|---|---|---|
| `APP-PROD` | Product Owner | Scope, fields, journeys, feature/access matrix, unresolved choices | Satyam Shree | `APPROVED 25 JULY 2026` for `SPEC-P1-001 v0.12` and `DEC-P0-001`; evidence gates remain |
| `APP-DESIGN` | Product Design | Navigation, every screen/state, stressed-use/paywall behavior, Figma disposition | Satyam Shree | `APPROVED 25 JULY 2026` canonical contract supersedes legacy Figma; implementation review remains |
| `APP-IOS` | iOS Lead | Target, architecture, permissions/entitlements, device feasibility, tests | Satyam Shree | `ASSIGNED 25 JULY 2026`; blocked on disposable physical spike |
| `APP-BE` | Backend/RLS Approver | Auth, RLS/storage, sync/conflicts, policy, deletion, operations | Satyam Shree | `ASSIGNED 25 JULY 2026`; blocked on versioned policies and isolation tests |
| `APP-CONTENT` | Content/Claims Owner | UI/system/audio/metadata copy and prohibited-claim review | Satyam Shree | `APPROVED 25 JULY 2026` for content roles and claims direction; final assets/copy remain release evidence |
| `APP-LEGAL` | Privacy/Legal Owner | Positioning, policies, data/retention/processors, rights, commercial disclosures | Satyam Shree | `OWNER-APPROVED 25 JULY 2026` lifecycle direction; attached PDF rejected; replacement policy/entity/contact pending |
| `APP-SEC` | Security Owner | Threat mitigations, residual risk, secrets, supply chain, incident controls | Satyam Shree | `ASSIGNED 25 JULY 2026`; Medium residual acceptance waits for test evidence |
| `APP-A11Y` | Accessibility/QA Owner | Screen-state coverage, AT/device matrix, evidence quality | Satyam Shree | `ASSIGNED 25 JULY 2026`; physical AT evidence pending |
| `APP-COMM` | Finance/Commerce Owner | Products, prices, trial, immediate cutoff/reminder, refund presentation, RevenueCat/App Store configuration | Satyam Shree | `APPROVED 28 JULY 2026` product model; RevenueCat/App Store Connect/Sandbox evidence pending |
| `APP-REL` | Release Owner | Toolchain, metadata, production configuration, review package, rollback/on-call | Satyam Shree | `ASSIGNED 25 JULY 2026`; hosted build/TestFlight/App Store configuration pending |

No one person should approve both a high-risk production policy change and its
independent verification when the team size permits separation.

## 9. Sign-off package

Each approver receives:

- all Phase 0 artifacts and source register;
- exact unresolved decision list;
- Figma revision/node mapping;
- data/SDK/network/storage observation report;
- RLS/security/test results;
- physical-device evidence;
- audio rights/content records;
- RevenueCat and StoreKit trial/subscription/lifetime Sandbox and boundary evidence;
- public legal/support URLs and App Store metadata draft;
- residual-risk list; and
- Gate record with no unowned blocker.

An approval is an explicit name, role, date, artifact version/hash, decision,
and exceptions. Silence, meeting attendance, a chat reaction, or “looks good”
without version/evidence is not sign-off.

Satyam Shree accepted accountability for all listed small-team roles on
25 July 2026. Role assignment and product approval do not substitute for
independent physical, RevenueCat/StoreKit, RLS, security, accessibility, or release
evidence. `APP-BE`, `APP-IOS`, `APP-SEC`, `APP-A11Y`, and `APP-REL` close only
after their linked evidence is reviewed and the residual risks are accepted.
Closure occurs only after the actual migrations/policies and positive/negative
test evidence exist and the reviewer records the exact name, decision, date,
artifact version/hash, exceptions, and accepted residual risks.
