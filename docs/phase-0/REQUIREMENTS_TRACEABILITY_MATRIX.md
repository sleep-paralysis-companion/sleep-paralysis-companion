# Phase 1 Requirements Traceability Matrix

> **Phase 1 change control - 29 July 2026.** Requirements that exclude questionnaire/persona collection, personal audio, recording, microphone permission, or authenticated onboarding are superseded by [Persona and Personal Audio Product Realignment](./PERSONA_AND_PERSONAL_AUDIO_REALIGNMENT.md). A traceability-matrix delta is required before implementation; current rows remain historical baseline traceability.

**Status:** Baseline v0.9 - Gate 0 not passed  
**Prepared:** 21 July 2026  
**Last updated:** 28 July 2026
**Change rule:** IDs are stable. Retire an ID instead of reusing it for a different requirement.

## How to read this matrix

- Source IDs are defined in [Source reconciliation](./SOURCE_RECONCILIATION.md); `D0-*` decisions are defined in [Decision, conflict, and blocker register](./OPEN_DECISIONS_AND_CONFLICTS.md).
- Each `P1-AREA-NNN` requirement maps to stable tests using `T-AREA-NNN-METHOD[-CASE]` as defined in [Test and source traceability](./TEST_AND_SOURCE_TRACEABILITY.md).
- `Figma` records legacy visual trace only. `Pending` means no concrete legacy
  node/state mapping was recoverable; under `D0-025` this is not a controlling
  requirement or Gate blocker. `N/A` means the requirement is nonvisual.
- The evidence column defines the minimum acceptance evidence; it is not evidence that the requirement has already passed.
- `Physical` means proof from the approved device/OS matrix, not Simulator-only evidence.
- Requirements marked `BLOCKED` or `CONDITIONAL` cannot authorize implementation. A former `PROVISIONAL` requirement moved to `BASELINE` only where the 23 July default direction settled the product choice; its acceptance evidence may still be pending.

The read-only [Figma audit](./FIGMA_READ_ONLY_AUDIT.md) provides
canvas-level conflict and missing-state evidence for visual `P1-*`
requirements. It does not change any `Figma` cell from `Pending`: child node
IDs, exact text layers, component/variable properties, and prototype reactions
were not returned by the connector. Satyam Shree approved superseding that
legacy source with the canonical contracts.

## Onboarding and product positioning

| ID | Requirement | Status | Sources | Figma | Minimum acceptance evidence |
|---|---|---|---|---|---|
| `P1-ONB-001` | Present the app as a non-medical sleep-wellness and self-management companion. | `BASELINE` | `S-EXEC` §§2, 5; `S-IOS` §2 | Pending | Content review covers onboarding, metadata, notifications, extensions, paywalls, and support copy; prohibited-claim search returns no unresolved result. |
| `P1-ONB-002` | Do not claim to diagnose, detect, predict, prevent, treat, cure, or medically reduce sleep paralysis. | `BASELINE` | `S-EXEC` §§2, 4.2, 5; `S-IOS` §2 | Pending | Approved claims matrix plus repository/binary/metadata copy audit. |
| `P1-ONB-003` | Let a new user reach a usable preparation/grounding path without unnecessary account creation. | `BASELINE` | `S-EXEC` §§4.1, 6, Phase 1C; `S-APPLE-ARG` §5.1.1(v); `S-IOS` §8; `D0-004` | Pending | UI test and manual flow prove guest completion; no identity request blocks the core path. |
| `P1-ONB-004` | Use one local person profile in Phase 1. | `BASELINE` | `S-EXEC` §6; `D0-003` | Pending | Approved field inventory and onboarding truth-table tests cover every branch. |
| `P1-ONB-005` | Collect only essential setup information with an approved purpose for every field. | `BASELINE` | `SPEC-P1-001` §7.1; `DATA-P1-001` §3 | Pending Phase 1C verification | Canonical five-field onboarding allowlist with purpose, sensitivity, storage, retention, export, and deletion mapping. |
| `P1-ONB-006` | Request permissions only in context immediately before the feature needs them. | `BASELINE` | `S-EXEC` §§5, 9.2; `S-APPLE-ARG` §5.1.1(iv); `S-IOS` §5 | Pending | Permission matrix tests not-determined, allowed, denied, restricted where applicable, revoked, reinstall, and Settings changes. |
| `P1-ONB-007` | Denial of every optional permission leaves a truthful, usable, non-coercive fallback. | `BASELINE` | `S-EXEC` Phase 1C; `S-IOS` §§5.4, 10.1 | Pending | UI tests plus manual denial/revocation flows; no repeated prompt, trap, crash, or unrelated feature lock. |
| `P1-ONB-008` | Relaunch during onboarding restores a valid step and state. | `BASELINE` | `S-EXEC` Phase 1C; `S-SWIFT` §§9, 15 | Pending | State-restoration tests for every step, termination, deep link, and invalidated route. |
| `P1-ONB-009` | Reconcile the exact onboarding questions and branch logic before implementation. | `BASELINE` | `SPEC-P1-001` §§6.1, 7.1; `NAV-P1-001` `SCR-002`–`SCR-004` | Pending Phase 1C verification | Canonical flow contains no questions: Welcome → boundary/privacy summary → atomic guest profile → Home. |

