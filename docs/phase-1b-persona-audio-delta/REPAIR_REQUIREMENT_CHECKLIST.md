# Persona/audio repair requirement-to-evidence checklist

**Implementation repair commit:** `029626fedf5381ef687d5c3d9a8d407d11b0a009` (verified with `git rev-parse`).

**Evidence correction commit:** Recorded only after Git creates the local correction commit; it must not be manually reconstructed.

**Final local HEAD for hosted verification:** Recorded only after the correction commit. Gate 1B Persona/Audio Delta is **NOT PASSED** until exact-head Codemagic iOS and isolated-backend jobs pass after an explicitly approved push.

| Requirement | Local repair/evidence |
|---|---|
| Draft identity, one current draft, account isolation, v3-safe migration | **Implemented; statically inspected.** Local schema v4 preserves v3, indexes profile/account lookup, and guards draft account/profile linkage. Runtime test not run. |
| Atomic completion/edit/delete and queue work | **Implemented; statically inspected.** Completion/replacement use the existing operation/tombstone queue. The available injected write fault occurs before the transaction begins; mid-transaction rollback is **not yet proven**. |
| End-to-end persona sync | **Implemented; source test added.** Completion creates `SyncEntityType.persona`; the production provider derives a trusted-owner `RemoteMutationPayload.persona`. Runtime test not run. |
| Structured export/redaction | **Implemented; source test added.** `PersonaExport` has explicit snake-case keys and a six-field projection. Runtime export test not run. |
| Local personal-audio metadata | **Implemented; source tests added.** Bounds/formats/default/cascade and cross-profile clip-ID rejection are asserted in test source. Runtime test not run. |
| Remote mutation/RLS boundary | **Implemented; statically inspected.** Follow-up migration revokes ordinary DML, preserves owner reads, and uses a narrowly granted private definer implementation. pgTAP runtime not run. |
| pgTAP security/absence coverage | **Test source expanded; runtime not run.** The 54-assertion suite includes Storage absence, DML/RLS, malformed payload, replay, privilege, legacy, and account-cascade assertions. |
| Swift migration/fault coverage | **Test source expanded; runtime not run.** v1/v2/v3 migration, corruption, pre-transaction write-fault preservation, persona/audio, and export tests are present. |
| Codemagic/evidence | **Hosted not tested.** Workflows remain branch-scoped and untouched; hosted verification awaits explicit push consent. |
| Explicitly out of scope | No onboarding UI, microphone/file implementation, importing/playback, WidgetKit, AlarmKit, credentials, live Supabase/Figma, deployment, or remote audio system was added. |

## Remaining acceptance evidence

- Execute iOS tests on macOS/Xcode and isolated migration/pgTAP tests on a functioning Docker/Supabase environment.
- Push only after Satyam Shree explicitly consents, then verify both Codemagic workflows ran on that exact pushed SHA.
- Obtain physical-device evidence before asserting protected-file, recording/import, widget, or locked/background behavior.
