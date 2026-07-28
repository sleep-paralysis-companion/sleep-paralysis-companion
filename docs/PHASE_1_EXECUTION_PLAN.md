# SP / Paralux — Phase 1 Execution Plan

> **29 July 2026 approved product-change override.** [Persona and Personal Audio Product Realignment](phase-0/PERSONA_AND_PERSONAL_AUDIO_REALIGNMENT.md) controls the authenticated Q1-Q3/persona onboarding, local-only personal audio, microphone, widget/manual-action, and Phase 1B/1C delta scope. Any guest-only onboarding, questionnaire/persona exclusion, personal-recording exclusion, or incompatible Phase 1C sequence below is historical baseline text and is superseded.

**Document status:** Initial operating plan for product, design, iOS, backend, QA, privacy, and release agents  
**Scope:** Phase 1 iPhone application only  
**Last reviewed:** 25 July 2026

## 1. Purpose

This document is the execution authority for taking the current research, PRD, Figma design, technical plan, and meeting notes to an App Store-ready Phase 1 release. It defines what Phase 1 is, what it is not, the decisions that must be locked before implementation, the order of work, and the evidence required to pass each gate.

An agent must not infer a feature merely because it appears in one source. When sources conflict, stop that workstream, record the conflict, and resolve it through the decision process in section 7.

## 2. Product definition

SP / Paralux is an iOS-first sleep-wellness companion for people who experience sleep paralysis. Phase 1 supports a deliberate user journey:

1. The user understands the product's wellness purpose and completes lightweight onboarding.
2. The user prepares for sleep with a schedule, reminder, and calming audio.
3. If an episode occurs, the user manually invokes a readily accessible grounding experience.
4. The app guides the user through a calm, low-cognitive-load recovery flow.
5. The user can complete a morning check-in and review their own history.

The product is a wellness and self-management aid. It must not diagnose, predict, prevent, treat, or claim to reduce a medical condition. It must never imply that it can automatically know that an episode is occurring.

## 3. Source authority and traceability

Agents must use this precedence order:

1. Applicable law and current official Apple platform/App Review requirements.
2. Approved decisions recorded in this repository's decision log.
3. This execution plan and its linked engineering guides.
4. The approved Phase 1 product specification and acceptance matrix created in Gate 0.
5. The Phase 1 technical plan.
6. Figma for visual intent and interaction reference.
7. The master PRD `Phase 1 Userflow` tab for exact wording that remains within
   the approved product/claims boundary.
8. The rest of the master PRD for research and longer-term product context.
9. Meeting notes and transcript as discovery evidence, not final requirements.

No internal decision can waive an Apple platform restriction, App Review rule, privacy obligation, or applicable legal requirement. If an external requirement changes, stop the affected release work, update the decision record and project documents, and revalidate the impacted features.

Current inputs:

- [SP Figma file](https://www.figma.com/design/vjbC6so9SSpuRpJPsYuXEw/SP?node-id=299-358&p=f&t=5VuTyclmlid6EdAm-0)
- [Master PRD - SP — Phase 1 Userflow](https://docs.google.com/document/d/1ccudhMzM18k5dMel4uQNpK80yihWJNmJE5N-kXTzDZA/edit?tab=t.ptx1blwstnqb)
- `SP_App_Tech_Stack_and_Phase_1_Plan_Client.pdf`
- [Project meeting document](https://docs.google.com/document/d/160QELWcVYsm0YyATZXlrox7fE7CKg5VdtzHxmSzisvI/edit?tab=t.n66f881tpwcq)
- [iOS 2026 best practices](./IOS_2026_BEST_PRACTICES.md)
- [Swift and SwiftUI best practices](./SWIFT_SWIFTUI_BEST_PRACTICES.md)

Every implemented requirement must have a requirement ID, Figma reference where applicable, test evidence, and a link to any decision that changes the original requirement.

## 4. Canonical Phase 1 boundaries

### 4.1 Included capabilities

| ID | Capability | Phase 1 outcome |
|---|---|---|
| P1-ONB | Onboarding and consent | Clear wellness positioning, essential setup, contextual permissions, and a usable path without unnecessary account creation |
| P1-SLP | Sleep preparation | Bedtime schedule/reminder and a dependable pre-sleep audio experience |
| P1-ACT | Manual episode action | A user-initiated action from supported iOS surfaces; no automatic detection |
| P1-GRD | Grounding flow | Immediate, calm, accessible audio/visual guidance with interruption recovery |
| P1-CHK | Morning check-in | A short, optional reflection that records only user-entered information |
| P1-HIS | Personal history | Review, edit where appropriate, and delete episode/check-in records |
| P1-SET | Settings and controls | Schedule, audio, notifications, privacy, data, account, and purchase controls as applicable |
| P1-OFF | Local-first operation | The core support flow works without a network connection after required assets are available |
| P1-SYN | Private synchronization | Supabase synchronization only for approved data and only behind enforced row-level access |
| P1-REL | App Store release | Complete metadata, privacy disclosures, legal/support pages, review notes, and release evidence |

### 4.2 Explicitly excluded

The following are not Phase 1 and must not be started without an approved scope change:

- Automatic sleep-paralysis detection or inferred episode detection.
- A “paralysis risk score,” risk tier, prediction, diagnosis, or treatment claim.
- Continuous or overnight microphone recording, ambient monitoring, or surveillance.
- AI-generated medical analysis, AI reports, or AI coaching.
- HealthKit integration.
- Apple Watch app or watch-only features.
- Android application.
- Community, social feed, clinician portal, or telehealth.
- Emergency-service claims or language implying guaranteed rescue.
- Research-data sharing, advertising profiles, or cross-app tracking.

### 4.3 Technology responsibilities

| Concern | Authority | Rule |
|---|---|---|
| iPhone application | Swift and SwiftUI | Native app; follow the repository's supported stable Xcode and Swift versions |
| Device persistence | SQLite through GRDB | Local-first source for user-visible core data and queued changes |
| Authentication | Supabase Auth | Optional sync accounts offer Sign in with Apple and Sign in with Google only; guest/local-first use remains available |
| Cloud database | Supabase Postgres | Schema migrations are versioned; all user data is protected by row-level security |
| File storage | Supabase Storage | Only approved user files; private buckets and short-lived access URLs |
| Trusted server logic | Supabase Edge Functions | Secrets, optional verified RevenueCat webhooks, deletion, and privileged operations never run in the app |
| Public web pages | Vercel | Privacy policy, terms, support, account-deletion information, and product website |
| Digital purchases | StoreKit 2 + RevenueCat Purchases SDK | Apple remains transaction/payment authority; active RevenueCat `premium_access` controls app feature access |
| Distribution | App Store Connect | Vercel does not host or distribute the native application |

Supabase and SQLite are complementary, not alternatives. SQLite protects the core experience from network failure; Supabase provides account-scoped synchronization and server authority.

## 5. Non-negotiable product and engineering rules

1. **Manual action only.** No copy, model, sensor, timer, or background process may claim to detect an episode.
2. **Core help is offline-capable.** Grounding must not depend on a live API call.
3. **Data minimization.** Collect only data tied to an approved Phase 1 requirement.
4. **No hidden recording.** Microphone access is forbidden unless a separately approved personal-recording feature is added; recording must always be explicit and visible.
5. **No unsupported guarantees.** Lock Screen, alarm, notification, and background behavior must be described exactly as proven on physical devices.
6. **Accessible by construction.** VoiceOver, Dynamic Type, sufficient contrast, Reduce Motion, and non-audio equivalents are acceptance criteria, not a later polish task.
7. **One source of truth per state.** Local and remote ownership, synchronization, and conflict behavior must be documented before data code is merged.
8. **No secrets in the client.** Service-role keys, signing secrets, and privileged credentials are server-only.
9. **Least privilege.** Every Supabase table, bucket, function, entitlement, capability, and iOS permission needs an explicit reason and test.
10. **No direct production experiments.** Development, staging, and production use isolated configuration and backend resources.
11. **User control.** Users can understand, correct, and delete their data; account deletion is available in-app whenever accounts can be created.
12. **Evidence over assumptions.** Simulator results do not prove alarm, notification, audio route, Lock Screen, background, or purchase behavior.

## 6. Required product decisions before implementation

Gate 0 must resolve each item below in a short decision record. The provisional default applies until the product owner explicitly approves another option.

| Decision | Provisional Phase 1 default | Required evidence |
|---|---|---|
| Product name | Use “SP / Paralux” internally; do not finalize store metadata | Trademark/name check and approved naming record |
| Wellness positioning | Non-medical wellness companion | Approved claims and content matrix |
| Profile model | One local person profile | Final field list and rationale for every field |
| Account boundary | Guest/local-first; offer account only for approved sync needs | Account journey and deletion journey |
| Minimum iOS version | Lock after the platform feasibility spike | Device coverage rationale plus feature fallback matrix |
| Alarm behavior | Scheduled reminder/alarm with an honest fallback by OS version | Physical-device proof for each supported OS |
| Lock Screen action | Manual action using the supported WidgetKit/App Intents surface | Physical-device interaction proof, including locked-state limitations |
| Grounding audio | Bundled or securely downloaded approved audio | Offline, interruption, route-change, and locked-state tests |
| Personal voice recording | Excluded | A scope change must define consent, storage, retention, deletion, and microphone UX |
| Data synchronization | Local-first; sync approved records when an account is present | Conflict, retry, deletion, and sign-out behavior |
| Monetization | No paywall until products, entitlement rules, and review copy are approved | StoreKit product map and restore/refund behavior |
| Trial | No trial claim until configured in App Store Connect | Product configuration and localized disclosure |
| History insights | Descriptive user-entered history only | Copy review confirming no risk/prediction inference |
| Legal copy | Privacy policy, terms, support, and wellness disclaimer required | Approved public URLs and in-app placement |

## 7. Agent operating protocol

### 7.1 Before starting a work item

The assigned agent must confirm:

- The requirement ID and acceptance criteria exist.
- The relevant decision records are approved.
- The Figma node and all required UI states are identified.
- Data classification, permission use, analytics impact, and offline behavior are known.
- Dependencies and supported OS behavior are documented.
- The task does not introduce an excluded Phase 1 capability.

If any answer is missing, the task remains blocked at the specification layer. Do not invent a default inside implementation.

### 7.2 Work item definition

Each work item must contain:

```text
Requirement IDs:
User outcome:
In scope:
Out of scope:
Figma nodes/states:
Data read/written:
Permissions/capabilities:
Offline behavior:
Failure and recovery behavior:
Accessibility acceptance:
Security/privacy acceptance:
Automated checks:
Physical-device checks:
Decision records:
```

### 7.3 Completion evidence

“Implemented” is not a completion state. A completed work item includes:

- Passing automated checks relevant to the change.
- Manual evidence for user-visible states and recovery paths.
- Physical-device evidence when platform behavior is involved.
- Accessibility verification.
- Privacy and data-flow review.
- Updated requirement traceability.
- No unresolved high-severity defect.

### 7.4 Change control

Any proposed change to scope, claims, data collection, permissions, subscriptions, or background execution requires:

1. A decision record describing the user benefit and alternatives.
2. Updates to the product specification, data map, acceptance matrix, and privacy disclosures.
3. Security, accessibility, and App Review impact assessment.
4. Product-owner approval before implementation.

## 8. Phase and gate plan

No implementation begins before Gate 0 passes. Later phases may overlap only when their entry conditions are already satisfied and they do not depend on an unresolved decision.

### Phase 0 — Product, claims, and feasibility lock

**Objective:** Turn conflicting discovery artifacts into one implementable Phase 1 contract.

**Current record (25 July 2026):** The documentation baseline and exact
blockers are indexed in [Phase 0 Control Index](./phase-0/README.md). The
authoritative decision is [Gate 0 — NOT PASSED](./phase-0/GATE_0_REVIEW.md);
production Phase 1A work remains unauthorized. Only the isolated disposable
platform spike defined in the feasibility report may run before Gate 0. The
[read-only Figma audit](./phase-0/FIGMA_READ_ONLY_AUDIT.md) confirms the exact
file key, starting page, and canvas-level visual conflicts, but child-node,
state, component/variable, and prototype mapping remains blocked.

#### Required work

- Create a requirement inventory with stable IDs and source links.
- Reconcile the profile count and onboarding branch logic.
- Replace the Figma “risk score,” “Guardian Mode,” detection, prevention, and episode-reduction language with approved wellness copy.
- Expand the screen count into a complete state inventory: loading, empty, offline, denied permission, unavailable capability, error, destructive confirmation, purchase, restoration, deletion, and recovery.
- Approve the exact Phase 1 data fields and retention rules.
- Approve the account/guest boundary and deletion behavior.
- Approve the audio catalog roles and bundle/download boundary. Clearly labeled
  placeholders and owned synthetic spike audio are permitted now; actual
  assets, rights, scripts, and manifests are required before content
  integration/release.
- Perform a platform feasibility spike on physical iPhones for AlarmKit, notifications, Lock Screen controls/widgets, App Intents, audio while locked, and OS fallbacks.
- When no local Mac is available, compile/sign the isolated spike through an
  approved hosted macOS iOS workflow, distribute it by internal TestFlight, and
  run the physical matrix on the arranged iPhone; reserve interactive
  borrowed/remote Mac access for Xcode issues that hosted logs cannot resolve.
- Lock the minimum deployment target only after the feasibility matrix is complete.
- Decide whether Phase 1 launches with paid digital features. If yes, approve StoreKit products and entitlement behavior.
- Create content, safety, accessibility, privacy, security, and analytics standards.

#### Deliverables

- Canonical Phase 1 product specification.
- Requirements-to-source-to-test matrix.
- Approved claims/copy matrix.
- Complete navigation and screen-state map.
- Platform feasibility report with device/OS evidence.
- Data inventory and data-flow diagram.
- Permission and entitlement register.
- Initial threat model.
- Decision records for every item in section 6.

#### Gate 0 exit criteria

- No critical requirement contradicts another approved requirement.
- Every Phase 1 screen and system state has acceptance criteria.
- Every collected field has a purpose, owner, storage location, retention rule, and deletion rule.
- Lock Screen and alarm language matches demonstrated platform behavior.
- The product can be described without medical, predictive, or detection claims.
- Product, design, iOS, backend, QA, privacy, and release owners approve the baseline.

### Phase 1A — Repository and platform foundation

**Verified status — 28 July 2026:** Gate 1A passed for candidate
`0a3046e3a1e12e6024fe244466d374cfcb12e772` in
[hosted macOS run 30313980331](https://github.com/sleep-paralysis-companion/sleep-paralysis-companion/actions/runs/30313980331).
This does not pass Gate 0 or authorize Phase 1B.

**Objective:** Establish a reproducible, secure foundation before feature development.

**Limited implementation authorization — 28 July 2026:** Satyam Shree
authorized Phase 1A repository/application foundation implementation while
Gate 0 remains `NOT PASSED`. This narrow exception does not change Gate 0,
authorize Phase 1B/features, or authorize live Supabase, RevenueCat/App Store,
Figma, signing, or production-service changes.

#### Entry conditions

- Gate 0 passed.
- Bundle identifiers, deployment target, environments, and Apple team roles are approved.

#### Required work

- Create the native Swift/SwiftUI application and test targets using the current stable Xcode toolchain accepted by App Store Connect.
- Enable strict Swift concurrency checking and the approved Swift language mode.
- Establish feature, domain, data, platform, design-system, and test boundaries.
- Configure separate development, staging, and production environments.
- Establish configuration injection; commit no credentials.
- Add deterministic formatting, linting, build, unit-test, and UI-test checks.
- Create the initial design tokens for color, typography, spacing, shape, motion, and accessibility behavior.
- Establish logging with privacy-safe redaction and no sensitive payloads.
- Create the privacy manifest and third-party SDK register from the first dependency onward.
- Define feature flags for platform-dependent or release-gated behavior.

#### Gate 1A exit criteria

- A clean checkout builds and tests using documented commands.
- Development and staging cannot accidentally reach production resources.
- Dependency provenance and privacy impact are recorded.
- The app shell supports accessibility text sizes and light/dark rendering decisions.
- No secrets or privileged Supabase keys are present in app resources, logs, or repository history.

### Phase 1B — Data, authentication, security, and offline foundation

**Verified status — 28 July 2026:** Gate 1B passed for repository, simulator, and isolated-backend
candidate `6b80c0d6269168b6f1a5494893869fc3278df47e` in
[hosted run 30322506101](https://github.com/sleep-paralysis-companion/sleep-paralysis-companion/actions/runs/30322506101).
Gate 0 remains `NOT PASSED`; production provider configuration, live deployment, physical-device
Data Protection, TestFlight, and production deletion remain external evidence.

**Objective:** Make local persistence and Supabase synchronization predictable before UI features depend on them.

#### Required work

- Finalize versioned schemas for settings, schedule, audio metadata, episode records, morning check-ins, sync state, and account linkage.
- Implement local migrations and rollback/recovery tests.
- Implement Supabase migrations, foreign keys, constraints, indexes, and row-level security.
- Test row-level security with positive and negative user-isolation cases.
- Define guest data ownership and the atomic guest-to-account transition.
- Implement only Sign in with Apple and Sign in with Google after provider
  callback, linking/collision, reauthentication, cancellation, token-revocation,
  and account-deletion behavior is approved. Do not add email/password/OTP.
- Define synchronization as an explicit state machine: pending, syncing, synced, conflicted, failed, and deleted.
- Define deterministic conflict resolution per entity; never use an undocumented last-write-wins rule.
- Make deletion tombstones and server deletion propagation testable.
- Store session tokens in Keychain; store sensitive local files with appropriate data protection.
- Establish export and deletion operations before collecting production user data.
- Define telemetry events from a minimal allowlist; exclude journal text, recordings, and sensitive free text.

#### Gate 1B exit criteria

- Core records can be created, read, updated, and deleted offline.
- Interrupted synchronization retries without duplicates or silent data loss.
- One user cannot access another user's rows or files.
- Sign-out, reinstall, token expiry, account conversion, and account deletion have documented outcomes.
- Schema and policy tests run in automation against an isolated backend.

### Phase 1C — Design system, app shell, and onboarding

**Objective:** Deliver a coherent, accessible shell and the shortest safe path to first use.

#### Required work

- Implement reusable semantic design components rather than screen-specific clones.
- Build value-based navigation with restorable, testable route state.
- Implement welcome, wellness disclaimer, essential preference setup, and permission education.
- Request notification or alarm authorization only in context, immediately before the relevant feature.
- Provide useful behavior when a permission is denied; include a clear path to Settings when necessary.
- Defer account creation and nonessential questions until their value is clear.
- Use approved copy only; no risk score or detection language.
- Validate VoiceOver order, labels, actions, Dynamic Type, Reduce Motion, contrast, keyboard behavior, and error announcements.

#### Gate 1C exit criteria

- A new user can reach the usable home/sleep-preparation state without creating an unnecessary account.
- Denying every optional permission does not trap or crash the app.
- Relaunching during onboarding restores a valid step.
- All supported content-size categories remain operable without clipped critical controls.
- Onboarding content and screenshots match the approved product claims.

### Phase 1D — Sleep schedule and pre-sleep audio

**Objective:** Make the preparation experience dependable online, offline, interrupted, and locked.

#### Required work

- Implement schedule creation, editing, disabling, daylight-saving changes, and notification/alarm authorization states.
- Implement the approved AlarmKit path where available and the approved fallback elsewhere.
- Clearly label differences between an alarm, a notification, and an in-app reminder.
- Implement the approved audio library, download/cache rules, and storage cleanup.
- Configure AVAudioSession only while needed and handle interruption, route change, headphones, Bluetooth, phone calls, Siri, lock, background, and app termination states.
- Preserve playback intent without surprising automatic audio after an interruption.
- Provide visible alternatives to audio-only information.
- Make schedule and playback controls fully accessible.

#### Gate 1D exit criteria

- Schedule behavior is verified across supported OS versions, device lock states, silent mode, focus modes, restarts, clock changes, and denied authorization.
- Previously available grounding/pre-sleep content works without network access.
- Audio never records or activates the microphone.
- Interruptions and route changes recover to the documented state.
- The UI never overstates what iOS can guarantee.

### Phase 1E — Manual episode action and grounding

**Objective:** Provide the simplest reliable, user-initiated path to grounding under stress.

#### Entry condition

- The Phase 0 physical-device feasibility result for the chosen Lock Screen/control approach is approved.

#### Required work

- Implement the approved manual App Intent/control/widget/deep-link entry surface.
- Make the action explicitly user-initiated; do not run a detector or infer an episode.
- Minimize interaction steps and visual density after activation.
- Start with locally available grounding content; network enrichment must never block entry.
- Support audio, readable visual instructions, haptics only when appropriate, and a silent mode.
- Handle locked-device limitations, device authentication, unavailable extensions, app termination, stale deep links, and repeated taps.
- Add an unobtrusive exit and an optional route to the later check-in; do not force logging.
- Use calm language and never imply an emergency response or guaranteed outcome.

#### Gate 1E exit criteria

- The action is proven on each supported physical-device/OS path and accurately documented.
- A user can reach useful grounding with the network unavailable and the main app not already running.
- Repeated activation is idempotent and cannot create duplicate records or overlapping audio.
- VoiceOver, large text, Reduce Motion, silent use, and one-handed interaction are verified.
- No episode record is created unless the approved UX makes that user action clear.

### Phase 1F — Morning check-in and personal history

**Objective:** Let users record and review their own experience without turning descriptive data into a clinical score.

#### Required work

- Implement the approved optional morning check-in fields.
- Support skip, partial completion, editing, and deletion according to the data contract.
- Show descriptive history and trends only when they are mathematically and contextually honest.
- Distinguish “no entry” from a negative answer.
- Handle locale, calendar, clock, and daylight-saving changes consistently.
- Avoid streak pressure, shame, diagnosis, causal claims, and risk classification.
- Keep local history usable while offline and reconcile it safely after reconnecting.

#### Gate 1F exit criteria

- Check-ins never appear without an explicit user submission.
- Missing, partial, duplicate, edited, and deleted records render correctly.
- History agrees with persisted data after relaunch, sign-in, sign-out, synchronization, and conflict resolution.
- Charts or summaries remain accessible and include a nonvisual textual equivalent.
- Copy review confirms that all insights are descriptive, not predictive or medical.

### Phase 1G — Settings, privacy, accounts, and purchases

**Objective:** Give users complete control over behavior, data, identity, and any paid access.

#### Required work

- Implement schedule, audio, notification, accessibility, privacy, and support settings.
- Show actual system-authorization state and link to iOS Settings when the app cannot change it.
- Implement data export, individual-record deletion, and complete local-data deletion.
- If account creation exists, implement in-app account deletion and explain any legally required retention.
- Replace planning placeholders with approved, live privacy policy, terms,
  support, and account-deletion pages on Vercel before release.
- Complete App Store privacy answers from the approved data inventory, including third-party SDK behavior.
- If premium digital features launch, use StoreKit 2, display localized product terms, restore purchases, handle pending/refunded/revoked transactions, and provide subscription management.
- Validate entitlements through approved server logic when server enforcement is necessary.
- Do not expose external checkout for in-app digital feature unlocks.

#### Gate 1G exit criteria

- Every setting has a deterministic effect and survives relaunch as specified.
- Export and deletion results match the local and Supabase data inventory.
- Account deletion is discoverable in the app and verified end to end.
- StoreKit sandbox scenarios pass if purchases are in scope.
- App privacy disclosures, permission strings, in-app explanations, and observed network behavior agree.

### Phase 1H — Integrated quality, security, and release readiness

**Objective:** Prove the complete Phase 1 product is safe, smooth, reviewable, and supportable.

#### Required work

- Execute unit, integration, contract, migration, UI, snapshot where appropriate, accessibility, performance, energy, security, and recovery testing.
- Run the full core journey on the oldest supported device class and current iPhone hardware.
- Test clean install, upgrade, reinstall, offline launch, poor network, backend outage, token expiry, notification denial, audio interruption, purchase states, and deletion.
- Perform privacy-manifest, required-reason API, third-party SDK, entitlement, permission, and binary-content audits.
- Resolve crashes, hangs, data loss, inaccessible critical flows, security defects, and misleading copy before release candidacy.
- Run an external TestFlight pass with feedback capture and release-candidate traceability.
- Prepare App Store metadata, screenshots, age rating, privacy details, review notes, support URL, privacy URL, demo account or demo mode, and special hardware instructions.
- Ensure the backend and public URLs used for review are live and stable.
- Establish production monitoring, crash triage, support ownership, and rollback/feature-disable procedures.

#### Gate 1H exit criteria — Phase 1 definition of done

- Every included requirement maps to passing evidence.
- No open release-blocking defect remains.
- The complete core flow works on physical devices with and without network access wherever offline support is promised.
- App launch, scrolling, input, navigation, audio start, and grounding entry meet approved responsiveness thresholds measured on target devices.
- No user data crosses account boundaries or appears in logs unexpectedly.
- Accessibility review passes for the full core flow.
- Privacy policy, App Store privacy details, actual data behavior, and SDK manifests are consistent.
- Review notes give Apple a complete, reproducible path through gated features.
- The archived release build is produced by the approved pipeline from the tagged source revision.
- Product, engineering, QA, privacy/security, content, and release owners sign the release record.

## 9. Cross-cutting acceptance matrices

### 9.1 Platform behavior matrix

For every supported OS/device combination, record:

- Scheduled alarm/reminder behavior.
- Lock Screen action availability and unlock requirements.
- App terminated, suspended, backgrounded, foregrounded, and device-restarted behavior.
- Silent mode, Focus, notification summary, and authorization behavior.
- Audio route and interruption behavior.
- Offline and degraded-network behavior.

Unsupported combinations must produce an honest fallback, not a broken or hidden control.

### 9.2 Permission matrix

For every permission or entitlement, record:

- Requirement ID and user benefit.
- Exact system purpose string.
- Pre-permission education screen, if any.
- Trigger point.
- Behavior for not determined, allowed, denied, restricted, and later revoked.
- Settings recovery path.
- Privacy-policy and App Store disclosure mapping.

Phase 1 must not request microphone, Health, contacts, location, camera, photos, Bluetooth, or tracking permission unless a future approved requirement is added.

### 9.3 Data matrix

For every field, record:

- Data owner and sensitivity.
- Collection source and purpose.
- Local table/file and protection class.
- Remote table/bucket and row-level policy.
- Whether it is linked to identity.
- Synchronization and conflict rule.
- Export format.
- Retention and deletion behavior.
- Analytics prohibition or approved aggregation.
- App Store privacy category.

### 9.4 Accessibility matrix

Every user-facing flow must cover:

- VoiceOver name, role, value, hint, order, rotor actions, and focus movement.
- Dynamic Type through accessibility sizes.
- Contrast and differentiation without color alone.
- Reduce Motion and Reduce Transparency where relevant.
- Voice Control and Switch Control reachability.
- Captions or visible equivalents for audio cues.
- Reachable, comfortably sized controls and sufficient spacing.
- Clear errors, confirmations, and reversible destructive actions.

### 9.5 Failure and recovery matrix

At minimum, test:

- No network and intermittent network.
- Supabase outage or slow response.
- Expired/revoked session.
- Local database migration failure or full storage.
- Download corruption or missing audio.
- Interrupted audio and changed route.
- Denied/revoked notification or alarm permission.
- Unsupported OS capability.
- Duplicate App Intent invocation.
- StoreKit pending, cancelled, refunded, and revoked states if applicable.
- Account deletion interrupted between local and server operations.

## 10. Quality and release severity policy

The following always block release:

- Crash, hang, or corrupted navigation in a core flow.
- User-visible data loss, duplication that changes meaning, or cross-account access.
- Grounding unavailable despite the app representing it as locally available.
- Hidden microphone activation or undisclosed data transfer.
- Broken account deletion, purchase restoration, or entitlement revocation.
- A critical flow that cannot be completed with VoiceOver or large text.
- Medical, predictive, detection, or guaranteed-outcome claims outside the approved copy matrix.
- App behavior that contradicts its privacy policy, App Store privacy answers, or permission purpose strings.
- Review-only credentials, URLs, products, or backend services that do not work.

## 11. Agent handoff template

Every handoff must be concise and evidence-based:

```text
Work item / requirement IDs:
Outcome delivered:
Files or systems changed:
Decisions used:
Automated evidence:
Physical-device evidence:
Accessibility evidence:
Privacy/security impact:
Known limitations:
Unresolved risks or blockers:
Next safe work item:
```

An agent must state what remains unverified. “Looks correct” and “should work” are not verification.

## 12. Phase 1 release record

The final release record must contain:

- Source revision, build number, version, Xcode version, Swift version, SDK, and deployment target.
- Supabase migration version and production policy-test result.
- Dependency lockfile and SDK privacy-manifest audit.
- Requirement traceability export.
- Supported-device and OS test matrix.
- Accessibility, privacy, security, StoreKit, audio, alarm, and offline reports.
- App Store metadata and review-note revision.
- Public privacy, terms, support, and deletion URLs.
- Known limitations stated in user-facing and support language where appropriate.
- Named approvals for product, engineering, QA, privacy/security, content, and release.

Only this signed release record may advance to App Store submission.
