# Session Prompt: Sign-in Hardening S1 — Offline-Tolerant Session Restore

You are working in the Sleep Paralysis Companion repository (`C:\Users\satya\Documents\paralux`).
This session is exclusively for **S1: offline-tolerant session restore**. Treat this prompt as the
session's operating contract. Assume no memory of any other chat. Start by reading `AGENTS.md`,
`docs/session-prompts/signin-hardening/README.md` (Standing repo facts), and skimming
`docs/IOS_2026_BEST_PRACTICES.md`.

## Problem being fixed (verified current behavior)

`SupabaseOAuthSessionService.restore()` (`ios/Sources/Authentication/OAuthSessionService.swift`
L85–96) calls `client.auth.refreshSession(refreshToken:)` unconditionally on every cold launch and
its catch-all does `try? sessionStore.delete(); throw AuthenticationError.expired`. Consequences:
transient network failure at launch (airplane mode, captive portal) permanently deletes a perfectly
valid keychain session and forces re-authentication; `.expired` is also a lie for network-class
failures. `AppModel.activate()` maps `.expired` to the auth screen with "Your session ended."
(`ios/Sources/App/AppModel.swift` L158–200). An unused expiry-skip precedent exists at
`AuthenticationFoundation.swift` L218–229 (`refresh(now:)`: skip until within 60 s of expiry).

## Required outcome

1. Cold launch with a comfortably-valid stored token restores without contacting the network.
2. When a refresh is needed, network-class failures preserve the stored session and surface a
   distinguishable, calm app state instead of destroying the session.
3. Only definitive server rejection of the refresh token (invalid/revoked grant class) purges the
   keychain entry and behaves like today's expiry path.

## Implementation requirements

1. Introduce a narrow test seam: a protocol (e.g. `SupabaseAuthRefreshing`) wrapping only the
   supabase-swift operations this actor uses (`refreshSession(_:refreshToken:)` today), injected
   into `SupabaseOAuthSessionService`. Production conformance wraps `client.auth`. Keep
   `OAuthSessionServicing`'s external signature stable unless returning richer restore outcomes is
   unavoidable; if it changes, update all three conformers (`Supabase…`, `Unavailable…`,
   DEBUG `UITestOAuthSessionService`) coherently.
2. Skip the network entirely when stored `expiresAt > now + 60 s`; return the stored material.
3. Classify refresh failures by consulting the pinned dependency's real error surface
   (`supabase-swift` 2.53.0 in Package.resolved / its GitHub tag): wrap `URLError` /
   transport-domain NSErrors as a network class; SDK `AuthError`/HTTP 401·403·invalid-grant shapes
   as definitive rejection; anything unrecognized defaults to *preserving* the session (fail-safe
   direction), reported as a separate "unclassified" outcome for visibility.
4. `AppModel.activate()` must handle the new outcome(s): preserved-offline proceeds into
   `resume(session:)` (verify first that `IntegratedPhase1Store.resume` makes no blocking network
   call on the critical path — synchronization is decoupled; if you find otherwise, adjust the
   design and report). Definitive-expiry keeps today's routing/copy. Extend `AuthenticationError`
   or define an internal result enum — your call, but stay consistent with existing equatable,
   Sendable style and add cases rather than overloading `.expired`.
5. Unit tests in a new `ios/Tests/Unit/OAuthSessionServiceRestoreTests.swift` (or appended to
   `AuthenticationFoundationTests.swift` if smaller): (a) fresh token → no SDK call, keychain
   untouched; (b) stale token + URLError-based network failure → keychain preserved, recoverable
   outcome; (c) stale token + invalid-grant-shaped failure → keychain purged, `.expired`;
   (d) successful refresh → updated material written back. Follow existing fixture idioms
   (`ScriptedAuthenticationGateway`, `Phase1BFixture.session()`).
6. Classification rationale as a concise comment table above the classifier function.

## Files you own

`Sources/Authentication/OAuthSessionService.swift` (Supabase actor + new seam types),
new/extended unit test files listed above, minimal `AppModel.activate()` diff.
**Do not touch**: `signIn`/`reauthenticateForDeletion` bodies beyond compiling, S2's future
territory (logging), `KeychainSessionStore` internals, `SupabasePublicConfiguration`,
`FigmaAuthenticationView`, anything under `Configurations/`.

## Environment honesty & verification

Windows workstation — `xcodebuild`, `swift build`, and the Make targets are unavailable here.
Author Swift/XCTest to compile-plausible precision (Swift 6 strict concurrency, default MainActor
isolation, warnings-as-errors: no force unwraps, no retain cycles, no new lint violations) and
state clearly in your report that compilation/testing was **not executed locally**. You may run
textual checks (Select-String/grep asserts) and cite their output. Never claim an executed build,
simulator run, or passing suite that did not happen.

## Report-back

Summarize: outcome enum/type design, error→class mapping table, exact diff points in `activate()`,
test list with intended assertions, open questions (e.g. store-resume network discovery), and any
places you had to assume SDK error shapes without running the library.
