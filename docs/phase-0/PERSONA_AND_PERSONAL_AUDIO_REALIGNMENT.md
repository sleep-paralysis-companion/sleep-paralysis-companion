# Persona and Personal Audio Product Realignment

**Status:** Approved product-change contract - 29 July 2026
**Scope:** Phase 1 documentation realignment only; no implementation, migration, permission, or Figma change is authorized by this document.

This contract supersedes the conflicting guest-only onboarding, questionnaire exclusion, personal-audio exclusion, microphone prohibition, and legacy-Figma dispositions in the prior Phase 0 and Phase 1C documents. Historical evidence remains historical evidence; it does not demonstrate this revised product.

## 1. Fixed product boundary

- The journey is **Splash -> feature introduction -> Apple/Google authentication -> Q1-Q3 -> derived internal persona -> personalized recommended setup -> record/import comfort audio -> sleep schedule -> Home**.
- Authentication uses **Sign in with Apple** and **Sign in with Google** only. Email/password, passwordless email, phone, OTP, a required full name, and a guest-only onboarding route are out of contract.
- There are four internal routing outcomes. Their identifiers and labels are never presented to the user as a profile, diagnosis, score, or result. The user sees only a neutral personalized recommended-setup screen.
- The product remains a private, nonmedical wellness companion. The answers and persona must not power diagnosis, treatment, prevention, prediction, risk scoring, detection, emergency response, clinical interpretation, or a guaranteed outcome.
- Seven-day-trial concepts are removed from this stage. This change does not authorize a replacement offer, pricing, or a paywall change.

## 2. Exact onboarding answers and derived persona

The persisted enum values are stable contract values; the displayed strings below are the exact approved question/options for this stage.

| Field | Enum values | Displayed question/options |
|---|---|---|
| `episode_frequency` | `rarely`, `monthly`, `weekly`, `almost_nightly` | **How often do you experience Sleep Paralysis?** `Rarely - a few times a year`; `Monthly - a few times a month`; `Weekly`; `Almost Nightly` |
| `post_episode_feeling` | `shake_it_off`, `awake_scared`, `too_frightened_to_close_eyes` | **How do you feel after the episode?** `I shake it off and go back to sleep`; `I lie awake scared for a while`; `I'm too frightened to close my eyes again` |
| `calming_person_context` | `beside_me`, `not_always_present`, `alone` | **Do you have someone whose voice calms you down?** `Yes - They sleep beside me`; `Yes - But they are not always with me`; `No - I go through this alone` |

`derived_persona` is computed, never hand-entered, and never independently editable:

| Internal enum | Predicate | User-visible treatment |
|---|---|---|
| `frequent_intense_person_not_always_present` | Q1 is `weekly` or `almost_nightly`, **and** Q2 is `awake_scared` or `too_frightened_to_close_eyes`, **and** Q3 is `not_always_present` | Neutral personalized recommended setup; prioritize the approved comfort-audio setup route. |
| `frequent_intense_person_beside_user` | Same Q1/Q2 predicate; Q3 is `beside_me` | Neutral personalized recommended setup; prioritize the approved comfort-audio setup route. |
| `frequent_intense_no_calming_person` | Same Q1/Q2 predicate; Q3 is `alone` | Neutral personalized recommended setup; prioritize the approved comfort-audio setup route. |
| `general_default` | Every other **completed** Q1-Q3 combination | Neutral general recommended setup. |

The routing rule is versioned (`persona_routing_rule_version`) and recalculated atomically whenever a complete answer set is saved from Settings. A recalculation overwrites only the derived persona and calculation metadata; it neither creates an episode record nor changes the historical answers without the person's explicit edit.

### Incomplete or skipped answers - open decision

No behavior is approved for a skipped, partially answered, dismissed, restored-incomplete, or otherwise invalid questionnaire. In particular, implementation must not assign `general_default`, infer an answer, persist a partial persona, show a personalized setup, or mark onboarding complete. Product/orchestrator confirmation is required for the exact UX, persistence, authentication-session, back-navigation, and resume behavior before implementation.

## 3. Persona-answer data handling

The answers, derived persona, routing-rule version, and calculation instant are sensitive wellness-profile data. They have a limited purpose: determine and later update the recommended setup. They are not analytics, diagnostics, notifications, crash reports, widgets, lock-screen text, marketing, or model input.

