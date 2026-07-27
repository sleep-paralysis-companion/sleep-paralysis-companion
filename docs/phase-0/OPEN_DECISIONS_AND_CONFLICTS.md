# Phase 0 Decision, Conflict, and Blocker Register

**Register ID:** `DEC-P0-001`  
**Status:** Current baseline; open approvals prevent Gate 0  
**Updated:** 28 July 2026

## 1. Decision rule

`ADOPTED` selects product direction but does not prove feasibility or approve
production. `PROPOSED` is a complete recommendation awaiting the named owner.
`BLOCKED` lacks evidence or authority. `EXCLUDED` requires formal change control
to reopen.

An approved record includes:

- selected and rejected options;
- benefit and scope impact;
- claims, fields, retention, permissions, analytics, accessibility, security,
  offline, commerce, and App Review impact;
- linked requirements/screens/tests/disclosures;
- acceptance evidence;
- accountable approver, date, and artifact version; and
- residual risks/exceptions.

## 2. Stable decision records

| ID | Decision | Recorded direction | Status | Required closure |
|---|---|---|---|---|
| `D0-001` | Product/store name | Use **Sleep Paralysis Companion** as the product/store name; `SP` may remain an internal abbreviation. | `APPROVED BY SATYAM SHREE — 25 JULY 2026` | Trademark clearance and App Store metadata evidence remain pre-release |
| `D0-002` | Positioning/claims | Nonmedical wellness and self-management; manual user input/action only; no diagnosis, detection, prediction, prevention, treatment, risk, emergency, or guarantee | `ADOPTED` | Named Claims/Legal approval of `CLAIMS-P1-001` |
| `D0-003` | Profile/onboarding | One local profile; first use asks no wellness questionnaire or login; fields limited to routing/notice metadata | `ADOPTED` | Product/Privacy approval and Figma mapping |
| `D0-004` | Guest/account boundary | Guest/local-first; optional account only when person chooses sync; RevenueCat/StoreKit commerce is independent of authentication | `ADOPTED` | Lifecycle/security approval and tests |
| `D0-005` | Minimum deployment target | Decide after physical matrix. Spike `TARGET-A` (iOS 26 minimum) first; compare lower-target fallback only if required coverage warrants it. | `PROPOSED` | Product coverage target plus iOS/QA physical evidence |
| `D0-006` | Bedtime alarm | AlarmKit when supported/proven; system state is authority. Notification fallback exists only if lower target is approved and is labeled distinctly. | `ADOPTED DIRECTION` | Physical matrix, exact target/fallback/copy |
| `D0-007` | Locked/manual entry surface | Manual user-initiated route only; select AlarmKit custom action/App Intent/Control/widget/deep link by measured privacy/accessibility/lifecycle result. | `ADOPTED PROCESS` | Disposable-spike evidence and selected surface |
| `D0-008` | Grounding/audio delivery | Minimum approved visual/audio bundle; optional larger secure download/cache; no streaming dependency | `ADOPTED DIRECTION` | Concrete catalog, rights, scripts, manifest, bundle budget, device evidence |
| `D0-009` | Voice/microphone | No personal/partner recording, upload, overnight/ambient monitoring, microphone permission, speech analysis, or input configuration | `ADOPTED; EXCLUDED` | Binary/manifest/source absence evidence |
| `D0-010` | Local/remote synchronization | GRDB immediate source; Supabase optional account sync with RLS, revisions, explicit conflicts, tombstones, and idempotent retry | `APPROVED DIRECTION — 25 JULY 2026` | Migrations, RLS, and isolation/deletion test evidence |
| `D0-011` | Paid feature boundary | One RevenueCat entitlement, `premium_access`; alarm plus required utilities are always free; every other feature is premium | `APPROVED BY SATYAM SHREE — 28 JULY 2026` | RevenueCat/StoreKit Sandbox and stressed-paywall evidence |
| `D0-012` | Trial model | Apple-managed three-day introductory free trial for eligible monthly/annual customers; one offer redemption per subscription group; no custom trial clock | `APPROVED BY SATYAM SHREE — 25 JULY 2026` | App Store Connect and Sandbox eligibility/conversion evidence |
| `D0-013` | History/insights | Submitted user entries and simple descriptive summaries only; no inferred/causal/risk/clinical content or streak pressure | `ADOPTED` | Claims/Design/Accessibility evidence |
| `D0-014` | Legal/support/data rights | Bundled and public privacy/terms/wellness/support; export/delete/account deletion/restore/manage/refund utilities outside premium | `ADOPTED` | Counsel-approved text/URLs and end-to-end evidence |
| `D0-015` | Check-in | Optional occurrence, intensity, present state, and note using the exact completed copy in `SPEC-P1-001 §8.3`; one entry per local date; seven-day local draft retention; no benefit/outcome questions | `APPROVED BY SATYAM SHREE — 25 JULY 2026` | Accessibility/localization implementation evidence |
| `D0-016` | Diagnostics | Minimal operational allowlist only; no check-in/wellness/free text/alarm time/listening history/account IDs; no tracking/ads | `ADOPTED DIRECTION` | Provider, legal basis/consent, processor terms, region, 30-day retention, traffic audit |
| `D0-017` | Retention/deletion | Entity-specific schedule in `DATA-P1-001`, immediate local hiding, sync tombstones, no resurrection, and distinct entry/local/account deletion | `OWNER-APPROVED — 25 JULY 2026` | Final entity/contact/legal-exception review plus backend tests |
| `D0-018` | Apple products | Monthly USD 8.99 and annual USD 59.99 auto-renewables in one group; lifetime USD 149.99 non-consumable; Family Sharing off; Apple Billing Grace Period off | `APPROVED BY SATYAM SHREE — 28 JULY 2026` | App Store Connect product IDs/localizations and Sandbox evidence |
| `D0-019` | Commercial authority/offline | Apple is purchase/payment authority; RevenueCat maps verified Apple state to `premium_access`; no custom or Apple billing grace; premium ends immediately when entitlement becomes inactive | `APPROVED BY SATYAM SHREE — 28 JULY 2026` | Offline/expiry/refund/revoke physical, RevenueCat, and Sandbox evidence |
| `D0-020` | Authentication method | Optional Supabase sync accounts offer only Sign in with Apple and Sign in with Google; email/password, passwordless email, phone, and OTP are excluded; guest/local-first remains available; linking requires explicit reauthentication | `APPROVED BY SATYAM SHREE — 28 JULY 2026` | Callback, collision, deletion, provider, and RLS test evidence |
| `D0-021` | Data after entitlement expiry | Never delete; ordinary premium access closes, but export/delete/account/purchase utilities remain | `APPROVED BY SATYAM SHREE — 25 JULY 2026` | Locked-state UX tests |
| `D0-022` | Remote incident controls | May disable a risky remote/content capability or use an Apple-supported offer; may not invent entitlement, disable alarm/data rights, delete data, or broaden collection | `APPROVED DIRECTION — 25 JULY 2026` | Security/Release runbook and runtime evidence |
| `D0-023` | Exact wording authority | The PRD `Phase 1 Userflow` tab is authoritative for exact strings that remain within approved Phase 1 scope and claims rules; contradictions and excluded capabilities require explicit disposition | `ADOPTED` | Content/Claims maps each shipping string to `S-PRD-P1-COPY` or a named approved revision |
| `D0-024` | Temporary placeholders | Planning and the disposable feasibility spike may use clearly labeled placeholder audio/assets and placeholder legal URLs; they are not production evidence or shipping content | `ADOPTED FOR CURRENT PHASE` | Real asset rights/content records and approved live legal/support URLs are required before their integration/release gates |
| `D0-025` | Legacy Figma disposition | Retain file/key/page/canvas evidence as discovery only; `SPEC-P1-001` supersedes all conflicting or unmappable legacy visual states; no Figma mutation | `APPROVED BY SATYAM SHREE — 25 JULY 2026` | New implementation must be reviewed against canonical screen/state/copy contracts |
| `D0-026` | Grounding content roles | Approve `AUD-SLOT-001` silent visual/text, `AUD-SLOT-002` short spoken track with transcript, and `AUD-SLOT-003` short nonverbal sound with silent/text equivalent; no personal voice recording | `APPROVED BY SATYAM SHREE — 25 JULY 2026` | Final scripts, audio, rights, mastering, and physical playback evidence before integration/release |
| `D0-027` | Privacy PDF | `Privacy_Policy.pdf` is a discovery template only and may not be published; replace its excluded microphone/voice/detection/AI/questionnaire/OTP/cloud-audio descriptions with actual Phase 1 practices | `APPROVED BY SATYAM SHREE — 25 JULY 2026` | Entity/address/contact, final legal wording, applicability review, and live URL |
| `D0-028` | RevenueCat role | Use RevenueCat for entitlement orchestration, offerings, and customer-information refresh; Apple remains the source of purchases, transaction truth, pricing, tax, and developer payouts. Invite collaborators instead of sharing credentials; public SDK keys may ship, secret keys/webhook secrets may not. | `APPROVED BY SATYAM SHREE — 28 JULY 2026` | Owner account, project, collaborator, App Store Connect, entitlement, offering, product, webhook/security, Sandbox, and physical evidence |
| `D0-029` | Audio asset availability | Satyam Shree reports candidate audio assets are available; no asset file, hash, script/transcript, rights record, or mastering evidence has entered the controlled intake yet. | `OWNER REPORTED — 28 JULY 2026` | Deliver assets through `assets/audio/incoming/` with the manifest and rights/provenance records required by `AUDIO-P1-001` |