## Sleep preparation, schedule, reminders, and audio

| ID | Requirement | Status | Sources | Figma | Minimum acceptance evidence |
|---|---|---|---|---|---|
| `P1-SLP-001` | Let the user create, edit, disable, and inspect a bedtime schedule. | `BASELINE` | `S-EXEC` §§4.1, Phase 1D | Pending | Unit/UI tests cover create/edit/disable/relaunch and invalid inputs. |
| `P1-SLP-002` | Preserve user-intended wall-clock schedules across time-zone and daylight-saving changes. | `BASELINE` | `S-EXEC` Phase 1D; `S-SWIFT` §13 | Pending | Parameterized calendar/time-zone/DST tests plus physical clock-change scenarios. |
| `P1-SLP-003` | Distinguish an AlarmKit alarm, ordinary notification, and in-app reminder in UI and copy. | `BASELINE` | `S-EXEC` §§5, 6, Phase 1D; `S-IOS` §§1.2, 6.1 | Pending | Copy review and physical behavior matrix show that no fallback is represented as equivalent to an alarm. |
| `P1-SLP-004` | Use AlarmKit where supported and proven, with an honestly labeled notification/in-app fallback elsewhere. | `BASELINE` | `S-EXEC` §§6, Phase 1D; `S-APPLE-ALARM`; `S-IOS` §§1.2, 5.1, 6.1; `D0-006` | Pending | Physical tests cover each supported OS, authorization state, lock, silent mode, Focus, restart, and fallback. |
| `P1-SLP-005` | If Product approves a check-in reminder, it uses notification authorization independently from AlarmKit authorization and remains optional. | `CONDITIONAL` | `S-EXEC` §9.2; `S-IOS` §5.2 | Pending | Approved reminder purpose/copy plus permission and scheduling tests cover separate authorization state changes, denial, revocation, and removal. |
| `P1-SLP-006` | Bundle the minimum approved offline grounding content and use approved secure download/cache behavior for any larger pre-sleep catalog. | `BLOCKED` | `S-EXEC` §§4.1, 6, Phase 0, Phase 1D; `D0-008` | Pending | Approved catalog, rights/provenance record, package/download manifest, cache limits, integrity and cleanup tests. |
| `P1-SLP-007` | Previously available promised audio remains usable without network access. | `BASELINE` | `S-EXEC` §§4.1, 5, Phase 1D; `S-IOS` §§3.3, 7 | Pending | Offline launch/playback tests after install/download, backend outage, cache cleanup, and corrupted/missing asset. |
| `P1-SLP-008` | Playback handles interruptions, route changes, headphones, Bluetooth, calls, Siri, alarms, lock, background, and termination according to a documented state model. | `BASELINE` | `S-EXEC` Phase 1D; `S-APPLE-AUDIO`; `S-IOS` §7 | Pending | Unit state-machine tests plus the physical audio route/interruption matrix. |
| `P1-SLP-009` | Do not surprise the user with automatic audio after interruption; resume only when system guidance and prior intent allow it. | `BASELINE` | `S-EXEC` Phase 1D; `S-APPLE-AUDIO`; `S-IOS` §7 | Pending | Physical interruption tests verify resume/non-resume decisions and visible state. |
| `P1-SLP-010` | Provide visible or textual equivalents for essential audio information. | `BASELINE` | `S-EXEC` §§5, 9.4, Phase 1D; `S-IOS` §10.3 | Pending | Accessibility review verifies silent use, captions/text alternatives, and VoiceOver output. |
| `P1-SLP-011` | Audio playback must not activate or require the microphone. | `BASELINE` | `S-EXEC` §§4.2, 5, Phase 1D; `S-IOS` §5.3 | N/A | Entitlement/purpose-string/binary audit and on-device privacy indicator observation show no microphone access. |

