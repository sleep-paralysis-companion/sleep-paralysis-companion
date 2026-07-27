# Navigation and Screen/State Map

**Map ID:** `NAV-P1-001`  
**Status:** Canonical behavior approved; legacy Figma canvas retained as
superseded discovery evidence  
**Updated:** 25 July 2026

## 1. Navigation model

```text
Launch router
├─ First-use scope
│  └─ Home
├─ Home
│  ├─ Alarm setup/status
│  ├─ Grounding entry → Grounding session → Optional check-in
│  ├─ Preparation/audio library → Download manager
│  └─ Paywall/purchase when a premium route is not entitled
├─ History
│  └─ Entry detail/edit/delete
└─ Settings
   ├─ Permissions and alarm state
   ├─ Audio and downloads
   ├─ Sync/account
   ├─ Data and privacy → Export / Delete local data / Delete account
   ├─ Premium → Paywall / Restore / Manage subscription / Refund help
   └─ Help, privacy, terms, wellness notice, app information
```

Home, History, and Settings are the only persistent destinations. A task route
returns to its origin or Home deterministically; it does not create a hidden
navigation stack. Deep links and system actions are routed through
`SCR-001` and use the same entitlement, privacy, and state checks as in-app
navigation.

## 2. Reusable state inventory

Every screen explicitly marks applicable states. A blank area, infinite
spinner, disabled control without explanation, or silent failure is not a
state.

| ID | State | Required presentation and behavior |
|---|---|---|
| `ST-001` | Initial/routing | No stale private content; evaluate local profile, route, policy, entitlement, and deep-link validity once |
| `ST-002` | Loading | Preserve safe navigation/exit; label the task being checked; use timeout/recovery |
| `ST-003` | Ready | Controls reflect authoritative current state |
| `ST-004` | Empty | Explain why empty and offer one relevant action without shame |
| `ST-005` | Offline-usable | Show local state and permit documented local actions |
| `ST-006` | Offline-blocked | Identify the network-dependent action; preserve local data; offer retry |
| `ST-007` | Permission-not-determined | Explain purpose immediately before system request; allow cancel |
| `ST-008` | Permission-denied/restricted | Show actual state and honest limitation; link to Settings only when useful |
| `ST-009` | Unsupported | Name unavailable behavior and proven fallback; never simulate success |
| `ST-010` | Recoverable error | State what failed/changed, preserve data, offer idempotent retry |
| `ST-011` | Blocking integrity error | Do not use corrupt/unverified data or asset; offer safe local alternative |
| `ST-012` | Free utility | Alarm and utility routes available; premium routes label access |
| `ST-013` | Introductory trial | Premium routes available only from active RevenueCat `premium_access` backed by Apple trial state; show eligibility/expiration using Apple facts |
| `ST-014` | Premium | All product routes available from active RevenueCat `premium_access` backed by Apple state |
| `ST-015` | Known nonrenewing expiration | Premium remains active until the verified expiration; begin the in-app reminder at most 72 hours before expiration, no more than once per local day |
| `ST-016` | Entitlement/policy unknown | Free utilities only; check/restore action; device clock is not authority |
| `ST-017` | Purchase pending | No false entitlement; explain pending state and safe exit |
| `ST-018` | Sync pending/syncing | Local changes remain authoritative for UI; show progress without blocking core use |
| `ST-019` | Sync failed/conflicted | Preserve local and remote versions per contract; no silent overwrite |
| `ST-020` | Destructive confirmation | Name scope, irreversibility, remote/local effects, subscription effect, and cancel |
| `ST-021` | Destructive in progress | Prevent duplicate submission; allow app lifecycle recovery |
| `ST-022` | Destructive complete | Confirm only reconciled completion; identify separately pending work |
| `ST-023` | Destructive failed/partial | State exact completed/pending parts and idempotent recovery |
| `ST-024` | Accessibility variants | VoiceOver/focus, Dynamic Type, contrast, motion, Voice/Switch Control preserve meaning/action |
| `ST-025` | Sensitive background/lock | Hide private content; use neutral labels; restore intentionally |

