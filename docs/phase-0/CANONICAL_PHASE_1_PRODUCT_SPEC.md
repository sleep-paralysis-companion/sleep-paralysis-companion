# Canonical Phase 1 Product Specification

**Specification ID:** `SPEC-P1-001`  
**Version:** 0.12  
**Status:** Product decisions approved by Satyam Shree; implementation,
independent review, and Gate 0 evidence pending  
**Effective for planning:** 25 July 2026  
**Production implementation:** Not authorized

## 1. Product contract

Sleep Paralysis Companion is a private, nonmedical iPhone wellness companion for people who
choose to prepare for, respond to, and privately record experiences they
identify as sleep paralysis.

The app:

- lets a person configure a bedtime alarm;
- offers a manual, user-initiated route to a low-cognitive-load grounding flow;
- makes a small approved grounding set available locally;
- optionally lets the person record a minimal check-in and view their own
  descriptive history; and
- optionally synchronizes approved data after the person creates or signs in
  to an account for that purpose.

The app does not observe whether an experience is occurring. It does not
diagnose, detect, monitor, predict, prevent, treat, score risk, contact an
emergency service, or guarantee an outcome.

### Success definition

Phase 1 succeeds only when a person can understand the product boundary, use
the alarm and manual grounding paths under their documented device states,
retain control of their data, and understand free versus premium access without
being misled.

Install count, alarm count, check-in frequency, or streaks are not wellness
outcomes and must not be presented as such.

## 2. Authority and change control

This specification implements the authority order in
[Source reconciliation](./SOURCE_RECONCILIATION.md). When another source
conflicts, this specification controls Phase 1 after Gate 0 approval.

A change requires a decision record when it changes any of:

- included/excluded capability;
- user-facing claim;
- collected, derived, synchronized, retained, exported, or deleted data;
- permission, entitlement, background mode, or extension;
- free/premium boundary or commercial timing;
- locked, offline, interruption, or recovery behavior;
- accessibility behavior;
- public disclosure; or
- acceptance test.

## 3. Phase 1 boundary

### Included

| Capability | Product behavior | Primary requirements |
|---|---|---|
| Scope onboarding | Explain the nonmedical/manual boundary and create one local guest profile without login | `P1-ONB-*` |
| Bedtime alarm | Schedule, edit, enable/disable, inspect, and remove an approved alarm | `P1-SLP-*` |
| Manual entry | User initiates grounding from an approved in-app or system surface | `P1-ACT-*` |
| Grounding | Local, calm, low-density audio/visual/silent flow with a clear exit | `P1-GRD-*` |
| Audio catalog | Minimal approved bundle plus optional secure downloads | `P1-GRD-*`, `P1-OFF-*` |
| Optional check-in | User-entered occurrence, perceived intensity, present state, and optional note | `P1-CHK-*` |
| Personal history | Descriptive display of submitted user entries only | `P1-HIS-*` |
| Settings and data rights | Alarm/audio controls, actual permission state, privacy/legal/support, export and deletion | `P1-SET-*` |
| RevenueCat/StoreKit premium access | Alarm always free; all other features require active `premium_access` from an Apple trial, subscription, or lifetime purchase; no grace | `P1-SET-007`, `P1-SET-008` |
| Optional account sync | Account only for sync; local-first with explicit lifecycle | `P1-SYN-*` |

### Excluded

The following are `EXCLUDED`, not “future-ready Phase 1” placeholders:

- automatic/inferred episode detection, prediction, trigger analysis, risk
  score, “wellness index,” diagnostic quiz, or preventive recommendation;
- continuous/overnight microphone use, ambient listening, any user/partner
  voice recording or upload, camera, photos, contacts, location, Bluetooth, or
  HealthKit;
- Apple Watch or Android targets;
- AI analysis, AI report, AI coaching, or generated medical content;
- community, social feed, partner calling, clinician/telehealth portal,
  research sharing, or emergency service;
- advertising, data brokerage, behavioral targeting, cross-app tracking, or
  marketing use of episode/wellness information;
- remote push infrastructure without a separately approved requirement; and
- any free-access mechanism other than the approved three-day StoreKit
  introductory offer.

Excluded frameworks, purpose strings, entitlements, UI placeholders, database
columns, analytics events, and marketing copy must not ship.

