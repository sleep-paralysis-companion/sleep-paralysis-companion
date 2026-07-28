# Persona/audio repair requirement-to-evidence checklist

**Status:** Local repair implementation commit `029626fe8df6e0d54a28f96fe5ac8ff8646f1d75`; Gate 1B Persona/Audio Delta is **NOT PASSED** until exact-head Codemagic iOS and isolated-backend jobs pass after an explicitly approved push.

| Requirement | Local repair/evidence |
|---|---|
| Draft identity, one current draft, account isolation, v3-safe migration | Local schema v4 preserves v3, indexes profile/account lookup, and guards draft account/profile linkage; `PersonaAudioFoundationTests` covers distinct IDs/resume and wrong account. |
| Atomic completion/edit/delete and queue work | `LocalDatabase+PersonaAudio` completes or replaces in one local transaction, queues persona upsert/tombstone work, supersedes retryable stale upserts, and keeps unchanged answers idempotent. |
| End-to-end persona sync | Completion creates `SyncEntityType.persona`; `LocalDatabaseOutboundPayloadProvider` derives a trusted-owner `RemoteMutationPayload.persona`; test covers the production provider path. |
| Structured export/redaction | `PersonaExport` is an explicit six-field projection. `exportSnapshot` assembles it only from a complete aggregate; tests cover inclusion and exclusions. |
| Local personal-audio metadata | Existing bounds/format/account/default/cascade constraints are retained; repair adds cross-profile clip-ID protection and a protected-file lifecycle interface without storing a path, name, or bytes. |
| Remote mutation/RLS boundary | New immutable follow-up migration revokes ordinary DML, preserves owner reads, and moves the checked RPC implementation behind a non-exposed private, explicitly granted definer function. |
| pgTAP security/absence coverage | Suite tests real Storage rows/objects/policies, direct-DML denial, existing-row cross-user reads, owner RPC, forged persona, replay mismatch, trusted update, delete/retry, and resurrection denial. |
| Swift migration/fault coverage | Existing v1/v2 migration, corruption, and write-fault tests are updated for v4; a v3-to-v4 no-fabrication test and persona/audio queue/export tests are added. |
| Codemagic/evidence | Persona/audio workflows remain branch-scoped and untouched. Local evidence is recorded separately; hosted verification is intentionally pending consent. |
| Explicitly out of scope | No onboarding UI, microphone/file implementation, importing/playback, WidgetKit, AlarmKit, credentials, live Supabase/Figma, deployment, or remote audio system was added. |

## Remaining acceptance evidence

- Execute iOS tests on macOS/Xcode and isolated migration/pgTAP tests on a functioning Docker/Supabase environment.
- Push only after Satyam Shree explicitly consents, then verify both Codemagic workflows ran on that exact pushed SHA.
- Obtain physical-device evidence before asserting protected-file, recording/import, widget, or locked/background behavior.
