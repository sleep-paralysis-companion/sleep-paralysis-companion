# Phase 1B Evidence Index

> **Phase 1B delta required - 29 July 2026.** This index and its CSV inventory describe the prior foundation. The approved persona/settings/local-personal-audio-metadata delta is [Persona and Personal Audio Product Realignment](../phase-0/PERSONA_AND_PERSONAL_AUDIO_REALIGNMENT.md); it is not implemented or validated here, and personal audio bytes remain local-only.

Phase 1B is the repository, simulator, and isolated-backend foundation authorized by Satyam Shree
on 2026-07-28. Gate 0 remains **NOT PASSED**. No live Supabase project or website change is part
of this phase.

- [Architecture and data boundaries](ARCHITECTURE_AND_DATA_BOUNDARIES.md)
- [Local schema and migrations](LOCAL_SCHEMA_AND_MIGRATIONS.md)
- [Remote schema and RLS](REMOTE_SCHEMA_AND_RLS.md)
- [Authentication lifecycle](AUTHENTICATION_LIFECYCLE.md)
- [Synchronization and conflict rules](SYNCHRONIZATION_AND_CONFLICTS.md)
- [Retention, deletion, and export](RETENTION_DELETION_EXPORT.md)
- [Privacy and security review](PRIVACY_AND_SECURITY_REVIEW.md)
- [Dependencies and SDK provenance](DEPENDENCIES_AND_SDK_PROVENANCE.md)
- [Field-level data inventory](DATA_INVENTORY.csv)
- [CI evidence](CI_EVIDENCE.md)
- [Gate review](GATE_1B_REVIEW.md)

Controlling implementation:

- Local database: `ios/Sources/LocalPersistence`
- Auth and Keychain: `ios/Sources/Authentication`
- Sync and conversion: `ios/Sources/Synchronization`
- Data rights: `ios/Sources/DataRights`
- Remote DTOs/adapters: `ios/Sources/RemoteData`
- Isolated backend: `supabase`
- Hosted verification: `.github/workflows/phase-1b-foundation.yml`
