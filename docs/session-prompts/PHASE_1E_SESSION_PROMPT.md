# Session Prompt: Phase 1E - Manual Episode Action and Grounding

You are working in the SP / Paralux repository. This session is exclusively for **Phase 1E: Manual episode action and grounding**. Treat this prompt as the session's operating contract. Do not assume access to earlier chat.

## Entry gate

Read the execution plan, engineering guides, approved Phase 0 claims/access/platform/grounding artifacts, physical feasibility report, and prior handoffs. Inspect repository guidance and `git status`; preserve unrelated changes. Confirm the selected Lock Screen/control/App Intent surface has approved physical-device evidence. If that evidence is absent, do not guess or ship the integration.

## Objective

Provide the simplest reliable, explicitly user-initiated path to calm grounding under stress, including offline and terminated-app behavior, without implying detection or emergency response.

## Commercial boundary

Manual episode action and grounding require active RevenueCat `premium_access` backed by an Apple trial, subscription, or lifetime purchase; no grace; only the alarm remains a free product feature. Follow the approved Phase 0 access UX exactly. Do not place a surprise paywall inside an active grounding sequence. Hide, disable, or gate external entry surfaces honestly according to the approved entitlement design. Use the shared access-policy boundary; do not implement commerce internals here. Privacy/legal/support, export/deletion, applicable account deletion, purchase restoration, and subscription-management controls remain accessible without entitlement.

## Required implementation

- Implement the approved manual App Intent/control/widget/deep-link entry surface using the same domain operation as the main app.
- Make initiation explicitly user-driven. Do not run sensors, models, timers, background inference, or automatic record creation.
- Minimize steps, cognitive load, reading burden, visual density, and required precision after activation.
- Start useful grounding from locally available content; network enrichment never blocks entry.
- Support approved audio, readable visual guidance, silent mode, and appropriate optional haptics.
- Handle locked-device limits, required authentication, unavailable/disabled extension, no entitlement, offline state, app termination, stale deep links, cancellation, repeated taps, and concurrent invocation.
- Make repeated activation idempotent: no duplicate episode/check-in records and no overlapping audio sessions.
- Provide an unobtrusive exit and optional later route to check-in. Never force logging.
- Create no episode record unless approved UX makes the user action and result explicit.
- Keep Lock Screen/widget/control wording neutral and nonsensitive; expose no profile answers, episode detail, check-in data, or private history.
- Use calm approved language with no detection, prevention, treatment, emergency, rescue, or guaranteed-outcome implication.

## Architecture/code rules

- App Intents are lightweight wrappers over existing domain operations and must work in supported foreground/background/extension contexts.
- Register required dependencies early and keep extension-shared state minimal. App Groups must not contain privileged credentials or an unrestricted user database.
- Use an opening intent when app UI/authentication/access UX is required.
- Use explicit invocation/grounding/audio state machines, stable IDs, transactions, structured concurrency, cancellation, and privacy-safe logging.
- SwiftUI views and intent wrappers do not duplicate business rules or access-policy logic.
- Do not use notification/background execution as a detector or substitute for an alarm.

## Required tests/evidence

- Domain/App Intent tests cover locked/unlocked, foreground/background/terminated, offline, stale link, unavailable extension, authentication, access allowed/denied, repeated/concurrent invocation, cancellation, and recovery.
- Physical-device tests cover every supported surface/OS, exact tap-to-useful-grounding path, launch latency, locked limitations, force quit, restart, and network loss.
- Persistence/audio tests prove idempotency and no unintended record.
- Access tests prove premium gating without surprise gating mid-flow and alarm/data-rights continuity.
- VoiceOver, all Dynamic Type sizes, Reduce Motion, increased contrast, silent use, one-handed reach, Voice Control, and Switch Control.
- Claims/privacy review covers every surface, notification, widget/control label, screenshot, and review note.

## Evidence rule

Do not infer Lock Screen or extension behavior from Simulator or API documentation. If physical evidence is missing, produce a reproducible protocol and leave Gate 1E unpassed.

## Gate 1E exit

Pass only when every supported physical path is proven and accurately documented, offline/terminated entry reaches useful grounding when access is allowed, activation is idempotent, accessibility passes, access gating is deterministic, and no record is created without clear user action.

## Handoff

Report requirement IDs, outcome, files/targets changed, selected surface and decisions, automated evidence, physical-device evidence, accessibility/claims/privacy impact, access behavior, limitations, blockers, whether Gate 1E passed, and the next safe Phase 1F work item. State what remains unverified.