## Manual episode action

| ID | Requirement | Status | Sources | Figma | Minimum acceptance evidence |
|---|---|---|---|---|---|
| `P1-ACT-001` | Episode support is initiated only by an explicit user action; no model, sensor, timer, or background process detects or infers an episode. | `BASELINE` | `S-EXEC` §§2, 4.1, 4.2, 5, Phase 1E; `S-PRD-P1-COPY`; `D0-023` | Pending | Architecture/data-flow review, behavior tests, and copy audit prove there is no detector or implied detection; “I just had an episode” remains an intentional self-report. |
| `P1-ACT-002` | Select a supported App Intent/control/widget/deep-link entry surface only after a physical-device feasibility spike. | `BLOCKED` | `S-EXEC` §§6, Phase 0, Phase 1E; `S-APPLE-INTENT`; `S-IOS` §§6.2-6.3 | Pending | Approved feasibility report identifies surfaces, OS support, unlock/authentication needs, latency, and fallback. |
| `P1-ACT-003` | The chosen action reaches useful local grounding with no network and the main app not already running. | `BASELINE` | `S-EXEC` Phase 1E; `S-IOS` §§3.3, 6.2-6.3 | Pending | Physical locked/unlocked, offline, terminated, backgrounded, and stale-deep-link tests. |
| `P1-ACT-004` | Repeated activation is idempotent and cannot create duplicate records or overlapping audio. | `BASELINE` | `S-EXEC` §§9.5, Phase 1E; `S-SWIFT` §16 | Pending | Automated concurrency/idempotency tests plus repeated-tap physical test. |
| `P1-ACT-005` | Do not create an episode record unless the approved UX makes the user action and result clear. | `BASELINE` | `S-EXEC` Phase 1E | Pending | UI and persistence tests cover launch, cancel, repeated activation, and explicit record creation. |
| `P1-ACT-006` | Lock Screen/widget/control content uses neutral wording and exposes no episode details, profile answers, or private history. | `BASELINE` | `S-EXEC` §§5, 9; `S-IOS` §§6.1, 6.4 | Pending | Locked-device visual/privacy review across notification previews and configured visibility states. |

## Grounding flow

| ID | Requirement | Status | Sources | Figma | Minimum acceptance evidence |
|---|---|---|---|---|---|
| `P1-GRD-001` | Enter a calm, low-cognitive-load grounding flow with minimal interaction steps and visual density. | `BASELINE` | `S-EXEC` §§2, 4.1, Phase 1E | Pending | Approved task-flow step budget plus moderated usability evidence on target devices. |
| `P1-GRD-002` | Start with locally available grounding content; network enrichment never blocks entry. | `BASELINE` | `S-EXEC` §§4.1, 5, Phase 1E; `S-IOS` §3.3 | Pending | Offline/poor-network/backend-outage physical tests meet the approved entry and audio-start thresholds. |
| `P1-GRD-003` | Support approved audio, readable visual instructions, and a silent mode; use haptics only when appropriate. | `BASELINE` | `S-EXEC` Phase 1E; `D0-008` | Pending | Approved modality/content specification and accessibility/device tests for each mode. |
| `P1-GRD-004` | Provide an unobtrusive exit and an optional route to later check-in; never force logging. | `BASELINE` | `S-EXEC` Phase 1E | Pending | UI tests cover exit, dismiss, relaunch, optional check-in, and no-record paths. |
| `P1-GRD-005` | Recover deterministically from interruption, unavailable extension, authentication, app termination, and stale deep links. | `BASELINE` | `S-EXEC` §§7.3, 9.5, Phase 1E | Pending | Failure/recovery matrix plus physical evidence for every supported entry surface. |
| `P1-GRD-006` | Do not imply emergency response, guaranteed rescue, prevention, treatment, or guaranteed outcome. | `BASELINE` | `S-EXEC` §§2, 4.2, 5, Phase 1E | Pending | Claims/copy review across UI, extensions, notifications, metadata, support, and screenshots. |