- Store them in protected local persistence under the authenticated local profile. A Phase 1B delta must define the corresponding remote, account-owned sync representation, RLS policy, operation compatibility, conflict behavior, export, and deletion tests before any sync implementation.
- Retain the current answers and derived persona until the person edits them, deletes them, deletes all local data, or deletes the account where synchronized. Do not retain prior answer history merely to compare persona changes.
- A structured data export includes the current enum answers, derived persona, routing-rule version, and export scope/time. It excludes tokens, diagnostics, internal queue state, and audio bytes.
- Settings exposes an edit/update route and a clear action to delete the answers/persona. Deleting them removes the derived persona in the same transaction and returns the product to the unresolved setup state; it must not silently reclassify the person.

## 4. Personal comfort audio - local-only boundary

Phase 1 includes explicit recording, importing existing audio files, storing multiple personal clips locally, selecting one personal clip or Sleep Paralysis Companion-provided audio as the default recovery audio, individual clip deletion, complete local-data deletion, and user-initiated individual audio export.

Personal recordings and imported audio are device-local only:

- Never upload, synchronize, back up through an app-controlled server, transcribe, analyze, or place audio bytes in Supabase Storage or any other server.
- Never include audio bytes, original filenames, filesystem paths, transcripts, waveform data, or derived voice data in analytics, diagnostics, notifications, crash logs, widgets, or lock-screen content.
- Keep only privacy-safe local metadata: opaque clip ID, source (`recorded` or `imported`), storage format, byte count, duration when available, creation/import time, integrity/availability state, and local protection version. Do not persist an imported original filename or path.
- Protect audio files and their local metadata with iOS file protection. The intended class is `completeUntilFirstUserAuthentication`, consistent with protected local app data; playback behavior while locked must be established by physical-device evidence before it is claimed.
- A personal clip default is device-local. Sync must never create a remote personal-audio reference or a cross-device expectation that its bytes exist. A Sleep Paralysis Companion-provided asset default may follow its separately approved catalog/cache contract.

### Recording, import, selection, export, and deletion

| Operation | Required behavior |
|---|---|
| Record | Begin only after the person taps a visible Record control, sees a recording state, and grants microphone access just in time. The UI always exposes Stop and Cancel. No ambient, background, overnight, continuous, or hidden recording is permitted. |
| Import | User explicitly invokes the system-supported audio import/document route. Validate supported type, readability, size policy, and local copy integrity before it becomes available. Import failure leaves no partial clip. |
| Select default | The person explicitly selects one ready personal clip or one ready Sleep Paralysis Companion-provided item. Selection does not start playback and does not imply an episode occurred. |
| Missing/corrupt selected personal clip | Do not choose a different personal clip silently. Explain that the selected item is unavailable and use a ready Sleep Paralysis Companion-provided recovery item when available; otherwise provide the documented silent visual fallback. |
| Playback unavailable/offline | Personal clips and bundled Sleep Paralysis Companion items remain usable without network once locally present. An unavailable, decoder-failed, interrupted, or corrupt item falls back to a ready approved Sleep Paralysis Companion item, then silent visual grounding. Do not promise locked/background playback until physical validation. |
| Export | The person explicitly exports one selected personal clip through a user-selected iOS share/document destination. Create a protected temporary copy only for that operation and clean it up after completion/cancel or bounded recovery. Audio bytes are never added automatically to a structured data export. |
| Delete one clip | Confirm the exact local-only effect, stop any active use safely, remove the bytes, metadata, temporary copies, and device-local default reference atomically/recoverably. It never deletes another clip or server data. |
| Delete all local data | Remove every personal recording/import, audio metadata, local selection/default, temporary export/import files, and protected local cache alongside the rest of the documented local-data deletion. Remote account data and Apple subscriptions remain distinct. |

## 5. Microphone boundary

Microphone access is allowed only for the explicit user-initiated recording feature described above. It is not requested on splash, feature introduction, authentication, questionnaire, recommended setup, schedule setup, ordinary launch, import, playback, manual episode action, or background execution.

If access is denied, restricted, revoked, or unavailable, recording stays unavailable with an honest recovery explanation and a route to iOS Settings where appropriate. The person can still import audio, choose Sleep Paralysis Companion-provided audio, use silent visual grounding, continue setup, and reach Home. The app must not repeatedly prompt, block onboarding, or activate an input session after denial.

## 6. Manual episode action and system surfaces

The episode entry remains manual: the person explicitly taps the intended Home Screen WidgetKit quick action or an in-app action. The app never infers an episode. The selected personal or Sleep Paralysis Companion-provided recovery audio then begins only through the documented iOS-supported path.