## 3. Application screen inventory

### `SCR-001` — Launch router

- **Entry:** app icon, system action, deep link, restoration, notification or
  AlarmKit/App Intent action.
- **Reads:** local profile, current notice version, route validity, local
  entitlement/policy cache, account token status; never requires network to
  route to local core.
- **States:** `ST-001`, `ST-002`, `ST-005`, `ST-010`, `ST-025`.
- **Exit:** `SCR-002`, `SCR-004`, `SCR-008`, or an honest unsupported/recovery
  destination.
- **Acceptance:** route evaluation is idempotent; stale or malformed deep links
  disclose no private data and fall back to Home; no duplicate session/record
  is created.

### `SCR-002` — Welcome

- **Purpose:** identify the product as a nonmedical, manual wellness tool.
- **Data:** none until Continue.
- **States:** `ST-003`, `ST-024`.
- **Exit:** `SCR-003`; back/close behavior returns to welcome on next launch
  without creating a profile.
- **Acceptance:** no account, permission, questionnaire, price, review request,
  marketing consent, or upload.

### `SCR-003` — Product boundary and privacy summary

- **Purpose:** show `CLM-001`–`CLM-003`, data-local default, optional sync, and
  links to bundled legal/help material.
- **Write on Continue:** only the onboarding fields in `SPEC-P1-001 §7.1`.
- **States:** `ST-003`, `ST-024`.
- **Exit:** `SCR-004`.
- **Acceptance:** Continue creates one guest profile transactionally; repeated
  taps cannot create duplicate profiles; informative notice is not presented as
  medical consent or rights waiver.

### `SCR-004` — Home

- **Purpose:** calm overview with alarm status, one primary manual-grounding
  action, and small preparation entry points.
- **States:** `ST-002`–`ST-016`, `ST-018`, `ST-019`, `ST-024`, `ST-025` as
  applicable.
- **Transitions:** alarm → `SCR-005`; grounding → `SCR-008` or `SCR-015`;
  preparation → `SCR-011`; History/Settings persistent destinations.
- **Acceptance:** alarm status reconciles to system truth; no episode status,
  risk, streak, shame, false urgency, inferred insight, or private lock-screen
  restoration.

### `SCR-005` — Alarm setup

- **Purpose:** choose supported time, recurrence, and approved snooze.
- **Reads/writes:** `DATA-ALARM`; write intent locally and system schedule only
  through an atomic/recoverable operation.
- **States:** `ST-002`, `ST-003`, `ST-005`, `ST-007`–`ST-011`, `ST-024`.
- **Transitions:** permission explainer/system prompt → `SCR-SYS-001`; success
  → `SCR-006`; cancel → origin.
- **Acceptance:** validates time/recurrence; explains time-zone behavior; does
  not claim success until system reconciliation; denial does not block Home.

### `SCR-006` — Alarm status/detail

- **Purpose:** show actual scheduled state and allow edit, enable/disable,
  reschedule, or removal.
- **States:** `ST-002`, `ST-003`, `ST-005`, `ST-008`–`ST-011`, `ST-020`–`ST-024`.
- **Acceptance:** external Settings changes, deleted system alarm, restart,
  DST/time-zone change, or scheduling failure never leave a false “set” state;
  removal confirmation distinguishes app intent and system object.

### `SCR-007` — Permission and capability status

- **Purpose:** show actual AlarmKit and any approved fallback authorization;
  explain how to recover.
- **States:** `ST-003`, `ST-007`–`ST-010`, `ST-024`.
- **Acceptance:** refreshed on foreground and after Settings; no request for
  microphone, Health, location, contacts, camera, photos, Bluetooth, or
  tracking; notification authorization appears only if the fallback/feature is
  approved.

### `SCR-008` — Grounding entry

- **Purpose:** resolve manual action, entitlement, local asset availability, and
  modality without logging an experience.