## Morning check-in and personal history

| ID | Requirement | Status | Sources | Figma | Minimum acceptance evidence |
|---|---|---|---|---|---|
| `P1-CHK-001` | The morning check-in is optional and stores only user-entered information. | `BASELINE` | `S-EXEC` §§2, 4.1, Phase 1F; `S-PRD-P1-COPY` | Pending | Data-flow review plus UI/persistence tests prove no inferred or automatically created response. |
| `P1-CHK-002` | Limit the optional ultra-light check-in to episode occurrence, perceived intensity, present state, and an optional note. | `BASELINE` | `S-EXEC` §§6, 9.3, Phase 0; `S-PRD-P1-COPY`; `D0-015`; `D0-023` | Pending | Adopted occurrence/present-state copy plus approved intensity prompt, note label, data inventory, privacy/retention mapping, localization, accessibility, and copy/state specification. |
| `P1-CHK-003` | Support skip, partial completion, explicit submission, editing, and deletion for the ultra-light check-in. | `BASELINE` | `S-EXEC` Phase 1F; `D0-015` | Pending | Approved partial-record semantics plus UI/persistence tests for skip, partial, submit, edit, delete, relaunch, and sync. |
| `P1-CHK-004` | Distinguish no entry, unanswered/partial, and a negative answer. | `BASELINE` | `S-EXEC` Phase 1F | Pending | Domain and rendering tests cover missing, null/unknown, false, partial, duplicate, edited, and deleted data. |
| `P1-CHK-005` | Handle locale, calendar, clock, and daylight-saving changes consistently. | `BASELINE` | `S-EXEC` Phase 1F; `S-SWIFT` §13 | Pending | Parameterized date/calendar/time-zone tests and relaunch/sync scenarios. |
| `P1-HIS-001` | Show only descriptive user-entered history and mathematically honest summaries. | `BASELINE` | `S-EXEC` §§4.1, 6, Phase 1F | Pending | Data fixtures and copy review prove no prediction, risk tier, diagnosis, causation, or treatment inference. |
| `P1-HIS-002` | Avoid streak pressure, shame, causal claims, and risk classification. | `BASELINE` | `S-EXEC` Phase 1F | Pending | Approved content review over all history states and notifications. |
| `P1-HIS-003` | History agrees with persisted data after relaunch, offline edits, sign-in/out, sync, conflicts, and deletion. | `BASELINE` | `S-EXEC` Phase 1F; `S-SWIFT` §16 | Pending | Deterministic integration tests cover every lifecycle and synchronization transition. |
| `P1-HIS-004` | Charts or summaries include a nonvisual textual equivalent. | `BASELINE` | `S-EXEC` §§5, 9.4, Phase 1F | Pending | VoiceOver and accessibility review validates reading order, meaning, and equivalence. |

## Settings, privacy, identity, and purchases

