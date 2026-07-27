# Platform Feasibility Report and Physical-Device Protocol

**Report ID:** `FEAS-P1-001`  
**Status:** Official capability verification and test protocol complete;
physical proof **NOT EXECUTED**  
**Updated:** 24 July 2026

## 1. Current conclusion

No deployment target or locked/system-surface claim is approved.

Official Apple documentation confirms that AlarmKit can schedule prominent
alarms/timers on iOS/iPadOS 26, uses per-app authorization, requires
`NSAlarmKitUsageDescription`, supports Lock Screen-related presentations, and
can use App Intents for custom actions. This establishes API availability, not
Sleep Paralysis Companion behavior.

The current workspace is Windows and has no local Xcode/iOS Simulator signing
environment or attached physical-iPhone evidence. On 25 July 2026, Satyam
Shree confirmed access to an Apple Developer account, App Store Connect, a
physical iPhone running iOS 26, and authorized an isolated hosted-macOS/
TestFlight spike under this report. Those prerequisites enable execution but
are not evidence that any scenario has passed. Production feature code was not
created.

The disposable source package now exists at
`spikes/phase0-platform-feasibility/` with a repository-root Codemagic workflow.
It includes neutral AlarmKit scheduling/custom action, explicit synthetic
audio, privacy-safe evidence export, and disposable StoreKit probes. It has not
been compiled, signed, uploaded, installed, or run; those states remain
`UNPROVEN`.

The selected Git remote is
`https://github.com/sleep-paralysis-companion/sleep-paralysis-companion.git`.
Reachability was verified against the empty remote on 25 July 2026. The
validated baseline was then published to `origin/main` at commit
`7fa790a0b46b457144531319337d73cc1b0a45f2`. Repository publication is
therefore complete. Codemagic project connection, App Store Connect
integration, hosted compilation/signing/upload, and physical execution remain
separate evidence steps.

### 1.1 Physical iPhone requirement

Yes. A physical iPhone is required before Gate 0 can approve AlarmKit and the
locked/manual-entry design. Simulator or API documentation cannot prove Silent
mode, Focus, Lock Screen and authentication behavior, termination/restart,
background/locked audio, real notification presentation, route interruptions,
Data Protection before first unlock, performance, or assistive-technology use.

Most documentation, architecture, SwiftUI layout work, unit tests, and
simulator UI tests can proceed without a device. One compatible physical
iPhone—owned, borrowed, or supplied by a named tester—is enough to start the
disposable feasibility spike and retire the highest-risk unknowns. Before App
Store release, at least two representative physical models are required,
including the oldest supported class and a current class; platform-sensitive
tests run on every applicable matrix cell.

### 1.2 When no local Mac is available

Owning a Mac is not required, but an Apple-supported macOS/Xcode environment is
still required somewhere to compile, sign, archive, and upload an iOS build.
Windows plus an iPhone alone cannot replace that toolchain.

Recommended no-local-Mac path:

1. Keep a valid native Xcode project/workspace—or an approved declarative
   project-generation specification—in the repository.
2. Use a hosted macOS iOS build service such as Codemagic to compile the
   isolated spike. Its App Store Connect integration can create/fetch signing
   certificates and provisioning profiles automatically without a local Mac.
3. Upload the spike as an internal TestFlight build from that hosted workflow.
4. Install it through TestFlight on the arranged physical iPhone and run the
   AlarmKit, lock, Silent/Focus, restart, time, audio, privacy, and
   accessibility matrix.
5. Capture screen recordings, exact device/OS/state notes, and an
   app-generated privacy-safe diagnostic/evidence export. Direct USB debugging
   is useful but is not required for every acceptance observation.
6. Use hosted build logs and artifacts for compile/test diagnosis. If a
   platform issue genuinely requires interactive Xcode, temporarily use a
   borrowed or remotely hosted Mac rather than purchasing one.

