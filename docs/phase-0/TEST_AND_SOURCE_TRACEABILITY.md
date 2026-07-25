# Test and Source Traceability Catalog

**Catalog ID:** `TRACE-P1-001`  
**Status:** Stable ID convention and pre-implementation test plan  
**Updated:** 24 July 2026

## 1. Trace chain

Every Phase 1 behavior must retain this chain:

`source ID → decision ID (when needed) → P1 requirement ID → screen/state ID →
data/permission/claim ID → test ID → evidence URI → Gate approval`

An implementation ticket, pull request, test report, App Review note, or release
record is incomplete when it skips a link.

## 2. Stable ID namespaces

| Prefix | Owner artifact | Meaning |
|---|---|---|
| `S-*` | [Source reconciliation](./SOURCE_RECONCILIATION.md) | External/internal source |
| `D0-*` | [Decision register](./OPEN_DECISIONS_AND_CONFLICTS.md) | Phase 0 decision |
| `P1-*` | [Requirements matrix](./REQUIREMENTS_TRACEABILITY_MATRIX.md) | Normative requirement or exclusion |
| `SCR-*` | [Navigation/state map](./NAVIGATION_AND_STATE_MAP.md) | Screen, route, or system surface |
| `ST-*` | [Navigation/state map](./NAVIGATION_AND_STATE_MAP.md) | Reusable UI/system state |
| `DATA-*` | [Data lifecycle contract](./DATA_LIFECYCLE_AND_SYNC_CONTRACT.md) | Entity or field group |
| `FLOW-*` | [Data lifecycle contract](./DATA_LIFECYCLE_AND_SYNC_CONTRACT.md) | Data flow |
| `RET-*` | [Data lifecycle contract](./DATA_LIFECYCLE_AND_SYNC_CONTRACT.md) | Retention/deletion rule |
| `CLM-*` | [Claims matrix](./CLAIMS_AND_COPY_MATRIX.md) | Claim/copy rule |
| `AUD-*` | [Audio contract](./AUDIO_AND_OFFLINE_CONTRACT.md) | Audio asset or behavior |
| `COM-*` | [Commercial access](./COMMERCIAL_ACCESS_AND_PERMISSIONS.md) | Commercial/access rule |
| `PERM-*` | [Commercial access](./COMMERCIAL_ACCESS_AND_PERMISSIONS.md) | Permission/entitlement |
| `THR-*` | [Threat model](./THREAT_MODEL_AND_STANDARDS.md) | Threat/mitigation |
| `T-*` | This catalog | Test case or manual protocol |
| `E-*` | Test/release system, assigned when evidence exists | Immutable evidence record |
| `G0-*` | [Gate 0 review](./GATE_0_REVIEW.md) | Gate criterion or blocker |

IDs are never renumbered or reused. A removed item is marked `RETIRED` with its
replacement; it is not deleted from history.

## 3. Requirement-to-test ID rule

For each requirement `P1-AREA-NNN`, applicable tests use:

`T-AREA-NNN-METHOD[-CASE]`

Examples:

- `P1-SLP-004` → `T-SLP-004-DEVICE-LOCKED`
- `P1-SYN-005` → `T-SYN-005-INT-OFFLINE-DELETE`
- `P1-GRD-006` → `T-GRD-006-COPY-EN`
- `P1-ACC-001` → `T-ACC-001-A11Y-VOICEOVER`

Allowed method tokens:

| Token | Evidence |
|---|---|
| `UNIT` | Deterministic domain/unit test |
| `INT` | Database, StoreKit, backend, extension, or multi-component integration |
| `UI` | Automated application UI behavior |
| `DEVICE` | Manual or instrumented physical iPhone evidence |
| `A11Y` | Manual assistive-technology/accessibility evidence |
| `COPY` | Claims/content/localization review |
| `PRIV` | Data/privacy/manifest/network/storage inspection |
| `SEC` | Security/policy/abuse-case test |
| `PERF` | Measured responsiveness/resource evidence |
| `REVIEW` | App Store/release-readiness rehearsal |
| `NA` | Method is inapplicable; must include an approved reason |

Each requirement needs at least one test ID before implementation and an
evidence ID before acceptance. Requirements that describe platform behavior
need `DEVICE`; a simulator result cannot replace it. Claims need `COPY`;
accessibility needs `A11Y`; data/permission requirements need `PRIV` and/or
`SEC`.

## 4. Required suite catalog

These suite IDs group individual requirement-derived test IDs; they do not
replace them.