| ID | Requirement | Status | Sources | Figma | Minimum acceptance evidence |
|---|---|---|---|---|---|
| `P1-SET-001` | Provide approved schedule, audio, notification, accessibility, privacy, data, support, conditional account, purchase restoration, and subscription-management controls. | `BASELINE` | `S-EXEC` §§4.1, Phase 1G; `D0-004`; `D0-011`; `D0-012` | Pending | Settings inventory maps each control to state ownership, effect, persistence, entitlement behavior, failure, and test. |
| `P1-SET-002` | Display actual system authorization state and link to iOS Settings only when appropriate. | `BASELINE` | `S-EXEC` §§9.2, Phase 1G; `S-IOS` §5 | Pending | Manual tests change permissions outside the app and verify foreground/background refresh and recovery. |
| `P1-SET-003` | Users can export approved user data in an understandable documented format. | `BASELINE` | `S-EXEC` §§5, 9.3, Phase 1G | Pending | End-to-end export reconciliation against local/remote inventory, including offline and failure states. |
| `P1-SET-004` | Users can delete individual records and all local data according to the approved retention contract. | `BASELINE` | `S-EXEC` §§5, 9.3, Phase 1G | Pending | End-to-end deletion tests cover rows, files, caches, queued changes, tombstones, and interrupted operations. |
| `P1-SET-005` | If accounts can be created, users can initiate complete account deletion in-app. | `CONDITIONAL` | `S-EXEC` §§5, 6, Phase 1G; `S-APPLE-ARG` §5.1.1(v); `S-APPLE-DELETE` | Pending | End-to-end deletion covers reauthentication, local/remote data, tokens, retained-data disclosure, interruption, and completion notice. |
| `P1-SET-006` | Publish and link approved privacy policy, terms, support, and account-deletion information. | `BASELINE` | `S-EXEC` §§6, Phase 1G; `S-APPLE-ARG` §5.1.1(i) | Pending | Public URL availability, in-app link, content-owner approval, and observed-data reconciliation. |
| `P1-SET-007` | Keep the alarm and required utility routes free; require active RevenueCat `premium_access`, backed by an eligible Apple three-day trial, active subscription, or lifetime purchase, for every other feature. | `OWNER APPROVED` | `D0-011`; `D0-012`; `D0-018`; `D0-028`; `COM-P1-001`; `RC-P1-004` | Pending | RevenueCat and StoreKit tests cover eligible/ineligible trial presentation, conversion, expiry, offline signed expiration, alarm continuity, and noncoercive paywall behavior. |
| `P1-SET-008` | Offer monthly USD 8.99, annual USD 59.99, and lifetime USD 149.99 through Apple; disable billing/custom grace, end premium immediately when verified entitlement becomes inactive, and begin an in-app reminder at most 72 hours before a known nonrenewing expiration. Keep restoration, management, privacy/legal/support, export/deletion, and account deletion accessible without entitlement. | `OWNER APPROVED` | `S-APPLE-ARG` §3.1; `D0-011`; `D0-018`; `D0-019`; `D0-028`; `RC-P1-004` | Pending | App Store Connect, RevenueCat, Sandbox, and TestFlight evidence covers purchase, pending, cancel, Ask to Buy, trial, plan change, renewal, retry without grace, known-expiration reminder, lifetime, refund, revoke, restore, reinstall, multiple devices, and absence of Family Sharing. |

## Optional account authentication

| ID | Requirement | Status | Sources | Figma | Minimum acceptance evidence |
|---|---|---|---|---|---|
| `P1-AUTH-001` | Keep guest/local-first use available; authentication is offered only when the person chooses synchronization or account management. | `BASELINE` | `S-EXEC` §§4.1, 6; `D0-004`; `D0-020` | Pending | Clean-install and account-flow tests prove no login blocks local core use and no guest data uploads before explicit conversion. |
| `P1-AUTH-002` | Offer only Sign in with Apple and Sign in with Google for optional synchronization. | `OWNER APPROVED` | `S-PRD-P1-COPY`; `D0-020` | Pending | Approved provider configuration and UI tests cover success, cancellation, provider error, offline state, and usable guest fallback for both methods. |
| `P1-AUTH-003` | Define deterministic linking/collision behavior when Apple or Google identifies an existing account; never merge identities or data silently. | `BLOCKED` | `D0-010`; `D0-020` | Pending | Security-approved identity table and integration tests cover same-email/different-provider, hidden Apple email, already-linked provider, reauthentication, replay, and cross-account denial. |
| `P1-AUTH-004` | Do not offer email/password, passwordless email, phone, or OTP authentication in Phase 1. | `OWNER APPROVED` | `D0-020`; `S-IOS` §4 | Pending | Provider configuration, UI/source inspection, and integration tests prove only Apple and Google can create or authenticate an optional sync account. |
| `P1-AUTH-005` | Account deletion and sign-out revoke the applicable Supabase sessions and Apple/Google authorization state without cancelling an Apple subscription. | `BASELINE` | `S-APPLE-DELETE`; `D0-017`; `D0-020` | Pending | End-to-end tests prove session/provider revocation, local-data choice, remote deletion, restart safety, and separate subscription messaging. |

## Local-first operation and synchronization

