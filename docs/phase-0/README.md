# Phase 0 Control Index

**Phase:** Product, claims, and feasibility lock  
**Status:** Documentation baseline complete; Gate 0 **NOT PASSED**  
**Baseline date:** 28 July 2026
**Implementation authority:** None. Phase 0 does not authorize production feature code.

## Outcome

The repository, the native Google Docs PRD, the full 15 July meeting notes and
transcript, and all three technical-plan DOCX files have been reconciled into a
single Phase 1 documentation baseline. The later
[Phase 1 execution plan](../PHASE_1_EXECUTION_PLAN.md), current Apple
requirements, and the direction in the Phase 0 session prompt control when
older sources conflict.

The result is specific enough to identify the remaining decisions and evidence
without allowing undocumented product assumptions into implementation. On 25
July the exact Figma file key and starting node were confirmed and all three
page canvases were rendered read-only. The audit found material visual/copy
conflicts, but child node IDs, component/variable properties, and prototype
reactions remain unavailable because hierarchy calls time out or fail. Satyam
Shree approved superseding that legacy discovery source with the canonical
specification. Product-accurate replacement privacy/legal/support drafts now
exist. Gate 0 remains blocked by their factual/legal verification and approval,
Supabase/RLS evidence, RevenueCat/StoreKit/App Store configuration evidence, and the
physical-device feasibility matrix.

On 24 July, the exact `Phase 1 Userflow` wording tab was reread. On 28 July,
Apple/Google-only account methods and RevenueCat entitlement orchestration
were selected, and clearly labeled
audio/asset and privacy/legal-URL placeholders were authorized for current
planning. Shipping assets, rights, legal text, and live URLs remain later
integration/release dependencies.

## Controlling direction

- Native iPhone app using Swift and SwiftUI.
- Nonmedical wellness and self-management positioning.
- Manual, user-initiated experience only. No automatic detection, inference,
  prediction, prevention, treatment, risk scoring, emergency response, or
  outcome guarantee.
- One local profile. Guest/local-first use; an account is optional and exists
  only for approved synchronization.
- Optional sync accounts use Supabase Auth with Sign in with Apple and Sign in
  with Google only.
- SQLite through GRDB is the immediate source of truth. Supabase supplies
  account-scoped synchronization protected by Row Level Security.
- Core preparation, alarm, manual action, grounding, and local data remain
  honest about their offline behavior.
- No microphone or voice recording, overnight monitoring, HealthKit, Apple
  Watch target, Android target, AI feature, community, clinician, advertising,
  or cross-app tracking in Phase 1.
- A minimal approved grounding set is bundled. Any larger catalog is an
  optional, integrity-checked download. Current planning and the disposable
  spike may use owned, clearly labeled placeholders; placeholders cannot ship.
- The optional check-in is limited to one editable entry per local night:
  occurrence, optional perceived intensity, optional present state, and an
  optional private note using the approved copy in `SPEC-P1-001`.
- The alarm is always free. Every other product feature requires active
  RevenueCat `premium_access` backed by an Apple trial, monthly/annual
  subscription, or lifetime non-consumable. There is no billing or custom
  grace; premium ends immediately when that entitlement becomes inactive.
- Approved United States prices are monthly USD 8.99, annual USD 59.99, and
  lifetime USD 149.99. Eligible monthly/annual customers receive Apple's
  three-day introductory free trial.
- Privacy, legal, support, data export/deletion, applicable account deletion,
  purchase restoration, subscription management, and refund help never depend
  on premium entitlement.

## Artifact set