- **States:** `ST-002`, `ST-005`, `ST-009`–`ST-016`, `ST-024`, `ST-025`.
- **Transitions:** entitled → `SCR-009`; not entitled → `SCR-015`; corrupt
  preferred asset → silent/bundled alternative.
- **Acceptance:** one intentional activation maps to one session; repeated
  activation is idempotent; no check-in row or analytics wellness fact is
  created.

### `SCR-009` — Grounding session

- **Purpose:** approved audio, visual, or silent grounding.
- **Controls:** play/pause when audio, modality, transcript/instructions, Stop,
  Done.
- **States:** `ST-003`, `ST-005`, `ST-009`–`ST-011`, `ST-024`, `ST-025`.
- **Transitions:** Done → `SCR-010`; Stop/close → origin/Home.
- **Acceptance:** usable offline from bundle; handles interruption/route/lock;
  no autoplay surprise from ordinary app launch; no factual assertion about
  the person's physiological or safety state.

### `SCR-010` — Grounding completion

- **Purpose:** neutral completion with “Done for now” and optional check-in.
- **States:** `ST-003`, `ST-012`–`ST-016`, `ST-024`.
- **Transitions:** Done → Home; optional check-in → `SCR-013` if entitled,
  otherwise `SCR-015`.
- **Acceptance:** no rating, forced log, streak, celebratory clinical outcome,
  or repeated paywall pressure.

### `SCR-011` — Preparation/audio library

- **Purpose:** list only approved catalog items, bundled/downloaded state,
  accessibility transcript, and size.
- **States:** `ST-002`–`ST-016`, `ST-024`.
- **Transitions:** item playback → `SCR-009`; download/remove → `SCR-012`;
  unavailable premium → `SCR-015`.
- **Acceptance:** every visible item has catalog/rights/claims approval; network
  items never masquerade as local; no YouTube reference is a shipping asset.

### `SCR-012` — Download manager

- **Purpose:** download, verify, install, retry, and remove optional catalog
  assets; show storage use.
- **States:** `ST-002`, `ST-004`–`ST-006`, `ST-010`, `ST-011`, `ST-020`–`ST-024`.
- **Acceptance:** partial/corrupt download never becomes playable; minimum
  bundled content is not evicted; removal does not remove currently playing
  bytes unsafely; cancellation/relaunch is recoverable.

### `SCR-013` — Optional check-in

- **Purpose:** create/edit the candidate contract in `SPEC-P1-001 §8.3`.
- **States:** `ST-003`, `ST-005`, `ST-010`, `ST-012`–`ST-016`, `ST-020`,
  `ST-024`, `ST-025`.
- **Transitions:** Save → `SCR-014`; Not now → origin; premium unavailable →
  `SCR-015`.
- **Acceptance:** explicit Save only; conditional intensity; note boundary;
  no inferred values; clear edit versus new; accessible errors; no forced
  completion.

### `SCR-014` — History

- **Purpose:** local submitted entries and permitted descriptive summaries.
- **States:** `ST-002`–`ST-006`, `ST-010`, `ST-012`–`ST-016`, `ST-018`,
  `ST-019`, `ST-024`, `ST-025`.
- **Transitions:** entry → `SCR-014A`; premium unavailable → `SCR-015`.
- **Acceptance:** empty state is neutral; dates/calendars are honest; textual
  chart equivalent; screen reconciles after edits, delete, sync, sign-out, and
  relaunch; no risk/causal/clinical inference.

### `SCR-014A` — Entry detail/edit/delete

- **Purpose:** display exact submitted values; edit or delete.
- **States:** `ST-003`, `ST-005`, `ST-010`, `ST-018`–`ST-024`, `ST-025`.
- **Acceptance:** edit history is not exposed to analytics; deletion hides the
  entry locally immediately and follows tombstone rules; failed remote deletion
  is explicit; no resurrected row after reconnect.

### `SCR-015` — Premium explanation/paywall

- **Purpose:** explain premium features and show
  StoreKit products.