| ID | Requirement | Status | Sources | Figma | Minimum acceptance evidence |
|---|---|---|---|---|---|
| `P1-OFF-001` | SQLite through GRDB is the immediate source for user-visible core data. | `BASELINE` | `S-EXEC` §§4.1, 4.3, 5; `S-IOS` §3.3 | N/A | Repository/integration tests show core screens read/write local state without Supabase availability. |
| `P1-OFF-002` | The core preparation, manual action, grounding, check-in, and local history paths remain useful during network loss as specified. | `BASELINE` | `S-EXEC` §§4.1, 5, 9; `S-IOS` §3.3 | Pending | End-to-end offline/degraded/backend-outage matrix with clear state and no data loss. |
| `P1-OFF-003` | Local migrations are versioned and recover safely from interruption or storage failure. | `BASELINE` | `S-EXEC` §§9.5, Phase 1B; `S-SWIFT` §16 | N/A | Migration, rollback/recovery, full-storage, corrupt-asset, and interrupted-transaction tests. |
| `P1-SYN-001` | Synchronize only approved records and only after an account is present. | `BASELINE` | `S-EXEC` §§4.1, 6, Phase 1B; `D0-004`; `D0-010` | N/A | Approved data inventory and integration tests prove no guest upload before explicit account transition. |
| `P1-SYN-002` | Define guest ownership and an atomic guest-to-account transition. | `BASELINE` | `DATA-P1-001` §§5.2–5.4; `SPEC-P1-001` §§4, 6.6 | Phase 1B hosted run `30350985687` | Transition contract and rollback tests cover duplicates, partial failure, existing account data, wrong account, and retry. |
| `P1-SYN-003` | Represent synchronization explicitly as pending, syncing, synced, conflicted, failed, and deleted. | `BASELINE` | `S-EXEC` Phase 1B; `S-SWIFT` §16 | Pending | State-machine tests cover every legal transition, retry, cancellation, relaunch, and stale response. |
| `P1-SYN-004` | Use a documented deterministic conflict rule per entity; no undocumented last-write-wins. | `BASELINE` | `DATA-P1-001` §6; `SPEC-P1-001` §11 | Phase 1B hosted run `30350985687` | Canonical entity conflict table plus deterministic conflict, retry, replay, and tombstone tests. |
| `P1-SYN-005` | Propagate deletion with testable tombstones and no resurrection after reconnect. | `BASELINE` | `S-EXEC` §§9.5, Phase 1B; `S-SWIFT` §16 | N/A | Interrupted/offline/multi-device deletion tests reconcile local rows, remote rows, files, caches, and queues. |
| `P1-SYN-006` | Protect every user-owned Supabase row and file with tested least-privilege access. | `BASELINE` | `S-EXEC` §§4.3, 5, Phase 1B; `S-IOS` §4.2 | N/A | Isolated backend policy tests include positive owner access and negative cross-user/anonymous/admin-claim cases. |
| `P1-SYN-007` | Define deterministic sign-out, token-expiry, reinstall, account-conversion, and account-deletion outcomes. | `BASELINE` | `DATA-P1-001` §§5, 7, 8; `SPEC-P1-001` §§6.6, 6.8, 7 | Phase 1B hosted run `30350985687` | Canonical lifecycle tables plus local/Keychain/isolated-remote reconciliation tests; physical and provider-console evidence remains external. |

## Accessibility and inclusive behavior

| ID | Requirement | Status | Sources | Figma | Minimum acceptance evidence |
|---|---|---|---|---|---|
| `P1-ACC-001` | Every critical flow is operable with VoiceOver using correct names, roles, values, hints, order, actions, and focus movement. | `BASELINE` | `S-EXEC` §§5, 9.4; `S-IOS` §10.3; `S-SWIFT` §12 | Pending | Manual VoiceOver pass on the physical matrix plus automated accessibility checks. |
| `P1-ACC-002` | Every critical flow remains operable at all supported Dynamic Type accessibility sizes. | `BASELINE` | `S-EXEC` §§5, 9.4; `S-IOS` §10.3; `S-SWIFT` §12 | Pending | Screenshot/manual tests show no clipped critical content or unreachable control at each size. |
| `P1-ACC-003` | Honor Reduce Motion/Transparency where relevant and do not encode meaning only in color, shape, sound, or motion. | `BASELINE` | `S-EXEC` §9.4; `S-IOS` §10.3; `S-SWIFT` §12 | Pending | Accessibility matrix covers motion, contrast, increased contrast, differentiation, and silent equivalents. |
| `P1-ACC-004` | Critical controls are reachable with Voice Control and Switch Control and support one-handed stressed use. | `BASELINE` | `S-EXEC` §9.4 and Phase 1E; `S-SWIFT` §12 | Pending | Manual assistive-technology and reachability tests on target device sizes. |
| `P1-ACC-005` | Errors, asynchronous changes, confirmations, and destructive actions are announced clearly and remain recoverable. | `BASELINE` | `S-EXEC` §§7.3, 9.4; `S-SWIFT` §12 | Pending | Accessibility/failure tests validate focus, announcements, confirmation, cancel, and reversal where specified. |

