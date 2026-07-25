# Session Prompt: Phase 0 - Product, Claims, and Feasibility Lock

You are working in the SP / Paralux repository. This session is exclusively for **Phase 0: Product, claims, and feasibility lock**. Treat this prompt as the session's operating contract. Do not assume access to any earlier chat.

## Required outcome

Turn the available discovery artifacts into one implementable, testable, privacy-conscious Phase 1 contract and determine whether Gate 0 passes. Do not begin production feature implementation. A disposable platform spike is allowed only when needed to collect feasibility evidence and must remain clearly separated from production code.

## Start here

1. Inspect repository guidance (`AGENTS.md` or equivalent), repository status, and existing Phase 0 artifacts. Preserve unrelated/user-authored changes.
2. Read completely:
   - `docs/PHASE_1_EXECUTION_PLAN.md`
   - `docs/IOS_2026_BEST_PRACTICES.md`
   - `docs/SWIFT_SWIFTUI_BEST_PRACTICES.md`
   - every file in `docs/phase-0/`
   - the authoritative PRD, Figma source, technical plan, and meeting evidence when available.
3. Verify temporally unstable Apple/platform claims against current official Apple documentation. Use primary sources only and record the verification date.
4. Create a short working plan before modifying artifacts.

## Source authority

Apply this precedence order: applicable law and current official Apple requirements; approved repository decisions; the execution plan and engineering guides; the approved Phase 1 specification/acceptance matrix; technical plan; Figma visual intent; master PRD; meeting notes. Never elevate a lower-authority discovery statement over a later approved decision.

If sources conflict, record the conflict and apply the current approved/default direction. If a missing choice would substantially change the launch experience, data collected, claims, permission use, account model, or business model, ask the user before deciding. Make ordinary technical/document-structure choices with best judgment and record them.

## Adopted product direction

- Native iPhone app using Swift and SwiftUI.
- Non-medical wellness/self-management positioning; no diagnosis, detection, prediction, prevention, treatment, risk scoring, emergency-response promise, or guaranteed outcome.
- One local person profile; guest/local-first core use. Offer an account only for approved synchronization value.
- Manual user-initiated episode action only.
- Local-first SQLite/GRDB; account-scoped Supabase synchronization behind tested row-level security.
- Core promised offline behavior must not depend on Supabase.
- No personal/partner voice recording, overnight monitoring, microphone permission, HealthKit, Apple Watch app, Android app, AI analysis/coaching, community, clinician portal, or tracking.
- Bundle the minimum approved grounding content needed for offline use; a larger pre-sleep catalog may be securely downloaded/cached after approval.
- Ultra-light optional check-in only: episode occurrence, perceived intensity, recovery state, and optional note. Exact labels/options need copy, privacy, accessibility, localization, retention, edit/delete, and export approval.
- The alarm and mandatory utility routes remain free. All other functionality requires verified StoreKit premium access.
- Eligible monthly/annual customers may receive Apple's three-day introductory free trial. Lifetime is a separate non-consumable purchase. Do not implement a custom trial clock.
- Privacy/legal/support, export/deletion, applicable account deletion, purchase restoration, and subscription management remain accessible without entitlement.

## Required Phase 0 work

- Reconcile every available requirement into stable IDs with source and test traceability.
- Complete the profile/onboarding truth table and approved field-purpose inventory.
- Create the approved claims/copy matrix and remove/replace risk score, Guardian Mode, detection, prevention, and reduction language.
- Inventory all navigation, screens, and states: normal, loading, empty, offline, denied/revoked permission, unsupported/unavailable capability, error, retry, destructive confirmation, purchase, restore, trial eligibility/active/expired, subscription/lifetime/grace, entitlement loss, deletion, and recovery.
- Approve the data inventory, data-flow diagram, retention/deletion schedule, export behavior, analytics allowlist, and privacy categories.
- Specify guest ownership, guest-to-account conversion, sign-out/reinstall/token-expiry behavior, entity conflict policy, retry, tombstones, and deletion propagation.
- Approve the audio catalog, rights/provenance, bundled/downloaded manifest, integrity/cache/cleanup rules, and offline promise.
- Specify the commercial access matrix, StoreKit product/offer direction, verified offline/grace/clock-tampering behavior, refund/revocation behavior, and which surfaces disappear or gate when entitlement is absent. Never infer access from install/account date or Supabase.
- Produce the permission/entitlement register, initial threat model, content/safety/accessibility/privacy/security/analytics standards, and owner/sign-off register.
- Run or design the physical-device feasibility matrix for AlarmKit, UserNotifications fallback, Lock Screen controls/widgets, App Intents, audio while locked, interruptions/routes, app termination, restart, silent mode, and Focus.
- Lock the minimum deployment target only after feasibility evidence is complete.

## Feasibility evidence rule

Do not claim physical-device behavior from documentation, Simulator, or code inspection. If approved iPhones/OS versions are unavailable, create a reproducible test protocol and mark the corresponding result unverified. Never fabricate screenshots, logs, timings, or sign-off.

Any spike code must use the stable accepted Xcode toolchain, availability checks, strict concurrency, privacy-safe logging, no secrets, and focused tests. Keep it disposable and separate from the production architecture.

## Required deliverables

- Canonical Phase 1 product specification.
- Requirements-to-source-to-test matrix.
- Approved claims/copy matrix.
- Complete navigation and screen-state map.
- Platform feasibility report with device/OS evidence or explicit evidence blockers.
- Data inventory, retention schedule, and data-flow diagram.
- Permission and entitlement register.
- Initial threat model.
- Decision records for every execution-plan, trial/product/paywall, and check-in decision above.
- Gate 0 review record with named approvals or explicit blockers.

## Gate 0 completion rule

Do not mark Gate 0 passed unless every critical requirement is noncontradictory, every screen/system state has acceptance criteria, every collected field has full lifecycle rules, platform language matches physical evidence, the product contains no prohibited claim, the commercial access model is deterministic, and product/design/iOS/backend/QA/privacy/security/content/release owners approve the baseline.

## Handoff

End with: outcome delivered; files changed; decisions applied; sources verified; automated/document checks; physical-device evidence; accessibility/privacy/security impact; known limitations; unresolved blockers; whether Gate 0 passed; and the next safe Phase 1A work item. State exactly what remains unverified.
