# Session Prompt: Sign-in Hardening S2 — Failure Taxonomy & Privacy-Safe Auth Logging

You are working in the Sleep Paralysis Companion repository (`C:\Users\satya\Documents\paralux`).
Exclusively **S2: differentiated sign-in failure taxonomy + privacy-safe logging**. Operating
contract; no memory of other chats. Prerequisite: **branch containing S1 is merged** — this session
extends `SupabaseOAuthSessionService` it reshaped. Read `AGENTS.md` and
`docs/session-prompts/signin-hardening/README.md` (standing facts) first.

## Problem being fixed (verified current behavior)

`SupabaseOAuthSessionService.signIn(provider:)`
(`ios/Sources/Authentication/OAuthSessionService.swift`) funnels everything except cancellation
into `throw AuthenticationError.externalProviderUnavailable`; `AppModel.signIn` renders one
generic message — *"Sign-in did not finish. Check the provider configuration and try again."*
(`AppModel.swift` ~L312–321) — which misleads users on ordinary offline failures and gives support
nothing. The privacy-safe logger (`ApplePrivacySafeLogger`, subsystem `app.sleepcompanion.spc`)
exists (see `AppCompositionRoot.swift` usage, event `.configurationUnavailable`) but the auth layer
logs nothing, so TestFlight diagnosis relies on guesses.

## Required outcome

Distinguishable, user-honest outcomes and categorized, PII-free log records for:
user-cancelled web session · device/network unavailable · provider web sheet could not start ·
server/provider rejected · unexpected/unclassified — without weakening cancellation's quietness or
exposing any token, email, or identifier in logs.

## Implementation requirements

1. Introduce the taxonomy additively on `AuthenticationError` (new cases such as
   `.networkUnavailable`, keeping the S1 era clean) or a paired classification value carried
   alongside — your design choice, justified in the report. Map inside the service's catch chain:
   `ASWebAuthenticationSessionError.canceledLogin` and `CancellationError` → `.cancelled`
   (unchanged); `URLError`-family / transport failures (including those surfaced through S1's
   refresh seam) → `.networkUnavailable`; remaining network-less failures →
   `.externalProviderUnavailable` today's meaning narrowed to "provider/web-sheet problem";
   recognizable HTTP rejection shapes → a server-rejected case.
2. Update `AppModel.signIn` (and `visibleMessage` copy in `FigmaAuthenticationView` only if the
   state strings demand it) so each category shows accurate, calm copy consistent with existing
   voice: offline ≠ "configuration", configuration problems keep their explicit message.
   `accountAccessState`/presentation-state transitions must remain exhaustive (`Domain/AppRoute.swift`
   enums are equatable/exhaustive-switch; widen them coherently).
3. Wire logging: thread the existing configured `ApplePrivacySafeLogger` from
   `AppCompositionRoot.makeModel()` into `SupabaseOAuthSessionService` (constructor param;
   `Unavailable`/`UITest` conformers get a no-op-consistent treatment). Record events per attempt:
   `sign_in_started`, classified terminal events, `restore_purged_on_rejection` (S1 hook),
   `sign_out_completed`. Define the event/category enum alongside the logger's existing patterns.
   Hard rules: never log tokens, nonce/state values, emails, raw URLs with query items, or
   provider account details; content limited to event + coarse class.
4. Unit tests extending S1's seam fakes: representative thrown inputs (scripted
   `ASWebAuthenticationSessionError.canceledLogin`, scripted `URLError(.notConnectedToInternet)`
   wrapped through the seam, synthetic HTTP rejection shape) assert (a) resulting taxonomy case and
   (b) via a spy logger, exactly the allowed fields were logged. Also assert
   `.cancelled` produces **no** log-noise.
5. Keep `UnavailableOAuthSessionService` and `UITestOAuthSessionService` compiling with sensible
   no-op/minimal behavior; UI-test flows must not regress.

## Files you own

`Sources/Authentication/OAuthSessionService.swift` (catch chains, constructor), taxonomy edits in
`Sources/Authentication/AuthenticationFoundation.swift` (additive only),
`Sources/App/AppModel.swift` (sign-in catch/message blocks; reuse the logger instance),
optional copy tweak in `FigmaAuthenticationView.swift`, related unit tests,
`Sources/Core`/logger file only to add event constants.
**Do not touch**: `restore()` decision logic introduced by S1 (only append logging hooks),
`SupabasePublicConfiguration`, keychain store internals, Configurations, entitlements.

## Environment honesty & verification

Same standing rule as all sessions in this folder: Windows workstation, no executable iOS toolchain.
Author compile-plausible Swift 6 strict-concurrency code, add a small textual self-check where
useful (e.g. Select-String proving no `print(`/token-field appears in new log call sites), and
explicitly flag "compile-unverified". Never fabricate test-run results.

## Report-back

Provide the final mapping table error-origin → `AuthenticationError` case → user-facing copy → log
event/category; the exhaustive-switch checklist you satisfied; test inventory; open risks
(e.g. SDK error shapes assumed from source reading, listed explicitly).