## 4. Person, device, and access model

### 4.1 One local profile

Each installation has exactly one active local profile. It is an internal data
owner, not a household, partner, child, patient, or clinical record.

The profile can be:

- `guest_local`: no remote identity; all approved core data stays on device; or
- `account_linked`: the same local profile is linked to one Supabase user for
  approved synchronization.

Changing accounts is never a silent profile switch. Sign-out leaves an explicit
choice defined in the lifecycle contract; a different account cannot claim the
previous account's protected local data.

### 4.2 Access classes

| Access class | Authority | Meaning |
|---|---|---|
| `utility_free` | Build rules | Alarm plus legal/support/data-rights and commerce utilities |
| `premium_trial` | Active RevenueCat `premium_access` backed by an Apple introductory-offer transaction | All Phase 1 features through the known trial expiration |
| `premium` | Active RevenueCat `premium_access` backed by an Apple subscription or lifetime purchase | All Phase 1 features while active |
| `unknown` | No trustworthy entitlement evidence | `utility_free` only; show recovery, never guess from account/device clock |

Account state does not grant premium access. Premium state does not require an
account. The App Store transaction belongs to the person's Apple Account;
optional Sleep Paralysis Companion account sync is a separate concern.

## 5. Information architecture

The canonical product destinations are:

1. **Home** — alarm status, manual grounding entry, and approved preparation
   content.
2. **History** — submitted user entries and descriptive summaries.
3. **Settings** — alarm/audio preferences, permissions, accessibility,
   privacy/data, optional sync account, purchase utilities, help, and legal.

Grounding, check-in, paywall, purchase, data-rights, and account flows are
task routes, not additional persistent tabs. Exact visual structure remains
pending child-node Figma reconciliation. The canvas-level
[read-only Figma audit](./FIGMA_READ_ONLY_AUDIT.md) confirms that the design
file contains visual concepts for several of these routes, but also contains
account-first onboarding, questionnaire/profile, detection/voice, risk,
clinician-sharing, and per-user-trial concepts that conflict with this
specification. Those concepts remain excluded or superseded.

## 6. Core journeys

### J-P1-001: First launch as guest

1. Show a concise welcome.
2. Show the nonmedical/manual product boundary and the privacy summary.
3. Create the one local profile only after the person continues.
4. Enter Home.
5. Offer alarm setup and grounding exploration as choices.
6. Request no system permission until a person invokes the feature that needs
   it.
7. Do not show sign-in, price, questionnaire, or permission as a condition for
   reaching Home.

**Acceptance:** clean-install tests show no network upload, account creation,
microphone prompt, notification prompt, AlarmKit prompt, tracking prompt,
wellness questionnaire, or paywall before the relevant voluntary action.

### J-P1-002: Configure an alarm

1. Person opens Alarm setup.
2. App explains what the proven implementation can and cannot do.
3. Person chooses local time and recurrence.
4. Immediately before scheduling, request AlarmKit authorization when the
   selected target supports AlarmKit; otherwise follow the approved fallback
   contract.
5. Show only confirmed system state: scheduled, authorization denied,
   unsupported, failed, or needs attention.
6. Permit edit, disable, and remove.

**Acceptance:** displayed schedule and authorization match system truth after
relaunch, external Settings changes, device restart, time-zone/DST changes,
and failed scheduling. Never display “set” from local intent alone.

### J-P1-003: Start grounding manually

1. Person intentionally invokes the in-app action or the physically proven
   system surface.
2. Repeated activation resolves idempotently to one current session.
3. If active RevenueCat `premium_access` backed by an Apple trial,
   subscription, or lifetime purchase is available, open the local grounding
   flow.
4. If premium is unavailable, preserve the always-free alarm and utility
   routes and present honest access choices. Do not imply that purchase is
   required for safety.
5. Never create an episode/check-in record from activation alone.

**Acceptance:** useful local content starts within the approved physical-device
threshold while offline and with the main app in every supported lifecycle
state. Locked-screen copy exposes no private history or experience detail.

### J-P1-004: Use grounding

1. Start with a locally verified approved asset or silent visual instructions.
2. Provide play/pause, progress where meaningful, modality selection, and a
   clear exit.