## 3. Rejected alternatives

The following are explicitly rejected for Phase 1:

| ID | Rejected alternative | Reason/authority |
|---|---|---|
| `R0-001` | Sign-up-first/account-required onboarding | Conflicts with guest/local-first and App Review login minimization |
| `R0-002` | Multiple household/partner profiles | One local profile baseline; expands data/access complexity |
| `R0-003` | Voice recording/upload/share | Excluded data/permission/safety scope |
| `R0-004` | Automatic/overnight microphone detection | Excluded monitoring/detection; no truthful feasibility/claim basis |
| `R0-005` | Risk score renamed “wellness index” | Underlying inference remains prohibited |
| `R0-006` | HealthKit, Watch, Android, AI, community, clinician/telehealth | Explicit Phase 1 exclusions |
| `R0-007` | Custom app-clock “night” trial or seven-day trial | Replaced by the approved StoreKit three-day introductory offer |
| `R0-008` | Polar/custom/external payment unlock | Apple In-App Purchase controls the transaction; RevenueCat maps it to app access |
| `R0-009` | AWS Phase 1 backend | Supabase selected for optional account sync |
| `R0-010` | “HIPAA-ready,” prevention, protection, guaranteed calm/sleep claims | Unsupported legal/medical/outcome claims |
| `R0-011` | Remote APNs as default foundation | No approved Phase 1 remote-push need |
| `R0-012` | Fixed August/eight-week delivery promise | Evidence gates precede schedule commitment |
| `R0-013` | “You’re awake. You’re safe.” | App cannot verify either user state |
| `R0-014` | YouTube references as shipping audio catalog | No catalog/rights/provenance/integrity evidence |

