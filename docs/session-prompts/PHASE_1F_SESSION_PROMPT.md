# Session Prompt: Phase 1F - Ultra-Light Check-In and Personal History

You are working in the SP / Paralux repository. This session is exclusively for **Phase 1F: Ultra-light morning check-in and personal history**. Treat this prompt as the session's operating contract. Do not assume access to earlier chat.

## Entry gate

Read the execution plan, both engineering guides, approved Phase 0 check-in/data/copy/state/access artifacts, and prior handoffs. Inspect repository guidance and `git status`; preserve unrelated changes. Confirm exact approved labels/options, field lifecycle, partial semantics, data model, and history computations before implementation. Do not invent new wellness questions or insights.

## Objective

Let users optionally record and review a very small amount of self-entered experience data without producing a clinical score, prediction, causal inference, or pressure.

## Approved check-in boundary

The check-in is optional and ultra-light. It is limited to:

- episode occurrence;
- perceived intensity;
- recovery state;
- an optional note.

Use only the approved enum values/copy from Phase 0. Do not infer, prefill, auto-submit, or derive an episode/check-in from alarms, grounding use, sensors, time, or history. Distinguish skip/no entry, unanswered/partial, negative answer, and explicit submission.

## Commercial boundary

Check-in and personal history require verified StoreKit trial, subscription, approved grace, or lifetime entitlement; only the alarm remains a free product feature. Export, individual deletion, complete data deletion, applicable account deletion, privacy/legal/support, purchase restoration, and subscription management remain accessible without entitlement. Apply the approved access UX through the shared access-policy boundary.

## Required implementation

- Implement the four approved check-in fields with explicit validation and data-purpose mapping.
- Support skip, partial completion according to the approved contract, explicit submission, editing, individual deletion, destructive confirmation, cancellation, and recovery.
- Never create or submit a check-in without a clear user action.
- Render missing, partial, duplicate, edited, tombstoned, deleted, offline, syncing, conflict, and failed states correctly.
- Implement descriptive history and only approved mathematically honest summaries.
- Avoid streaks, shame, adherence pressure, risk tiers, prediction, diagnosis, causation, prevention, treatment, and “improvement/reduction” claims.
- Handle locale, calendar, wall-clock/instant distinction, time-zone and daylight-saving changes consistently.
- Keep local history useful offline and reconcile through the approved sync/conflict/deletion contract.
- Provide accessible nonvisual text equivalents for every chart or visual summary.
- Keep optional notes out of analytics, diagnostics, notifications, Lock Screen content, logs, and crash payloads.

## Architecture/code rules

- Domain models distinguish absence/unknown/negative/partial values explicitly; do not overload booleans or empty strings.
- Views do not operate on GRDB rows, Supabase DTOs, or analytics payloads.
- Use stable identities, transactions for multi-step edits/deletes, deterministic date/calendar dependencies, structured concurrency, cancellation, and typed errors.
- Keep summary computations pure, documented, localized, testable, and separate from views.
- Do not add unused fields or speculative future metrics.
- Use native semantic controls, adaptive layout, complete localizable strings, and accessible error/confirmation announcements.

## Required tests/evidence

- Parameterized domain/persistence tests cover skip, no entry, negative, partial, explicit submit, duplicate attempt, edit, delete, tombstone, conflict, and relaunch.
- History reconciliation tests cover offline, reconnect, sign-in/out, conversion, multi-device conflict, deletion, and entitlement change.
- Calendar/time-zone/DST/locale tests cover grouping and display without changing record meaning.
- Access tests prove premium gating, alarm unaffected, and export/deletion controls always reachable.
- Copy/math review proves all outputs are descriptive and accurate for empty, sparse, partial, edited, and deleted datasets.
- VoiceOver reading order/labels, all Dynamic Type sizes, Reduce Motion, increased contrast, Voice Control, Switch Control, and textual chart equivalence.
- Privacy/log/analytics inspection proves no note or check-in answer escapes approved storage/sync/export.

## Gate 1F exit

Pass only when records appear solely after explicit submission, all missing/partial/edit/delete states render correctly, history matches persistence through lifecycle/sync transitions, visual summaries have equivalent text, access rules are correct, and content review confirms no predictive or medical interpretation.

## Handoff

Report requirement IDs, outcome, files changed, approved fields/options used, automated/manual/accessibility evidence, data/privacy impact, access behavior, limitations, blockers, whether Gate 1F passed, and the next safe Phase 1G work item. State what remains unverified.
