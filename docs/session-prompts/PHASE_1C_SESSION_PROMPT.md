# Session Prompt: Phase 1C - Design System, App Shell, and Onboarding

You are working in the SP / Paralux repository. This session is exclusively for **Phase 1C: Design system, app shell, and onboarding**. Treat this prompt as the session's operating contract. Do not assume access to earlier chat.

## Entry gate

Read the execution plan, both engineering guides, approved Phase 0 product/copy/data/state artifacts, and Phase 1A/1B handoffs. Inspect repository guidance and `git status`; preserve unrelated changes. Confirm all entry gates required by the execution plan are passed. If requirements, approved copy, Figma states, or data fields are missing, stop that workstream at specification rather than inventing them.

## Objective

Deliver a coherent, accessible app shell and the shortest safe guest-first path to useful sleep preparation, using only approved wellness copy and contextual permissions.

## Adopted product constraints

- Non-medical wellness positioning; never use detection, prediction, prevention, treatment, risk score, Guardian Mode, episode-reduction, emergency, or guarantee language.
- One local person profile.
- Guest/local-first core use; account creation appears only when approved sync value is explained.
- Ultra-light check-in exists later but must not be front-loaded into onboarding.
- No microphone, HealthKit, Watch, tracking, or other excluded permission.
- Only the alarm and mandatory utilities are free; other features use the shared StoreKit access-policy boundary. Do not lead onboarding with a paywall or purchase request, and show three-day trial copy only when StoreKit confirms eligibility.
- Privacy/legal/support, export/deletion, applicable account deletion, purchase restoration, and subscription-management controls remain reachable regardless of entitlement.

## Required implementation

- Implement reusable semantic design components and tokens; do not create screen-specific clones where a shared role exists.
- Build value-based `NavigationStack` routing with typed routes, identifiable presentations, direct-entry handling, and restorable/testable state.
- Implement approved welcome, value explanation, wellness disclaimer, essential preference setup, and permission education.
- Implement the approved one-profile onboarding truth table using only approved minimal fields and purposes.
- Defer account creation and optional/nonessential questions. Explain sync value before any account route.
- Request notification or AlarmKit authorization only after the user chooses the related schedule/alarm feature and immediately before it is needed.
- Provide stable denial/revocation/unsupported fallbacks and an appropriate Settings route after denial.
- Persist onboarding progress outside transient view state and recover to a valid step after termination, invalid route, or app update.
- Integrate the shared access-policy presentation seam without implementing StoreKit/paywall internals in this phase. The alarm path must remain ungated.
- Implement every approved state: loading, empty, offline, denied/revoked, unsupported capability, error, retry, destructive confirmation where applicable, trial/premium/expired access messaging, and recovery.

## Swift/SwiftUI quality rules

- Views render state and send intents; feature models coordinate one feature only; domain/platform/data work stays behind focused interfaces.
- UI-facing state is `@MainActor`; use Observation deliberately and never treat `@State` as persistent storage.
- Use structured concurrency with owned task lifetime and cancellation. Do not patch isolation with dispatch queues or unsafe annotations.
- Use native semantic controls, stable IDs, adaptive layout, localization-ready complete strings, and no fixed text frames.
- No forced unwraps/casts, empty catches, raw backend errors, hidden side effects in destination builders, Boolean navigation soup, or production-only test branches.
- Add meaningful previews using inert test dependencies for normal, loading, empty, error, offline, permission, large text, and dark/light states. Previews never contact Supabase, request permission, schedule alarms, or purchase.

## Accessibility acceptance

- Verify VoiceOver name/role/value/hint/order/actions and focus after navigation, errors, permission results, and asynchronous changes.
- Support all approved Dynamic Type accessibility sizes without clipped critical controls.
- Honor Reduce Motion/Transparency; do not communicate state only with color, shape, sound, or motion.
- Verify Voice Control, Switch Control, increased contrast, right-to-left layout, keyboard behavior where relevant, and comfortable one-handed targets.

## Tests/evidence

- Guest completes onboarding and reaches usable home/sleep preparation without account creation.
- Every optional permission can be denied/revoked without trap, crash, or unrelated feature lock.
- Every onboarding branch and restoration point is covered with parameterized tests.
- Direct entry, back/dismiss, deep links, auth/access changes, stale routes, and relaunch are deterministic.
- Approved copy and screenshot audit contains no prohibited claim or unapproved purchase/trial language.
- Accessibility evidence covers every onboarding step and shell state.

## Gate 1C exit

Pass only when a guest reaches useful state, permission denial is safe, interrupted onboarding restores correctly, all text sizes remain operable, and implementation/copy/screens match the approved Phase 0 contract.

## Handoff

Report requirement IDs, outcome, files changed, Figma nodes/states implemented, decisions used, automated/manual/accessibility evidence, privacy/data impact, known limitations, blockers, whether Gate 1C passed, and the next safe Phase 1D work item. State what remains unverified.