The Home Screen widget is the intended primary external surface. Lock Screen and Control Center availability, unlock requirements, app-terminated/background behavior, and recovery-audio playback are unverified until physical-device feasibility tests pass. No implementation or copy may claim "no unlock required," locked/background playback, or Control Center support beforehand.

## 7. Phase sequencing and validation gates

- **Phase 1B delta:** before code relies on this contract, define and test a scoped schema/model delta for persona answers, derived persona, routing version, Settings update/deletion, and local personal-audio metadata. It must preserve account ownership, RLS, operation/entity/payload compatibility, tombstone conventions, export/deletion semantics, and the prohibition on server-side audio bytes.
- **Phase 1C replacement:** replace the obsolete guest-only welcome -> notice -> Home implementation and its contract checks/tests with the authenticated journey in section 1. Preserve compatible design system, shell, typed navigation, restoration, local persistence discipline, accessibility foundations, and test harnesses.
- **Physical feasibility:** recording/import, file protection/playback, Home Screen widget, recovery audio, and all lock/background/control claims require physical-device evidence before they are represented as supported.
- **Historical evidence:** current Phase 1C implementation/evidence documents are superseded for product acceptance by this approved change. They remain retained as evidence for the prior guest-only scope only.

## 8. Implementation-impact inventory

### Reusable current Phase 1C work

- Design tokens, SwiftUI shell, accessibility helpers, privacy-safe logging, typed navigation/restoration structure, local-store actor/transaction pattern, route validation, and the unit/UI test support are candidates for reuse after review.
- The existing protected GRDB foundation, account/auth boundaries, deletion/export foundation, and synchronization/RLS test harness are candidates for Phase 1B-delta extension, not proof that the new fields are implemented.

### Replace or redesign

- `ios/Sources/Features/Onboarding/WelcomeView.swift`, `ProductNoticeView.swift`, `ios/Sources/App/AppModel.swift`, `ios/Sources/Domain/OnboardingModels.swift`, and `ios/Sources/LocalPersistence/LocalOnboardingProfileStore.swift` implement the obsolete guest-only five-field onboarding model and require replacement or material redesign.
- `ios/Sources/Domain/AppRoute.swift`, `ios/Sources/LocalPersistence/LocalDatabase+Onboarding.swift`, `ios/Tests/Unit/OnboardingPersistenceTests.swift`, `ios/Tests/Unit/NavigationStateTests.swift`, `ios/Tests/UI/ApplicationLaunchUITests.swift`, `scripts/phase_1c_contract_check.sh`, and the Phase 1C evidence/CI assertions require contract-aligned updates in a later implementation stage.
- Required model/migration work includes protected local answer/persona rows, local personal-audio metadata and file lifecycle, device-local personal-default representation, authenticated onboarding/state restoration, and a scoped remote persona/settings representation with RLS/sync compatibility. There is no remote audio-object migration because server-side personal audio is forbidden.

### Required tests before acceptance

- Exact enum/copy and four-route matrix tests; all nonmatching **complete** combinations route to general/default; Settings edits atomically recalculate; persona/answers export/delete correctly; and incomplete/skip handling follows the later approved decision.
- Apple/Google-only authentication, cancellation, denial, linking/collision, expired/revoked session, account isolation, and no-email/phone/OTP/full-name checks.
- Recording just-in-time permission, denial/revocation/recovery, visible start/stop/cancel, import validation/rollback, multiple clips, local metadata redaction, no server/audio/filename/path/transcript/waveform leakage, selection, missing/corrupt/interrupted fallback, individual export cleanup, individual deletion, and complete local-data deletion.
- Widget/manual-action idempotency; offline/terminated/locked/background/unsupported-surface matrices; no automatic episode record or detection; and physical-device evidence for every locked/background/Control Center claim.
- Local/remote RLS, operation/payload negative cases, account deletion, export, tombstone, and migration-upgrade tests for the Phase 1B delta.

## 9. Remaining decisions requiring product/orchestrator confirmation

1. The exact behavior for skipped, incomplete, dismissed, interrupted, or restored-partial Q1-Q3 answers.
2. The approved recommended-setup content/copy and whether the three frequent/intense variants may differ beyond audio-setup priority, subject to the nonmedical claims boundary.
3. Recording/import type, size, duration, normalization, and backup policy limits.
4. The minimum iOS version and the physically demonstrated WidgetKit, Lock Screen, Control Center, terminated/background, and audio-playback behavior.
5. The exact permission-purpose copy and final privacy-policy/App Store disclosure wording after implementation details are approved.