3. Handle route change, call/Siri interruption, headphone removal, app
   backgrounding, lock, and asset corruption per the audio contract.
4. At exit, offer “Done” and an optional route to the check-in. Do not force a
   log or rating.

**Acceptance:** no network request blocks entry; sound is not the only carrier
of meaning; no copy states or guarantees that the person is safe, awake,
calmed, treated, protected, or recovered.

### J-P1-005: Submit an optional check-in

1. Person opens Check-in voluntarily.
2. A draft remains local and is not part of history until explicit submission.
3. Person may skip any optional field or abandon the draft.
4. Conditional questions appear only when logically relevant.
5. Submission creates one user-entered history entry.
6. Person may later edit or delete it.

**Acceptance:** tests distinguish no entry, abandoned/partial draft, submitted
negative occurrence, submitted positive occurrence, edits, and deletion.
Activation, alarm firing, playback, or app launch never creates a check-in.

### J-P1-006: View history

History may show:

- the user-selected/reporting date;
- the person's submitted values;
- simple counts by selected calendar period; and
- a nonvisual textual equivalent for any chart.

History must not show:

- risk, likelihood, detection confidence, cause, trigger, prevention score,
  recovery score, clinical interpretation, or personalized recommendation;
- correlations presented as causation;
- inferred entries;
- streak pressure or shame; or
- precision the source data does not support.

### J-P1-007: Enable sync

1. Guest opens **Settings > Sync across devices**.
2. App explains exactly which entities leave the device and links privacy
   information.
3. If offline, stop without creating an account or changing ownership.
4. Person chooses **Sign in with Apple** or **Sign in with Google**.
5. If the account has no remote profile, atomically link and upload the approved
   guest dataset.
6. If the account already has data, do not merge scalar/profile state silently;
   present the deterministic choice in the sync contract.
7. Show sync state and allow retry.

**Acceptance:** no guest row or file is uploaded before successful account
linkage and the explicit sync action. A failed conversion rolls back to a fully
usable guest profile.

### J-P1-008: Purchase, restore, and manage

1. Paywall states the premium feature set, exact localized price/period, renewal
   behavior, and links required by Apple.
2. StoreKit/App Store Connect control products, payments, and transaction
   truth; RevenueCat controls the app's `premium_access` entitlement mapping
   and customer-information presentation.
3. Pending, cancelled, failed, unverified, active, billing-retry-without-grace,
   expired, refunded, and revoked states remain distinct.
4. Restore and subscription management remain available without login or
   premium.
5. Account deletion explains that deleting Sleep Paralysis Companion data does not itself cancel
   an Apple subscription.

## 7. Onboarding truth table

Onboarding is a router over persisted facts; it is not a sequence assumed to
have completed atomically.

| Local profile | Notice version | Account/session | Network | Destination and action |
|---|---|---|---|---|
| Absent | None | None | Any | Welcome → product boundary → create `guest_local` → Home |
| Present | Current | None | Any | Home as guest |
| Present | Superseded | Any | Any | Show updated scope/privacy notice once; alarm and data-rights remain reachable; record new `seen_at` after display |
| Present | Current | Linked and valid | Any | Home; sync runs only when network is available |
| Present | Current | Linked, token expired | Offline | Home with local data; sync state `auth_required`; no data loss or forced logout |
| Present | Current | Linked, token expired | Online | Home with nonblocking sign-in-required state; reauthenticate from Sync settings |
| Present | Current | None; person selects Sync | Offline | Stay guest; explain connection required; create nothing remotely |
| Present | Current | None; person selects Sync | Online | Privacy summary → authenticate → conversion decision/transaction |
| Present | Current | Different account attempts sign-in | Any | Stop before data exposure; require explicit local-data disposition and reauthentication |
| Present | Current | Account deletion pending | Any | Local core follows the approved deletion choice; show status and subscription note |

### 7.1 Onboarding fields and purposes

Only these fields may be created by onboarding:

| Field | Type | Required | Purpose | Storage/sync |
|---|---|---:|---|---|
| `local_profile_id` | random UUID | Yes | Stable owner for local rows without personal identity | Local; mapped to account only during conversion |
| `profile_created_at` | UTC instant | Yes | Migration, export, and lifecycle audit | Local; sync only when account linked |
| `product_notice_version` | bounded string | Yes | Know which scope/privacy summary was shown | Local; not analytics |
| `product_notice_seen_at` | UTC instant | Yes | Avoid repeated display; not legal proof of health consent | Local; not analytics |
| `onboarding_completed_at` | UTC instant | Yes | Deterministic launch routing | Local; not analytics |