- **States:** `ST-002`, `ST-006`, `ST-012`–`ST-017`, `ST-024`.
- **Controls:** Purchase, Restore, Manage subscription, Terms, Privacy, close.
- **Acceptance:** exact localized price/period/renewal from StoreKit; no fake
  timer, custom trial clock, preselected purchase, fear, health outcome claim, or
  close obstruction; alarm and utility-free routes stay available.

### `SCR-016` — Purchase result

- **Purpose:** show verified result and recovery.
- **States:** `ST-002`, `ST-010`, `ST-014`–`ST-017`, `ST-024`.
- **Acceptance:** cancellation is not an error; pending is not entitled;
  unverified never unlocks; success updates all affected routes once; refund,
  revoke, expiry, reminder, and immediate cutoff reconcile on foreground,
  CustomerInfo update, and transaction update.

### `SCR-017` — Settings

- **Purpose:** grouped controls for alarm, grounding/audio, permission status,
  sync/account, privacy/data, premium, accessibility preferences, help/legal,
  and app information.
- **States:** `ST-002`–`ST-019`, `ST-024`.
- **Acceptance:** each row shows actual state or neutral navigation; account and
  premium remain separate; utility routes never disappear behind entitlement.

### `SCR-018` — Sync/account

- **Purpose:** explain optional sync, authenticate, convert, show sync state,
  reauthenticate, sign out, or navigate to account deletion.
- **Authentication choices:** Sign in with Apple and Sign in with Google only;
  guest mode remains available.
- **States:** `ST-002`, `ST-005`, `ST-006`, `ST-010`, `ST-018`–`ST-024`,
  `ST-025`.
- **Acceptance:** no account-first pressure; exact data list before conversion;
  provider errors, cancellation, collision/linking, verification, recovery,
  and reauthentication are explicit; existing-remote-data choice;
  transactional rollback; no cross-account data exposure; subscription state
  not described as account state.

### `SCR-019` — Data and privacy

- **Purpose:** field/processor summary, policy links, export, record/local data
  deletion, conditional account deletion, diagnostics setting if approved.
- **States:** `ST-002`, `ST-005`, `ST-006`, `ST-010`, `ST-020`–`ST-024`.
- **Acceptance:** exported/deleted scope is explicit; bundled copies remain
  viewable offline; public current version labels when online; account deletion
  and local reset are not conflated.

### `SCR-020` — Export

- **Purpose:** create the documented local or reconciled account export and
  pass it to a user-selected destination.
- **States:** `ST-002`, `ST-005`, `ST-006`, `ST-010`, `ST-021`–`ST-024`.
- **Acceptance:** manifest identifies scope/time; excludes tokens, internal
  diagnostics, tombstones, and copyrighted audio; temporary export removed
  after share completion/cancel according to retention rule; no hidden upload.

### `SCR-021` — Delete local app data

- **Purpose:** clear local profile/data, system alarms created by the app,
  shared extension state, drafts, queue, tokens, caches, and approved local
  diagnostics.
- **States:** `ST-020`–`ST-024`.
- **Acceptance:** confirmation names that account/cloud data and Apple
  subscription are separate; operation is restart-safe; completion returns to
  `SCR-002`; account-linked remote data is not falsely reported deleted.

### `SCR-022` — Delete account

- **Purpose:** initiate full remote account/data deletion, reauthenticate when
  appropriate, select immediate local disposition, and track completion.
- **States:** `ST-006`, `ST-010`, `ST-020`–`ST-024`.
- **Acceptance:** reachable in-app for every account; explains deadline,
  retained legal exceptions, applicable Apple/Google authorization revocation,
  local effect, and Apple subscription continuation/cancellation; support
  contact is not a mandatory gate.

### `SCR-023` — Premium and purchase utilities

- **Purpose:** current entitlement state, Restore, Manage subscription, Refund
  help, and paywall.
- **States:** `ST-002`, `ST-006`, `ST-010`, `ST-012`–`ST-017`, `ST-024`.
- **Acceptance:** available to guest and account-linked users; shows verified
  RevenueCat entitlement and Apple purchase state; no custom external payment
  unlock in Phase 1.