| Suite ID | Requirement coverage | Required scenarios |
|---|---|---|
| `T-SUITE-ONB-001` | `P1-ONB-001`–`009` | Clean install, interrupted onboarding, re-entry, notice update, no-login path, no-permission-before-purpose, offline, VoiceOver, largest Dynamic Type |
| `T-SUITE-SLP-001` | `P1-SLP-001`–`011` | Alarm authorization states, schedule/edit/remove, locked, silent, Focus, terminated, restart, external Settings change, DST, manual time/time-zone change, stale system object, fallback truth |
| `T-SUITE-ACT-001` | `P1-ACT-001`–`006` | Every proposed system surface, locked/unlocked, auth required/not required, offline, app absent/background/terminated, repeated activation, private previews |
| `T-SUITE-GRD-001` | `P1-GRD-001`–`006` | Bundled/silent entry, offline, corrupt asset, audio route/interruption, background/lock, exit, no-log path, claims review |
| `T-SUITE-CHK-001` | `P1-CHK-001`–`005` | No entry, draft, abandoned, submitted no/yes, conditional intensity, note boundary, edit/delete, duplicate, date/locale/calendar/DST |
| `T-SUITE-HIS-001` | `P1-HIS-001`–`004` | Empty, single/multiple entries, edit/delete, offline, sync/conflict, descriptive math, textual chart equivalent, prohibited inference scan |
| `T-SUITE-SET-001` | `P1-SET-001`–`008` | All settings states, external permission changes, export reconciliation, local/account deletion, policy URLs, trial eligibility/conversion, lifetime, and StoreKit lifecycle |
| `T-SUITE-AUTH-001` | `P1-AUTH-001`–`005` | Guest fallback, Apple/Google/email success and cancellation, offline/provider errors, email verification/recovery/rate limits, identity collision/linking, reauthentication, token expiry/revocation, sign-out, account deletion |
| `T-SUITE-OFF-001` | `P1-OFF-001`–`003` | Fresh offline, reconnect, backend outage, queue retry, disk full, database migration interruption, corrupt cache |
| `T-SUITE-SYN-001` | `P1-SYN-001`–`007` | Guest privacy, conversion rollback, existing-account choice, queue states, deterministic conflicts, tombstones, RLS isolation, token expiry, sign-out, reinstall, account deletion |
| `T-SUITE-ACC-001` | `P1-ACC-001`–`005` | VoiceOver, Voice Control, Switch Control, all Dynamic Type sizes, Reduce Motion/Transparency, contrast/differentiation, focus/error/destructive actions |
| `T-SUITE-SEC-001` | `P1-SEC-001`–`010` | Field allowlist, forbidden permission/binary scan, traffic/storage/log audit, secret scan, environment isolation, Keychain/file protection, privacy manifests, RLS, threat abuse cases |
| `T-SUITE-REL-001` | `P1-REL-001`–`006` | Archive validation, physical matrix, metadata/binary reconciliation, clean-review walkthrough, TestFlight, backend/URL availability, rollback |
| `T-SUITE-X-001` | `P1-X-001`–`009` | Binary, source, UI, schema, manifest, SDK, analytics, metadata, screenshot, and support-copy absence checks |

## 5. Source traceability

The `Sources` column of
[Requirements traceability matrix](./REQUIREMENTS_TRACEABILITY_MATRIX.md) is
normative. A source reference must use a registered `S-*` ID and, for repository
standards, a section or heading. New sources are first added to
[Source reconciliation](./SOURCE_RECONCILIATION.md).

Discovery sources (`S-PRD`, `S-MEETING`, `S-TECH`, `S-FIGMA`) cannot by
themselves create an accepted requirement. A discovery-only behavior needs an
approved `D0-*` decision and controlling requirement.

`S-PRD-P1-COPY` is narrower: it controls exact strings only after the related
capability is inside approved scope and the claims matrix allows the wording.

## 6. Evidence record

An evidence record uses an immutable ID `E-YYYYMMDD-NNN` and contains:

- exact test IDs and requirement IDs;
- app version/build/commit;
- Xcode, Swift, SDK, and deployment target;
- physical model, OS build, locale, calendar, time zone, appearance, text size,
  authorization, entitlement, network, lock, Focus, silent, and account states;
- fixtures and backend environment;
- expected and observed result;
- screenshots/video/logs with sensitive data removed;
- tester and timestamp;
- pass/fail and defect links; and
- reviewer approval.

“Tested,” a screenshot without state metadata, simulator-only evidence for
system behavior, or a passing build is not a valid evidence record.

## 7. Pre-implementation test obligations

Before a Phase 1 implementation slice begins, its plan must list:

1. included `P1-*` requirements and explicit exclusions;
2. `SCR-*`/`ST-*` states;
3. fields/flows/permissions/claims affected;
4. individual `T-*` IDs using this convention;
5. the physical evidence needed;
6. failure and rollback behavior; and
7. the owner who can accept the result.

Any unmapped behavior returns to Phase 0 change control instead of being
decided in code.