Onboarding must not ask for or store name, age, date of birth, sex/gender,
location, diagnosis, medication, episode frequency, emotions, partner contact,
voice preference, health data, or marketing consent. Alarm, audio, optional
check-in, account, and diagnostics choices occur just in time in their own
flows.

## 8. Feature field-purpose inventory

This is the product-level allowlist. The authoritative storage/retention detail
is in [Data lifecycle and sync contract](./DATA_LIFECYCLE_AND_SYNC_CONTRACT.md).

### 8.1 Alarm

| Field | Purpose |
|---|---|
| Stable local alarm ID and system AlarmKit ID | Reconcile app intent with actual scheduled object |
| Local wall-clock hour/minute | Display and reschedule the person's chosen time |
| Selected weekdays | Represent recurrence; empty means approved one-time behavior |
| Enabled state | Express person intent; never substitute for system truth |
| Optional snooze duration from approved choices | Configure proven snooze behavior |
| Last schedule result and non-sensitive error category | Honest recovery and diagnostics |

No alarm title may expose sleep-paralysis or check-in details on a locked
screen. The exact neutral title needs Content/Claims approval.

### 8.2 Grounding preferences

| Field | Purpose |
|---|---|
| Preferred approved modality/asset ID | Start the person's selected local content |
| Volume-independent silent-mode preference | Provide a non-audio option |
| Haptics preference | Honor user choice when haptics are approved and available |
| Downloaded asset IDs/versions | Verify and manage optional cache |

Do not persist a timeline of grounding use in Phase 1.

### 8.3 Optional check-in copy and field contract

The user-designated exact-copy source is `S-PRD-P1-COPY`. Satyam Shree approved
the following minimal completion of its occurrence and present-state wording
on 25 July 2026. Questions about whether the app helped, what content was used,
or inferred outcomes remain excluded.

| Field | Exact prompt/options or unresolved source state | Rule and purpose |
|---|---|---|
| `reported_for_local_date` | `Night of` date selector; default to the immediately preceding local calendar date before local noon, otherwise the current local date | Organize history without claiming a detected event time; the person may change the date |
| `occurrence` | “Did you have an episode last night?” → `Yes` / `No` | Manual user report only. Missing row ≠ draft null ≠ submitted `No`; “last night” requires explicit local-date semantics. |
| `perceived_intensity` | `How intense did it feel? (Optional)` → `Mild` / `Moderate` / `Severe` / `Extreme` | Optional subjective description; never a clinical scale, diagnosis, or computed score |
| `present_state` | “How are you feeling now?” → `I’m fine now` / `Still a bit shaken` / `Exhausted` | Optional present-moment self-description; do not label as clinical recovery or app outcome |
| `note` | `Anything you'd like to remember? (Optional)` | Private user text; never analytics, notification copy, search indexing, or model input; 500 user-perceived-character limit |

System metadata (`entry_id`, creation/update instants, revision, sync state, and
deletion marker) exists only for storage integrity, export, and synchronization.

Validation:

- a submitted entry requires `reported_for_local_date` and `occurrence`;
- intensity is permitted only when occurrence is `Yes`;
- changing occurrence from `Yes` clears intensity after confirmation;
- present state and note are optional for either occurrence value;
- whitespace-only note becomes absent;
- the note limit is measured in user-perceived characters and never truncates
  silently;
- exactly one submitted entry is allowed per local calendar date; a later save
  edits that entry instead of creating a duplicate; and
- draft autosave is local only and purges seven days after last edit.

## 9. State ownership rules

| State | Owner |
|---|---|
| Navigation and presentation | SwiftUI feature state |
| Local profile, settings, alarm intent, entries, sync queue | GRDB database transaction |
| Scheduled alarm and authorization | AlarmKit/system API |
| Notification authorization if fallback is approved | UserNotifications/system API |
| Current audio playback | Audio session/player state |
| Downloaded asset integrity | Versioned manifest plus verified local file |
| Remote account/session | Supabase Auth; tokens in Keychain |
| Remote synchronized records | Supabase rows/objects protected by RLS |
| Premium entitlement | RevenueCat `premium_access` backed by Apple transaction state |