| Artifact | Purpose | Approval state |
|---|---|---|
| [Source reconciliation](./SOURCE_RECONCILIATION.md) | Source authority, revision evidence, conflicts, and exclusions | Figma/user-flow/privacy conflicts dispositioned |
| [Figma read-only audit](./FIGMA_READ_ONLY_AUDIT.md) | Exact MCP evidence, canvas-level inventory, stable-ID reconciliation, conflicts, and missing states | `PARTIAL` evidence retained; legacy source superseded; no Figma mutation |
| [Privacy policy asset review](./PRIVACY_POLICY_ASSET_REVIEW.md) | Full 16-page policy-template review and required corrections | Supplied PDF rejected for publication |
| [Replacement privacy-policy draft](./PRIVACY_POLICY_PHASE_1_DRAFT.md) | Product-accurate Phase 1 policy content and publication checklist | Entity/contact/territory/region and legal review pending |
| [Canonical Phase 1 product specification](./CANONICAL_PHASE_1_PRODUCT_SPEC.md) | Phase 1 boundary, journeys, onboarding truth table, fields, acceptance contract | Product owner approved v0.12 |
| [Requirements traceability matrix](./REQUIREMENTS_TRACEABILITY_MATRIX.md) | Stable requirement IDs, sources, and acceptance evidence | Baseline; legacy Figma is non-controlling |
| [Test and source traceability catalog](./TEST_AND_SOURCE_TRACEABILITY.md) | Stable test IDs and requirement-to-test rules | Baseline |
| [Claims and copy matrix](./CLAIMS_AND_COPY_MATRIX.md) | Allowed, conditional, prohibited, and approved copy direction | Owner direction approved; legal/release evidence pending |
| [Navigation and state map](./NAVIGATION_AND_STATE_MAP.md) | Route inventory, state inventory, transitions, and screen acceptance criteria | Canonical text contract controls |
| [Data lifecycle and sync contract](./DATA_LIFECYCLE_AND_SYNC_CONTRACT.md) | Field inventory, flows, retention, export, deletion, diagnostics, and sync | Owner defaults approved; Supabase evidence pending |
| [Legal, wellness, and support copy draft](./LEGAL_AND_SUPPORT_COPY_DRAFT.md) | Product-accurate wellness, alarm, purchase, account, deletion, support, and Terms drafting copy | Factual/legal values and approval pending |
| [Audio and offline contract](./AUDIO_AND_OFFLINE_CONTRACT.md) | Catalog, rights, manifest, integrity, cache, playback, and offline behavior | Three roles approved; final rights/device evidence pending |
| [Commercial access and permissions](./COMMERCIAL_ACCESS_AND_PERMISSIONS.md) | StoreKit products, access states, trial, permissions, and entitlements | Product/Finance approved; App Store/Sandbox/device evidence pending |
| [RevenueCat integration contract](./REVENUECAT_INTEGRATION_CONTRACT.md) | Apple/RevenueCat responsibility split, entitlement/offering map, keys, collaboration, cutoff, and reminder rules | Product direction approved; account/App Store/Sandbox/device evidence pending |
| [Threat model and standards](./THREAT_MODEL_AND_STANDARDS.md) | Assets, boundaries, threats, mitigations, standards, owners, and sign-off | Satyam Shree assigned; evidence-backed approvals pending |
| [Platform feasibility report](./PLATFORM_FEASIBILITY_REPORT.md) | Deployment-target options, disposable-spike protocol, physical-device matrix | Package published at `7fa790a`; hosted Xcode/TestFlight/device execution pending |
| [Decision and conflict register](./OPEN_DECISIONS_AND_CONFLICTS.md) | Adopted decisions, proposals awaiting approval, retired conflicts, blockers | Current |
| [Gate 0 review](./GATE_0_REVIEW.md) | Pass/fail record, exact blockers, owner actions, and Phase 1A handoff | **NOT PASSED** |

## Source authority

1. Current Apple requirements and platform documentation, verified
   23 July 2026.
2. The explicit Phase 0 session prompt and its adopted product direction.
3. [Phase 1 execution plan](../PHASE_1_EXECUTION_PLAN.md).
4. [iOS 2026 best practices](../IOS_2026_BEST_PRACTICES.md) and
   [Swift/SwiftUI best practices](../SWIFT_SWIFTUI_BEST_PRACTICES.md).
5. Approved decisions recorded in this folder.
6. Figma as superseded discovery evidence, using the evidence levels and
   limitations in [FIGMA-P0-001](./FIGMA_READ_ONLY_AUDIT.md); it cannot
   override the approved canonical contract.
7. The PRD `Phase 1 Userflow` tab for exact wording that remains inside the
   approved scope and claims boundary.
8. The rest of the PRD, meeting evidence, and older technical plan as discovery
   input.

## Status vocabulary

| Status | Meaning |
|---|---|
| `BASELINE` | Required by a controlling source; acceptance evidence is still required. |
| `ADOPTED` | Product direction is selected; this is not Gate approval. |
| `PROPOSED` | A deterministic recommendation is documented but an accountable owner must approve it. |
| `BLOCKED` | Required evidence or authority is unavailable. |
| `CONDITIONAL` | Applies only when its parent capability is enabled. |
| `EXCLUDED` | Outside Phase 1; reopening requires formal change control. |

## Gate rule

No production feature implementation begins until
[Gate 0](./GATE_0_REVIEW.md) is changed to `PASSED` with links to:

- explicit design-source disposition and an approved canonical screen/state
  contract;
- corrected privacy/legal wording plus approved claims, fields, retention,
  products, and placeholder/shipping-audio boundary;
- deterministic lifecycle and entitlement behavior;
- physical-device evidence for AlarmKit, manual locked entry, notifications,
  audio, interruption, restart, and clock/time-zone changes; and
- named Product, Design, iOS, Backend, Content/Claims, Privacy/Legal, Security,
  Accessibility/QA, and Release approvals.

The next safe technical work after Gate 0 is Phase 1A foundation only. A
disposable platform spike may run before Gate 0 solely under the isolated
protocol in the feasibility report; it must not enter the production target.