### `SCR-024` — Help, legal, and app information

- **Purpose:** wellness notice, privacy summary/policy, terms, support, app and
  policy versions, and approved general help.
- **States:** `ST-003`, `ST-005`, `ST-006`, `ST-010`, `ST-024`.
- **Acceptance:** bundled readable snapshot plus current public link; no
  copied/unapproved competitor policy, personal medical advice, unsupported
  claim, or entitlement requirement.

## 4. System surfaces

| ID | Surface | Gate condition and privacy rule |
|---|---|---|
| `SCR-SYS-001` | AlarmKit authorization prompt | Just-in-time after product explanation; `NSAlarmKitUsageDescription` matches actual purpose |
| `SCR-SYS-002` | AlarmKit alert/Lock Screen/StandBy/Dynamic Island | Neutral title; no profile/check-in detail; stop/snooze/custom action proven physically |
| `SCR-SYS-003` | Manual App Intent/control/widget surface | Exact surface chosen only after spike; manual, idempotent, private, and useful when offline |
| `SCR-SYS-004` | Optional notification fallback | Exists only if target decision approves it; honestly labeled less-prominent behavior |
| `SCR-SYS-005` | StoreKit purchase sheet | Product fetched from StoreKit; cancellation/pending/verification handled |
| `SCR-SYS-006` | Share/export sheet | User-initiated; temporary export lifecycle enforced |
| `SCR-SYS-007` | iOS Settings | Deep link only for recoverable permission/configuration; app refreshes actual state on return |
| `SCR-SYS-008` | Subscription management/refund | Apple's management/refund surface; available regardless of account/entitlement |

## 5. Destructive-action semantics

| Action | Confirmation must say | Reversal/recovery |
|---|---|---|
| Delete one entry | Entry date and local/remote effect | No user-facing undo after remote tombstone; cancel before confirm |
| Remove downloaded audio | Asset title and redownload requirement | Redownload if still licensed/entitled |
| Remove alarm | System alarm and local schedule effect | Recreate manually |
| Delete local app data | Local-only scope, cloud/account separation, subscription separation | Export first; account sync may redownload only after explicit sign-in choice |
| Sign out | Local protected-data disposition, queued changes, and offline effect | Reauthenticate; never expose to a different account |
| Delete account | Remote data scope, completion time, retained legal exceptions, local choice, subscription continuation | Reauthentication and confirmation; immediate deletion remains available even with active subscription |

## 6. Legacy Figma disposition

For any new implementation/design review, every `SCR-*` and applicable `ST-*`
combination must map to:

- Figma file revision;
- page/frame/component/node ID;
- prototype entry and exit;
- exact copy record (`CLM-*`);
- compact/large device layout;
- light/dark appearance if supported;
- all Dynamic Type designs or documented adaptive rule;
- loading, empty, offline, denied, unsupported, error, purchase, sync,
  destructive, and completion state; and
- Product/Design/Accessibility approval.

The read-only [Figma audit](./FIGMA_READ_ONLY_AUDIT.md) confirms the exact file
key, starting page, page names, and canvas-level visual evidence. It maps the
visibly identifiable concepts to this screen/state inventory and confirms:

- partial visual intent for onboarding, alarm, grounding/audio, settings,
  check-in/history, purchase, and lock-screen concepts;
- material conflicts involving account-first onboarding, questionnaire/profile
  data, detection/Guardian Mode/voice, risk/analytics/clinician flows,
  legacy trials, and check-in copy/options; and
- missing or unverified empty, offline, permission, unsupported, error,
  destructive, sync, recovery, accessibility, and complete purchase/auth state
  families.

Satyam Shree approved `D0-025` on 25 July 2026: the legacy canvas remains
discovery evidence, while this map and the canonical specification define
behavior. The missing child hierarchy is therefore not a Gate 0 dependency.
Canvas screenshots still do not prove node identity or transition semantics,
and no Figma design was mutated.
