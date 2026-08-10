# Session Prompt: Phase 1D - Sleep Schedule and Pre-Sleep Audio

> **Amended 29 July 2026.** Any prior exclusion of personal recording/import or microphone permission is superseded by [Persona and Personal Audio Product Realignment](../phase-0/PERSONA_AND_PERSONAL_AUDIO_REALIGNMENT.md). Hidden/ambient/overnight recording and server-side personal audio remain prohibited; physical-device feasibility remains required.

You are working in the Sleep Paralysis Companion repository. This session is exclusively for **Phase 1D: Sleep schedule and pre-sleep audio**. Treat this prompt as the session's operating contract. Do not assume access to earlier chat.

## Entry gate

Read the execution plan, engineering guides, approved Phase 0 schedule/audio/platform/access artifacts, and prior phase handoffs. Inspect repository guidance and `git status`; preserve unrelated changes. Confirm the AlarmKit/fallback and audio decisions, deployment target, catalog/rights, data fields, offline promise, and required prior gates. Do not invent unapproved platform promises or content.

## Objective

Make the sleep schedule, free alarm, reminder fallbacks, and approved pre-sleep audio dependable across offline, lock, interruption, route, permission, time change, and lifecycle states.

## Commercial boundary

The alarm feature is always available without payment. Pre-sleep audio requires active RevenueCat `premium_access` backed by an Apple trial, subscription, or lifetime purchase; no grace. Use the shared injected access-policy interface; do not implement commerce/paywall internals or scatter entitlement/time checks through views. Privacy/data/account/purchase-management controls remain accessible.

## Required implementation

- Implement schedule create, edit, disable, and reconciliation using the approved wall-clock/calendar model.
- Correctly handle daylight-saving transitions, time-zone changes, locale/calendar changes, device clock changes, restart, reinstall, and schedule edits near firing time.
- Implement AlarmKit only on approved supported OS versions with availability checks, contextual authorization, purpose string, and tested scheduling/update/cancel behavior.
- Implement the approved UserNotifications or in-app fallback elsewhere. Label alarm, notification, and in-app reminder honestly; never promise equivalence.
- Show current authorization state and stable fallback for not-determined, allowed, denied, restricted where applicable, later revoked, and Settings changes.
- Implement the approved audio catalog, bundled/downloaded manifest, integrity validation, offline cache, cleanup, missing/corrupt asset recovery, and storage limits.
- Configure `AVAudioSession` only while genuinely needed. Enable background audio only for active user-selected playback.
- Handle calls, Siri, alarms, other-app audio, route changes, headphone disconnect, Bluetooth, lock, background, suspension, termination, and insufficient storage.
- Preserve playback intent without surprising automatic resume. Pause on headphone disconnect when required to avoid private speaker playback.
- Provide visible/text alternatives for essential audio information and accessible playback controls.
- Never activate or request microphone access. Never use silent audio or busy work to keep the process alive.

## Architecture/code rules

- Keep date/time/calendar/clock, schedule calculation, AlarmKit, UserNotifications, audio, storage, download, and access policy behind focused testable interfaces.
- SwiftUI views do not schedule alarms, manage audio sessions, read files, or perform downloads.
- Use explicit state machines for schedule authorization/fallback and audio lifecycle. Persist state before suspension and reconstruct deterministically.
- Use structured concurrency, cancellation, idempotent/resumable jobs, transactions where needed, typed errors, redacted logs, and no forced unwraps.
- Keep local/offline state authoritative for promised behavior; network enrichment never blocks the free alarm.

## Required tests/evidence

- Parameterized schedule tests for DST gaps/overlaps, time zones, locale/calendar, wall-clock versus instant, edits, disable, restart, and duplicate reconciliation.
- Permission tests for every authorization/revocation/Settings transition.
- Physical-device matrix across supported OS versions for lock, silent mode, Focus, restart, force quit, background/foreground, time changes, and fallback behavior.
- Audio tests for offline, missing/corrupt assets, poor network, calls, Siri, alarm interruption, route/headphone/Bluetooth changes, lock, termination, and appropriate resume.
- Access-policy tests prove the alarm is always free and pre-sleep audio requires verified premium access.
- VoiceOver, large text, Reduce Motion, increased contrast, silent/non-audio alternative, and one-handed controls.

## Evidence rule

Simulator/unit tests do not prove AlarmKit, Focus/silent mode, locked playback, background behavior, routes, or interruption behavior. If physical devices are unavailable, produce the exact protocol and mark those cases unverified; do not pass the gate.

## Gate 1D exit

Pass only when schedule behavior is physically verified across supported OS/device states, promised audio works offline, no microphone is used, interruptions/routes recover to the documented state, access gating is correct, and UI/copy never overstates iOS guarantees.

## Handoff

Report requirement IDs, outcome, files/assets changed, decisions used, automated evidence, physical-device matrix, accessibility/privacy impact, access-policy evidence, known limitations, blockers, whether Gate 1D passed, and the next safe Phase 1E work item. State what remains unverified.