## Privacy, security, and data governance

| ID | Requirement | Status | Sources | Figma | Minimum acceptance evidence |
|---|---|---|---|---|---|
| `P1-SEC-001` | Collect only fields tied to approved Phase 1 purposes; do not collect information “just in case.” | `BASELINE` | `S-EXEC` §§5, 9.3; `S-IOS` §4.1 | N/A | Field-by-field data inventory approval and observed-network/storage audit. |
| `P1-SEC-002` | Phase 1 does not request microphone, Health, contacts, location, camera, photos, Bluetooth, or tracking access. | `BASELINE` | `S-EXEC` §§4.2, 5, 9.2; `S-IOS` §5.3 | N/A | Entitlement, purpose-string, linked-framework, binary, privacy-indicator, and runtime prompt audit. |
| `P1-SEC-003` | Do not use wellness or episode data for advertising, tracking, brokerage, behavioral targeting, or unrelated marketing. | `BASELINE` | `S-EXEC` §§4.2, 5; `S-APPLE-ARG` §§2.5.18, 5.1; `S-IOS` §4.1 | N/A | Analytics allowlist, SDK/data-flow review, policy review, and traffic inspection. |
| `P1-SEC-004` | No service-role key, signing secret, privileged credential, token, or private signed payload ships in the client or logs. | `BASELINE` | `S-EXEC` §§4.3, 5; `S-IOS` §§4.2, 12.1; `S-SWIFT` §17 | N/A | Secret/history/bundle/log scan plus negative client-authorization tests. |
| `P1-SEC-005` | Development, staging, and production use isolated configuration and backend resources. | `BASELINE` | `S-EXEC` §5 and Phase 1A; `S-IOS` §4.2 | N/A | Configuration tests prove nonproduction builds cannot resolve or mutate production resources. |
| `P1-SEC-006` | Store session tokens in Keychain and select file/data protection classes against verified lock-state behavior. | `BASELINE` | `S-EXEC` Phase 1B; `S-IOS` §4.3; `S-SWIFT` §17 | N/A | Device-lock, reinstall, sign-out, backup, and file-protection inspection tests. |
| `P1-SEC-007` | Maintain a valid privacy manifest and third-party SDK register from the first dependency onward. | `BASELINE` | `S-EXEC` Phase 1A; `S-APPLE-PRIVACY`; `S-IOS` §§4.5-4.6 | N/A | Xcode privacy report, manifest validation, required-reason API scan, SDK signature/provenance review, and disclosure reconciliation. |
| `P1-SEC-008` | Logging and diagnostics redact sensitive content and omit questionnaire answers, tokens, signed URLs, audio paths, and raw payloads. | `BASELINE` | `S-EXEC` Phase 1A; `S-IOS` §12.1; `S-SWIFT` §17 | N/A | Unit redaction tests and captured-device-log inspection across failure scenarios. |
| `P1-SEC-009` | Approve retention and deletion behavior for every local row/file, remote row/object, cache, queue item, and analytics event. | `BLOCKED` | `S-EXEC` Phase 0 and §9.3 | N/A | Signed retention schedule and end-to-end deletion reconciliation. |
| `P1-SEC-010` | Complete an initial threat model before data implementation begins. | `BLOCKED` | `S-EXEC` Phase 0 | N/A | Reviewed threat model covers assets, actors, trust boundaries, abuse cases, mitigations, residual risk, and owners. |