The UI may display cached intent while loading, but must label it and reconcile
to the owning system before claiming success.

## 10. Offline and failure contract

### Must work without network after first successful installation/setup

- launch and reach Home;
- inspect local alarm intent and, when the OS supports it, reconcile system
  state without a server;
- invoke the approved manual surface;
- start the minimum bundled grounding content;
- use silent visual grounding;
- create/edit/delete local check-in entries;
- view local history;
- inspect privacy/legal copies bundled with the app, while also offering the
  public URL when online;
- export local data to a user-selected destination; and
- delete local data.

### Requires network

- account creation, authentication, reauthentication, conversion, and sync;
- optional audio download;
- StoreKit purchase, restore, or entitlement refresh when Apple requires a
  network;
- purchase when StoreKit requires network;
- account deletion request and completion status; and
- current public support/legal pages.

### Failure language

Every failure states:

1. what did not complete;
2. whether local data or system schedule changed;
3. what remains available;
4. the safe next action; and
5. whether retry can duplicate anything.

Errors never imply clinical danger or advise medical/emergency action as a
personalized judgment. General help copy may say the app is not emergency
support and direct a person to local professional/emergency resources only
after jurisdictionally appropriate Legal/Safety approval.

## 11. Accessibility and stressed-use acceptance

Every included flow must:

- support VoiceOver labels, values, traits, actions, logical order, and focus
  recovery;
- remain operable through supported Dynamic Type accessibility sizes without
  clipping a critical control;
- provide a textual and visual equivalent for audio/haptic meaning;
- honor Reduce Motion, Reduce Transparency, Increased Contrast, and
  Differentiate Without Color where relevant;
- expose unique Voice Control names and work with Switch Control;
- keep critical manual controls reachable one-handed on the approved device
  matrix;
- announce asynchronous result, permission change, error, and destructive
  confirmation;
- avoid countdown pressure, shame, streaks, and coercive paywall behavior; and
- use plain language suitable for a person who may be tired or stressed.

Automated accessibility checks supplement but do not replace physical manual
testing.

## 12. Privacy, support, and legal utility

The following remain available in all access, account, network, and entitlement
states:

- bundled wellness/product-boundary notice;
- bundled privacy summary and terms snapshot plus current public links;
- support contact/method;
- local export and deletion;
- account export/deletion when account-linked;
- purchase restoration, subscription management, and refund-help route; and
- app version, policy versions, and non-sensitive diagnostic reference.

Legal copy must match observed data and processors. It may not be copied from a
competitor or treated as approved because it appeared in the PRD.

## 13. Definition of accepted requirement

A requirement is accepted only when:

- its stable `P1-*` ID links to controlling source IDs;
- its screen and every applicable state are specified;
- every field and processor is in the allowlist;
- claims and localized copy are approved;
- permissions and entitlements match the binary;
- offline, denial, interruption, retry, deletion, and accessibility behavior
  are specified;
- automated and/or physical test IDs are assigned;
- evidence passes on the approved matrix; and
- the accountable owner signs the Gate record.

Visual similarity, a passing simulator demo, or a happy-path unit test is not
acceptance evidence for system behavior.

## 14. Unresolved approvals

The specification intentionally does not pretend the following are approved:

- complete Figma child-node, component/variable, state, and prototype mapping,
  retained only as unavailable legacy evidence; Satyam Shree has approved
  superseding the conflicting visual source with this specification;
- exact neutral alarm and manual-action labels;
- exact audio titles, scripts, voices, licenses, and downloadable catalog;
- App Store Connect product IDs/localizations and StoreKit Sandbox evidence for
  the approved monthly, annual, lifetime, trial, no-grace, immediate-cutoff,
  and known-expiration-reminder configuration;
- minimum iOS deployment target and fallback;
- replacement public privacy/terms/support wording, entity/contact values,
  live URLs, and any required independent counsel review;
- diagnostics processor and retention; and
- independent iOS/backend/security/accessibility/release evidence.

These are Gate 0 blockers, not implementation TODOs.
