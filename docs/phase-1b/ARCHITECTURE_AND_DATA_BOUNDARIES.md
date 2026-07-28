# Architecture and Data Boundaries

> **Phase 1B delta required - 29 July 2026.** This documents the previously implemented foundation. The approved persona/settings/local-personal-audio-metadata delta in [Persona and Personal Audio Product Realignment](../phase-0/PERSONA_AND_PERSONAL_AUDIO_REALIGNMENT.md) is not implemented or validated by this document; personal audio bytes remain out of every remote boundary.

The Phase 1A inward dependency direction is preserved:

`SwiftUI state -> use-case coordinators -> domain models/protocols -> local or remote adapters`

SwiftUI does not receive GRDB records, Supabase DTOs, tokens, database handles, queue rows, or raw
responses. Domain models, GRDB records, remote DTOs, session material, synchronization operations,
access state, and UI-facing state are distinct types.

`LocalDatabase` is an actor around a GRDB `DatabasePool` and is the immediate authority for
user-visible data. `AuthenticationCoordinator`, `GuestConversionCoordinator`,
`SynchronizationEngine`, `SignOutCoordinator`, and `AccountDeletionCoordinator` are actors.
There is no mutable global database, session, or synchronization state.

Guest profiles have no Supabase user ID. The synchronization engine cannot run without an explicit
authenticated user ID and an explicitly queued operation. Account linkage persists an expected
user ID in a local conversion checkpoint before remote work begins. Finalization verifies the same
profile/user pair in one local transaction.

The only privileged backend operation is Auth-user deletion. It is isolated in an Edge Function;
the iOS target supplies a user access token and never receives a service-role key.