Full source-level reconciliation is in
[SOURCE_RECONCILIATION.md](./SOURCE_RECONCILIATION.md).

## 4. Current Gate 0 blockers

| ID | Blocker | Owner | Exact evidence to close |
|---|---|---|---|
| `B0-004` | Commercial decisions are approved, but the RevenueCat account/project/collaborator configuration, App Store Connect products/banking prerequisites, and Sandbox evidence do not exist | Product + iOS + QA + Release | Create the RevenueCat project, invite the approved Satyam account, configure `premium_access` and the offering/products, complete Apple agreements/tax/banking in App Store Connect, disable billing grace, and capture eligibility, conversion, reminder, immediate cutoff, restore, expiry, refund, revoke, lifetime, and offline evidence |
| `B0-006` | `SUPA-P0-001` confirms the selected project but found no recorded migrations/Auth identities/Phase 1 schema; `public.waitlist` anonymously exposes email rows and permits unrestricted inserts; public `SECURITY DEFINER` `rls_auto_enable()` is executable by `anon` and `authenticated` | Backend + Security | Identify the waitlist owner/purpose; produce a reviewed versioned remediation; configure Apple/Google providers; implement approved schemas/policies; pass owner-positive, anonymous/other-user denial, forged-owner, expired/revoked-session, over-posted-field, abuse-control, and deletion/tombstone tests |
| `B0-007` | The attached privacy PDF is unusable; `PRIV-P1-002` and `LEGAL-P1-003` now record the supplied provider name, publication-date rule, age 13+, and United States scope, but still lack verification that the provider name is a legal contracting entity, mailing address, monitored contact mailboxes, Supabase region, governing law/venue, applicability review, and final approval | Satyam Shree as Privacy/Legal owner | Verify the entity, create/verify the address and mailboxes, identify project region and governing jurisdiction, then approve the drafts; publish/test URLs before release |
| `B0-008` | The disposable spike is published at commit `7fa790a`, but AlarmKit, manual surface, notification fallback, audio, lock, restart, time, and accessibility still lack hosted-Xcode and physical proof | iOS + QA/A11y + Design/Privacy | Connect the repository to Codemagic/App Store Connect, compile/sign/upload, distribute by internal TestFlight, run `FEAS-P1-001` on the confirmed iPhone, and use a borrowed/remote interactive Mac only if CI diagnostics are insufficient |
| `B0-010` | Exact App Store/release configuration does not exist | Release + iOS + Product | Stable toolchain/archive, metadata, privacy answers, review notes, TestFlight and production configuration |

The PRD and meeting evidence are no longer missing-source blockers. The exact
Phase 1 wording tab was reread and reconciled on 24 July 2026. Figma identity
and canvas-level evidence are available. Satyam Shree approved superseding the
legacy visual source with the canonical specification, so the unavailable
child hierarchy is no longer a controlling-source blocker.

## 5. Approval order

To avoid circular rework:

1. Replace the privacy template with actual legal entity/contact information.
2. Execute the isolated physical/TestFlight and StoreKit Sandbox spike.
3. Produce and test the Supabase RLS/auth/deletion design.
4. Record evidence-backed iOS, backend, security, accessibility, and release
   decisions; then sign the final Gate 0 record.

No blocker moves into production as “we will decide while implementing.”