[Codemagic's native iOS workflow](https://docs.codemagic.io/yaml-quick-start/building-a-native-ios-app/)
can build and submit to TestFlight, and its
[automatic signing flow](https://docs.codemagic.io/flutter-code-signing/ios-code-signing/)
can manage certificates/profiles through an App Store Connect API key without
a Mac. `codemagic.yaml`, credentials, access scope, secrets, logs, artifacts,
and billing still require security/finance approval before use.

[Xcode Cloud](https://developer.apple.com/xcode-cloud/) can also build and send
builds to TestFlight, but its initial product/workflow setup is performed
through Xcode, so it is not the easiest no-Mac bootstrap. [GitHub-hosted macOS
runners](https://docs.github.com/en/actions/reference/runners/github-hosted-runners)
can compile and test after the repository/project/signing workflow exists.
[Amazon EC2 Mac](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-mac-instances.html)
is one remote-Mac option, but it uses a Dedicated Host with a 24-hour minimum
allocation. A simpler hosted-Mac provider or a borrowed Mac may therefore be
more economical for the first bootstrap.

Cloud simulators and ordinary device farms do not replace the arranged iPhone
for hardware-dependent Gate 0 evidence. Remote Mac access also does not
magically attach the local iPhone by USB; TestFlight is the practical bridge.

## 2. Target options

| Option | Shape | Benefit | Cost/risk | Decision state |
|---|---|---|---|---|
| `TARGET-A` | Minimum iOS 26; AlarmKit is the alarm path | One honest prominent-alarm model, less fallback complexity | Excludes devices unable/unwilling to run iOS 26; still requires full physical proof | `RECOMMENDED FOR SPIKE`, not approved |
| `TARGET-B` | Minimum below iOS 26; AlarmKit when available plus UserNotifications/in-app fallback | Wider device reach | Different reliability/claims/permission paths; more screen/test/review complexity; fallback must never be called an alarm equivalent | `ALTERNATIVE`, not approved |

Product supplies desired supported-device coverage before the spike. iOS/QA
record which currently available physical models/OS builds represent it. Do not
select a target from simulator availability, market-share assumption, or API
compilation alone.

## 3. Questions the spike must answer

| ID | Question | Required decision |
|---|---|---|
| `FEAS-Q-001` | Can an authorized Sleep Paralysis Companion AlarmKit alarm be scheduled, reconciled, edited, disabled, removed, snoozed, and restored honestly? | Alarm architecture and copy |
| `FEAS-Q-002` | What occurs in Silent mode, each relevant Focus configuration, lock, app termination, restart, and clock/time-zone change? | Supported behavior and conditional claims |
| `FEAS-Q-003` | Which user-initiated surface reaches grounding with the least friction and acceptable privacy: AlarmKit custom action, App Intent, Control, widget, or ordinary deep link? | Exact system surface/capabilities |
| `FEAS-Q-004` | Does the chosen action require unlock/authentication in each state, and can it operate offline with the app terminated? | Honest locked-state UX |
| `FEAS-Q-005` | How do repeated actions, stale deep links, and simultaneous app launches resolve? | Idempotency state machine |
| `FEAS-Q-006` | Can approved audio start/continue/stop under lock/background with the necessary Data Protection and audio-session configuration? | Background mode/file protection |
| `FEAS-Q-007` | How do AlarmKit, grounding audio, calls, Siri, other audio, and route changes interact? | Audio interruption contract |
| `FEAS-Q-008` | What is the lowest target/device on which every included core path meets performance/accessibility gates? | Minimum deployment target |
| `FEAS-Q-009` | If `TARGET-B`, what exactly does the notification fallback do and fail to do? | Separate fallback requirements/copy |
| `FEAS-Q-010` | What private information appears in Lock Screen, StandBy, Dynamic Island, notification previews, Control/widget, and app switcher? | System-surface privacy |

## 4. Disposable spike boundary

The spike is allowed before Gate 0 only under this protocol:

- separate `spikes/phase0-platform-feasibility/` project/target or isolated
  branch/worktree;
- no production module imports and no code copied into production without a
  fresh implementation review;
- dummy neutral name/copy and one synthetic local audio tone/instruction owned
  for testing;
- no Supabase, real account, StoreKit product, analytics, check-in schema,
  personal data, microphone, HealthKit, or production credential;
- only AlarmKit, proposed App Intent/system surface, minimal local playback,
  and instrumentation needed for timing/state evidence;
- separate bundle IDs/provisioning and development environment;
- source clearly marked `DISPOSABLE — NOT FOR SHIPPING`;
- results committed as report/evidence; spike binary/credentials removed or
  archived according to security policy; and
- Product/iOS/Security confirm it cannot enter a release target accidentally.

The spike may answer feasibility only. It does not decide product copy, schema,
navigation, entitlement, or architecture by becoming de facto production code.

## 5. Physical device matrix

Record exact model, hardware identifier, OS version/build, battery/thermal
state, locale, calendar, time zone, appearance, accessibility settings,
authorization, network, Focus, silent, and app lifecycle for each run.

Minimum physical representatives:

| Device class | Purpose |
|---|---|
| Oldest model and OS build proposed for support | Performance, memory, target feasibility |
| Compact/smallest supported display | Reachability, Dynamic Type, visual density |
| Non-Dynamic-Island device if supported | Lock/System surface differences |
| Dynamic-Island device if supported | Dynamic Island presentation/action |
| Current large-display iPhone on current stable OS | Current platform and layout |
| Current beta OS/device | Informational regression only; never replaces stable release evidence |
| iPad compatibility mode | Only if App Store distribution allows installation; document or intentionally exclude |

At least two physical models run every critical test. Platform-sensitive tests
run on every matrix cell.

## 6. Scenario matrix

### AlarmKit and permission

| Test ID | Scenario | Pass condition |
|---|---|---|
| `T-SLP-001-DEVICE-AUTH-FIRST` | First schedule, authorization not determined | Purpose explanation precedes system prompt; cancel/allow outcomes exact |
| `T-SLP-002-DEVICE-AUTH-DENIED` | Deny then schedule | No false schedule; useful honest recovery; Home remains usable |
| `T-SLP-002-DEVICE-SETTINGS` | Change authorization externally | App refreshes actual state on foreground |
| `T-SLP-003-DEVICE-SCHEDULE` | One-time and approved recurrence | System object and app detail agree after relaunch |
| `T-SLP-004-DEVICE-SILENT-FOCUS` | Alert in ring/silent and relevant Focus | Observed behavior recorded; copy claims only passing states |
| `T-SLP-005-DEVICE-LIFECYCLE` | Foreground/background/suspended/terminated/restart | Alert and app state follow documented result |
| `T-SLP-006-DEVICE-TIME` | DST, time-zone, manual clock, recurrence boundary | Policy is explicit; no duplicate/missed local state hidden |
| `T-SLP-007-DEVICE-EDIT-REMOVE` | Edit, disable, remove, system object missing | App reconciles without phantom “set” state |
| `T-SLP-008-DEVICE-SNOOZE` | Snooze/stop/custom action | Buttons do exactly labeled action once |
| `T-SLP-009-DEVICE-MULTIPLE` | Repeated schedule/update taps | One intended system alarm; no duplicate |
| `T-SLP-010-DEVICE-PRIVACY` | Locked/preview/StandBy/Dynamic Island | Neutral content; no check-in/profile detail |
| `T-SLP-011-DEVICE-FALLBACK` | Unsupported path if `TARGET-B` | Fallback is distinct, useful as specified, and never overclaimed |

### Manual entry and app lifecycle

| Test ID | Scenario | Pass condition |
|---|---|---|
| `T-ACT-001-DEVICE-SURFACES` | Evaluate each proposed surface | Evidence ranks steps, time, privacy, availability, accessibility |
| `T-ACT-002-DEVICE-LOCKED` | Locked, auth required/not required | Exact unlock behavior documented; no private preview |
| `T-ACT-003-DEVICE-OFFLINE-COLD` | Offline, app terminated/not yet running this boot | Useful bundled/silent grounding reached or surface rejected |
| `T-ACT-004-DEVICE-REPEAT` | Rapid/repeated/parallel activation | One session/player; no duplicate record or route |
| `T-ACT-005-DEVICE-STALE` | Stale/malformed/deleted-version deep link | Safe Home/recovery; no crash/data exposure |
| `T-ACT-006-A11Y-SYSTEM` | VoiceOver, Voice Control, Switch Control | Surface label/action and app focus are operable |

### Audio/interruption

| Test ID | Scenario | Pass condition |
|---|---|---|
| `T-GRD-002-DEVICE-OFFLINE` | Bundle start offline | Approved content starts within threshold without server |
| `T-GRD-003-DEVICE-LOCK` | Lock/unlock/background/foreground | Continue/pause is consistent, private, and controllable |
| `T-GRD-005-DEVICE-CALL-SIRI` | Call/Siri interruption | No overlap; approved pause/resume; controls recover |
| `T-GRD-005-DEVICE-ROUTE` | Headphone/Bluetooth/AirPlay route changes | Approved route policy; no unexpected loud output/overlap |
| `T-GRD-005-DEVICE-ALARM` | Alarm before/during/after grounding | Alarm and audio resolve deterministically |
| `T-GRD-005-DEVICE-RESTART` | Restart/file protected before first unlock | Actual availability matches copy; silent fallback remains |
| `T-GRD-005-DEVICE-CORRUPT` | Corrupt/truncated/unsupported item | Item not played; safe bundled/silent alternative |

### Time, commerce, and offline

| Test ID | Scenario | Pass condition |
|---|---|---|
| `T-SET-007-DEVICE-TRIAL` | Eligible/ineligible, start, trial-to-paid conversion, cancel, and expiry | StoreKit eligibility/state and paywall copy are exact; alarm always remains |
| `T-SET-007-DEVICE-CLOCK` | Wall clock ±days, time zone/DST | Access follows verified signed StoreKit state, not device-clock manipulation |
| `T-SET-007-DEVICE-REBOOT-OFFLINE` | Verified unexpired trial/subscription, reboot, stay offline | Signed expiration behavior and copy match `COM-P1-001`; no custom grace |
| `T-SET-008-DEVICE-STOREKIT` | Monthly/annual/lifetime, no-grace retry, known-expiration reminder, immediate cutoff, expired/refunded/revoked/restore | RevenueCat/StoreKit verified state maps to the commercial matrix |

## 7. Performance and reliability gates

Values are `PROPOSED` until iOS/QA/Product approve them before running:

| Metric | Proposed gate |
|---|---|
| Manual action to first useful bundled/silent grounding UI | p95 ≤2.0 seconds on oldest supported device, warm or cold state recorded separately |
| Visible grounding UI to audible start for local asset | p95 ≤1.0 second after explicit start |
| Repeated manual activations | Exactly one current session/player and zero automatic check-in rows |
| Alarm schedule/edit/remove UI result | Authoritative success/failure visible ≤2.0 seconds under normal local system conditions |
| Main-thread stalls in critical route | No user-visible stall ≥250 ms attributable to app work |
| Offline core success | 100% of required matrix cases without server |
| Crash/data-loss/duplicate alarm/duplicate audio | Zero in acceptance runs |
| Accessibility critical blockers | Zero |
| Private content on locked/system surface | Zero |

Record sample size, distribution, instrumentation overhead, thermal state, and
raw evidence. A single passing video does not establish p95.

## 8. Evidence package

Each `E-*` record includes the metadata in
[Test and source traceability](./TEST_AND_SOURCE_TRACEABILITY.md), plus:

- spike commit and signed build;
- capability/entitlement/Info.plist snapshot;
- system authorization before/after;
- screen recording from a second camera when locked/system behavior is not
  captured by device recording;
- timestamped instrumentation for route/audio;
- device console excerpts with private data redacted;
- expected versus observed behavior and claim impact;
- pass/fail/unsupported classification;
- reproducibility count; and
- tester plus iOS/QA reviewer.

## 9. Deployment-target decision rule

Choose the lowest target only after:

1. Product records required device coverage.
2. Every included core path passes the corresponding stable physical matrix.
3. The selected system surface meets privacy, accessibility, latency, and
   lifecycle gates.
4. If target is below iOS 26, the fallback has separately approved
   requirements/copy and passes its full matrix.
5. App size/performance/accessibility on the oldest cell pass.
6. App Review/metadata describe the actual behavior.
7. Product, iOS, Design, Privacy, Accessibility/QA, and Release sign.

If `TARGET-B` fails any honesty/usefulness gate, select `TARGET-A` or remove the
affected capability. Do not hide the failure behind a generic notification
claim.

## 10. Current evidence table

| Area | Official API evidence | App simulator | App physical device | Result |
|---|---|---|---|---|
| AlarmKit availability/authorization concept | Yes, official Apple sources verified 23 July 2026 | None | None | `UNPROVEN` |
| Silent/Focus/lock/restart behavior | General Apple description only | None | None | `UNPROVEN` |
| App Intent/control/widget choice | General API availability only | None | None | `UNPROVEN` |
| Offline terminated launch | None specific to this app | None | None | `UNPROVEN` |
| Background/locked audio and interruption | General AVFAudio guidance only | None | None | `UNPROVEN` |
| Data Protection before/after first unlock | General platform guidance only | None | None | `UNPROVEN` |
| StoreKit trial/subscription/lifetime boundaries | General StoreKit guidance only | None | None | `UNPROVEN` |
| Accessibility/stressed use | Standards only | None | None | `UNPROVEN` |

Gate 0 therefore cannot pass, and no copy may state that Sleep Paralysis Companion already
supports these conditions.
