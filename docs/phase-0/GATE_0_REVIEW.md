# Gate 0 Review — Product, Claims, and Feasibility Lock

**Gate record:** `G0-2026-07-24-001`  
**Review date:** 25 July 2026  
**Decision:** **NOT PASSED**  
**Production implementation authorized:** **No**  
**Disposable platform spike authorized:** Only under
[`FEAS-P1-001`](./PLATFORM_FEASIBILITY_REPORT.md#4-disposable-spike-boundary)

## 1. Decision summary

The documentation baseline now has:

- reconciled repository, PRD, meeting, and technical-plan evidence;
- one controlling Phase 1 product specification;
- stable requirement, source, screen/state, data, claim, permission, threat,
  and test ID conventions;
- complete proposed onboarding, data, sync, audio, commercial, permission,
  retention, export/deletion, threat, and feasibility contracts; and
- an explicit owner/blocker register.

Gate 0 still fails because a documentation draft is not approval or physical
proof. Figma file/node identity and all three canvases were inspected
read-only. Satyam Shree approved treating the unavailable hierarchy and all
conflicting legacy visual concepts as superseded discovery material.
Satyam Shree has now accepted the small-team Product, Design, iOS, Backend,
Content/Claims, Privacy/Legal, Security, Accessibility/QA, Commerce, and
Release roles and approved the product/commercial/lifecycle directions recorded
on 25 July 2026.
AlarmKit, system entry, locked/offline audio, StoreKit behavior, Supabase RLS,
and accessibility still have no required runtime/device evidence. The supplied
privacy PDF is not publishable; a product-accurate replacement draft now
exists but still needs the identified legal/contact/region values and approval.

The exact PRD wording tab is now available, Apple/Google/email account methods
are selected, and clearly labeled audio/asset and legal-URL placeholders are
authorized for the current phase. Those placeholder inputs remain mandatory
shipping dependencies, but their final files/URLs are no longer treated as
missing Phase 0 source material.

No production app feature, schema, backend migration, StoreKit product,
permission, entitlement, or remote policy was implemented in Phase 0.

## 2. Gate 0 exit criteria

| ID | Gate criterion | Current evidence | Result |
|---|---|---|---|
| `G0-C-001` | All authoritative and discovery sources identified/reconciled | Repository, all PRD tabs, full meeting record, three DOCX bodies, Figma discovery, supplied user flow, and supplied privacy PDF reconciled in `SOURCE_RECONCILIATION.md` | `PASS` |
| `G0-C-002` | Design-source conflicts are completely dispositioned and implementation has one controlling screen/state/copy contract | `FIGMA-P0-001` confirms file/page/canvas evidence and unavailable hierarchy. `D0-025` explicitly supersedes conflicting/unmappable legacy Figma with `SPEC-P1-001`; no design mutation occurred. | `PASS — SUPERSEDED SOURCE` |
| `G0-C-003` | One canonical noncontradictory Phase 1 scope and exclusion set | `SPEC-P1-001 v0.12`, source conflict table, decision/rejection register | `PASS — OWNER APPROVED` |
| `G0-C-004` | Stable requirements with source and test traceability | Existing `P1-*` matrix plus `TRACE-P1-001` ID/evidence rules | `PASS — PLAN`; test evidence not yet expected except feasibility |
| `G0-C-005` | Complete onboarding truth table and field-purpose inventory | `SPEC-P1-001 §§7–8`; minimal check-in copy/date/uniqueness/draft rules approved | `PASS — OWNER APPROVED` |
| `G0-C-006` | Claims/copy matrix across every surface; no prohibited claims | `CLAIMS-P1-001`; Figma/user-flow/privacy conflicts superseded; `PRIV-P1-002` and `LEGAL-P1-003` provide product-accurate replacement drafts | **FAIL:** factual/legal placeholders, final audio/store metadata, legal approval, and release evidence remain |
| `G0-C-007` | Complete navigation, screen, state, error, destructive, permission, purchase, sync, offline inventory | `NAV-P1-001`; legacy Figma superseded by canonical contract | `PASS — OWNER APPROVED PLAN` |
| `G0-C-008` | Data inventory, data flow, retention, export, deletion, analytics/privacy contract | `DATA-P1-001`; Supabase plus Apple/Google/email-code direction and retention defaults approved; diagnostics off; `PRIV-P1-002` drafted | **FAIL:** legal/entity/region applicability values and backend evidence remain |
| `G0-C-009` | Guest-to-account ownership, conversion, conflicts, retry, tombstones, sign-out, reinstall, deletion are deterministic | `DATA-P1-001 §§5–7, 11–12`; merge, linking, reauthentication, sign-out, draft, and recovery direction owner-approved | **FAIL:** Supabase callbacks, migrations, RLS/storage policies, isolation, recovery, and deletion tests unrun |
| `G0-C-010` | Audio roles, delivery/offline/playback contract, placeholder boundary, and shipping-content gate are explicit | `AUDIO-P1-001`; user authorized placeholders and owned synthetic spike audio | `PASS — PLACEHOLDER CONTRACT`; actual rights/content/assets are required before production content integration and release |
| `G0-C-011` | Commercial model, access matrix, trial/offline/grace/restore/refund/revoke behavior | `COM-P1-001`: monthly USD 8.99, annual USD 59.99, lifetime USD 149.99, three-day offer, Family Sharing off, 16-day paid-renewal grace | **FAIL — PRODUCT APPROVED:** App Store Connect and Sandbox evidence absent |
| `G0-C-012` | Permission/entitlement register; excluded capabilities absent | `COM-P1-001 §6` | **FAIL:** target/system surface/background capability still depends on physical spike |
| `G0-C-013` | Initial threat model, mitigation/test owners, residual risk accepted | `SEC-P1-001`; Satyam Shree is assigned to all review roles | **FAIL:** mitigation tests and evidence-backed Medium residual acceptance missing |
| `G0-C-014` | Safety, privacy, security, accessibility, analytics, and release standards with named owners | `SEC-P1-001 §§6–9`; Satyam Shree assigned to all small-team roles | **FAIL — OWNED:** evidence-backed iOS/backend/security/accessibility/release decisions remain |
| `G0-C-015` | Physical feasibility proves AlarmKit, fallback, system entry, lock/offline/terminated/restart/time/audio/accessibility behavior | `FEAS-P1-001` protocol only | **FAIL:** no Xcode/physical execution |
| `G0-C-016` | Minimum deployment target and system-surface choice locked from evidence | `TARGET-A` proposed for spike | **FAIL** |
| `G0-C-017` | Privacy/terms/wellness/support copy and public-URL delivery gate are explicit | `PRIV-P0-001` rejects the supplied template; `PRIV-P1-002` and `LEGAL-P1-003` record Sleep Paralysis Companion, a publication-date rule, age 13+, United States scope, product-accurate drafts, and an explicit publication gate | **FAIL:** legal-entity verification, address, monitored email aliases, Supabase region, governing law/venue, applicability approval, and final legal approval remain; live URLs remain release evidence |
| `G0-C-018` | Every material decision has named dated approval and no unowned blocker | `DEC-P0-001` enumerates dated decisions and assigns every remaining blocker to Satyam Shree's small-team roles | `PASS — OWNED` |

Because any `FAIL` prevents passage, Gate 0 is **NOT PASSED**.

## 3. Exact unblock actions

### `G0-B-001` — Design-source disposition — **CLOSED**

- **Decision:** `D0-025` preserves the confirmed read-only canvas evidence but
  makes `SPEC-P1-001`, `NAV-P1-001`, and `CLAIMS-P1-001` controlling.
- **Evidence:** Satyam Shree approved supersession on 25 July 2026.
- **Mutation boundary:** editor permission, if technically required by Figma
  MCP, grants no authority to change the design. Use read-only inspection and
  documentation mapping only; make no Figma write of any kind.

### `G0-B-002` — Product/Commerce choices — **CLOSED AS DECISIONS**

- **Decision:** Sleep Paralysis Companion; alarm free/all other features
  premium; monthly USD 8.99; annual USD 59.99; lifetime USD 149.99; StoreKit
  three-day introductory offer; Family Sharing off; 16-day paid-renewal grace;
  exact check-in and Supabase email-code UX recorded in the linked contracts.
- **Remaining evidence:** App Store Connect, Sandbox, and runtime tests under
  `G0-B-005`.

### `G0-B-003` — Replace and approve privacy/legal package

- **Owner:** Privacy/Legal + Product + Backend + Security.
- **Action:** finalize `PRIV-P1-002`, the replacement for the rejected PDF;
  verify the supplied provider name as the legal contracting entity; create
  and verify the mailing address and monitored privacy/support mailboxes;
  confirm the Supabase region, governing law/venue, United States/age-13
  applicability, publication date, and approved public wording. Keep
  diagnostics off unless separately approved.
- **Evidence:** final policy/terms/support versions plus RLS/deletion evidence;
  live tested URLs remain a release gate.

### `G0-B-004` — Placeholder content roles — **CLOSED FOR PHASE 0**

- **Owner:** Content/Claims + Legal/Rights + Accessibility + Product.
- **Decision:** Satyam Shree approved `AUD-SLOT-001`–`003` and an
  owned-synthetic spike fixture on 25 July 2026. Do not integrate real content
  until concrete catalog records arrive.
- **Evidence for Gate 0:** signed role/delivery/claims/accessibility contract
  and synthetic-fixture provenance. **Evidence before release:** rights files,
  scripts/transcripts/translations, hashes/mastering, approvals,
  bundle/download classification, and commercial class for actual assets.

### `G0-B-005` — Execute isolated physical spike

- **Owner:** iOS + QA/Accessibility + Design/Privacy.
- **Action:** run `FEAS-P1-001` on the proposed matrix using an isolated
  disposable target.
- **Prepared:** `spikes/phase0-platform-feasibility/` and `codemagic.yaml`
  contain the disposable source/workflow; compile, signing, TestFlight upload,
  installation, and observation have not occurred.
- **Evidence:** immutable `E-*` records for AlarmKit, permissions, silent/Focus,
  lock, termination, restart, time/DST/time zone, system action, idempotency,
  offline, audio/interruption/routes, privacy, accessibility, and performance.
- **Decision:** select deployment target, fallback, manual surface, App
  Group/extension, Live Activity, background audio, Data Protection, and exact
  platform copy.
- **Hardware minimum:** one compatible physical iPhone may start the spike;
  release evidence requires at least two representative physical models,
  including oldest-supported and current classes.
- **No-owned-Mac route:** compile/sign/upload through an approved hosted macOS
  iOS workflow (recommended: Codemagic automatic signing plus internal
  TestFlight), and run the matrix on the arranged iPhone. Use a borrowed or
  remote interactive Mac only when CI logs cannot resolve an Xcode/platform
  issue. A macOS/Xcode environment remains required somewhere even though
  local Mac ownership is not.

### `G0-B-006` — Approve security/backend operations

- **Owner:** Backend + Security + Release.
- **Action:** review RLS/storage/Auth/Edge Function designs, threat mitigations,
  StoreKit administration, environment isolation, deletion, content
  revocation, incident response, and residual risk.
- **Evidence:** test plan/results appropriate to Phase 0 spike/design, named
  residual acceptances, and production change-control runbooks.
- **Assigned reviewer:** Satyam Shree accepted accountability for the
  backend/RLS review on 25 July 2026. This is an assignment, not approval;
  `APP-BE` closes only after the policies and isolation tests are reviewed and
  a named, dated, versioned decision is recorded.

### `G0-B-007` — Complete evidence-backed sign-off

- **Owner:** Product sponsor.
- **Action:** Satyam Shree is now named for every small-team role. Close the
  pending iOS/backend/security/accessibility/release decisions only after their
  linked evidence exists.

## 4. Artifact handoff

| Handoff item | File |
|---|---|
| Control index and authority | [README](./README.md) |
| Source/revision/conflict evidence | [Source reconciliation](./SOURCE_RECONCILIATION.md) |
| Figma identity, canvas conflicts, missing states, and connector evidence | [Figma read-only audit](./FIGMA_READ_ONLY_AUDIT.md) |
| Product and onboarding/field contract | [Canonical product specification](./CANONICAL_PHASE_1_PRODUCT_SPEC.md) |
| Stable requirements | [Requirements traceability matrix](./REQUIREMENTS_TRACEABILITY_MATRIX.md) |
| Stable tests/evidence chain | [Test and source traceability](./TEST_AND_SOURCE_TRACEABILITY.md) |
| Claims/copy | [Claims and copy matrix](./CLAIMS_AND_COPY_MATRIX.md) |
| Navigation and states | [Navigation and state map](./NAVIGATION_AND_STATE_MAP.md) |
| Data/sync/lifecycle | [Data lifecycle and sync](./DATA_LIFECYCLE_AND_SYNC_CONTRACT.md) |
| Supplied privacy asset disposition | [Privacy-policy asset review](./PRIVACY_POLICY_ASSET_REVIEW.md) |
| Product-accurate replacement policy draft | [Phase 1 privacy-policy draft](./PRIVACY_POLICY_PHASE_1_DRAFT.md) |
| Wellness, Terms, support, commerce, and deletion copy draft | [Legal and support copy draft](./LEGAL_AND_SUPPORT_COPY_DRAFT.md) |
| Audio/catalog/offline | [Audio and offline](./AUDIO_AND_OFFLINE_CONTRACT.md) |
| Commercial/permissions | [Commercial access and permissions](./COMMERCIAL_ACCESS_AND_PERMISSIONS.md) |
| Threat/standards/sign-off | [Threat model and standards](./THREAT_MODEL_AND_STANDARDS.md) |
| Device spike/target protocol | [Platform feasibility report](./PLATFORM_FEASIBILITY_REPORT.md) |
| Decisions/conflicts/blockers | [Decision register](./OPEN_DECISIONS_AND_CONFLICTS.md) |

## 5. Next safe work

### Before Gate 0 passes

Only:

- resolve/document the blockers above;
- update these artifacts through change control; and
- execute the isolated disposable physical-platform spike.

Do not create the production Xcode target, production database migration,
StoreKit products, Supabase production policy, audio publication, analytics
integration, or permissions/entitlements.

### Phase 1A after Gate 0 passes

The first authorized production slice is foundation only:

1. Create the native iPhone Xcode project with the approved stable
   Xcode/Swift/SDK and evidence-selected deployment target.
2. Establish environment-isolated configuration and production-safe build
   settings.
3. Add the approved module boundaries, dependency injection, typed navigation,
   clock/UUID/platform protocols, and Swift concurrency settings.
4. Add GRDB with only the approved initial schema/migration and local repository
   tests.
5. Add the privacy manifest, dependency/SDK register, secret scanning, and
   permission/entitlement absence checks from the first commit.
6. Establish CI for build, unit tests, lint/format rules if approved,
   accessibility/static/privacy/security checks, and evidence naming.
7. Add no user-facing alarm, grounding, check-in, sync, commerce, or account
   feature until its subsequent phase slice and requirement/test set is
   authorized.

Phase 1A completion does not itself approve Phase 1B or a release.

## 6. Gate owner sign-off

| Role | Name | Decision/date | Evidence |
|---|---|---|---|
| Product Owner | Satyam Shree | `APPROVED 25 JULY 2026` | `SPEC-P1-001 v0.12`, `DEC-P0-001` |
| Design | Satyam Shree | `APPROVED 25 JULY 2026` | Legacy Figma supersession and canonical state/copy contract |
| iOS Lead | Satyam Shree | `ASSIGNED — EVIDENCE PENDING` | `FEAS-P1-001` physical spike |
| Backend Lead | Satyam Shree | `ASSIGNED — EVIDENCE PENDING` | Supabase migrations/RLS/isolation/deletion tests |
| Content/Claims | Satyam Shree | `APPROVED DIRECTION 25 JULY 2026` | `CLAIMS-P1-001`, `AUD-SLOT-001`–`003`; final assets pending |
| Privacy/Legal | Satyam Shree | `OWNER-APPROVED DIRECTION 25 JULY 2026` | `DATA-P1-001`, `PRIV-P0-001`; replacement policy pending |
| Security | Satyam Shree | `ASSIGNED — EVIDENCE PENDING` | Threat/RLS/StoreKit/physical evidence and residual acceptance |
| Accessibility/QA | Satyam Shree | `ASSIGNED — EVIDENCE PENDING` | Physical AT/device matrix |
| Finance/Commerce | Satyam Shree | `APPROVED 25 JULY 2026` | `COM-P1-001`; App Store Connect/Sandbox evidence pending |
| Release | Satyam Shree | `ASSIGNED — EVIDENCE PENDING` | Hosted macOS/TestFlight/App Store configuration |

**Final Gate 0 result: NOT PASSED.**