## Release and operational readiness

| ID | Requirement | Status | Sources | Figma | Minimum acceptance evidence |
|---|---|---|---|---|---|
| `P1-REL-001` | Build release candidates with a stable Xcode accepted by App Store Connect and the required SDK; the deployment target is a separate Gate 0 decision. | `BASELINE` | `S-EXEC` Phase 1A; `S-APPLE-SDK`; `S-IOS` §1 | N/A | Archived build records Xcode/Swift/SDK/target; App Store validation passes; device matrix supports the target. |
| `P1-REL-002` | Do not lock the minimum deployment target until the AlarmKit/notification/Lock Screen/App Intent/audio feasibility matrix is complete. | `BLOCKED` | `S-EXEC` §§6, Phase 0; `S-IOS` §1.2 | N/A | Approved physical feasibility report and feature fallback matrix. |
| `P1-REL-003` | Complete metadata, screenshots, age rating, privacy details, legal/support URLs, review notes, and review access consistent with the binary. | `BASELINE` | `S-EXEC` §§4.1, Phase 1H; `S-APPLE-ARG`; `S-IOS` §14 | Pending | Release audit reconciles metadata/copy/screenshots/URLs/privacy answers with observed build behavior. |
| `P1-REL-004` | Review notes disclose manual episode reporting, permission setup, alarm/fallback behavior, locked-state limits, audio, offline behavior, purchases, and deletion. | `BASELINE` | `S-EXEC` Phase 1H; `S-APPLE-ARG`; `S-IOS` §14 | N/A | Independent reviewer follows notes from clean install and reaches every gated capability. |
| `P1-REL-005` | Run automated, physical-device, accessibility, privacy, security, recovery, performance, and TestFlight evidence before release. | `BASELINE` | `S-EXEC` §§7.3, 8-12; `S-IOS` §§12-15 | N/A | Signed release record links every included requirement to passing evidence and contains no release blocker. |
| `P1-REL-006` | Production backends and public review URLs are live, stable, isolated, and supportable during App Review. | `BASELINE` | `S-EXEC` Phase 1H; `S-APPLE-ARG` review guidance | N/A | External availability checks, demo access, monitoring, ownership, feature-disable, and recovery evidence. |

## Explicit Phase 1 exclusions

| ID | Excluded capability | Status | Sources | Re-entry condition |
|---|---|---|---|---|
| `P1-X-001` | Automatic or inferred episode detection, prediction, or risk scoring | `EXCLUDED` | `S-EXEC` §4.2 | Approved scope change, claims/legal review, data and platform assessment, and revised acceptance matrix. |
| `P1-X-002` | Continuous/overnight microphone recording or ambient surveillance | `EXCLUDED` | `S-EXEC` §§4.2, 5 | Approved scope change defining explicit initiation, visible state, consent, storage, retention, deletion, and non-recording fallback; background monitoring remains prohibited. |
| `P1-X-003` | Personal or partner voice recording/upload | `EXCLUDED` | `S-EXEC` §§5-6 | Separate approved recording feature decision and full privacy/security contract. |
| `P1-X-004` | AI-generated medical analysis, reports, or coaching | `EXCLUDED` | `S-EXEC` §4.2 | Approved future scope and claims, privacy, safety, and App Review assessment. |
| `P1-X-005` | HealthKit integration | `EXCLUDED` | `S-EXEC` §§4.2, 9.2 | Approved future scope, data-purpose review, entitlement/permission register, and platform tests. |
| `P1-X-006` | Apple Watch app or watch-only feature | `EXCLUDED` | `S-EXEC` §4.2 | Approved future scope and separate watchOS requirements/evidence. |
| `P1-X-007` | Android application | `EXCLUDED` | `S-EXEC` §4.2 | Approved future phase. |
| `P1-X-008` | Community, social feed, clinician portal, telehealth, or emergency-service claims | `EXCLUDED` | `S-EXEC` §4.2 | Approved future scope with moderation, safety, legal, privacy, and operational plan. |
| `P1-X-009` | Research-data sharing, advertising profiles, or cross-app tracking | `EXCLUDED` | `S-EXEC` §4.2 | Not eligible through ordinary feature approval; requires new policy/legal basis and a Phase 1 scope change. |
