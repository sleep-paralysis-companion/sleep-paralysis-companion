# Session Prompt: Sign-in Hardening S3 — Keychain Constants & Polish Batch

You are working in the Sleep Paralysis Companion repository (`C:\Users\satya\Documents\paralux`).
Exclusively **S3: four small hardening/polish items**. Operating contract; no memory of other
chats. Prerequisite: **S1 and S2 branches merged** (shared files settle). Read `AGENTS.md` and the
folder `README.md` standing facts first.

## Items to deliver

### A. Single-source keychain identity constants
`KeychainSessionStore`'s default parameters (`ios/Sources/Authentication/KeychainSessionStore.swift`
L65–73) use service `"app.sleepcompanion.spc.auth"`, while production wiring passes
`"app.sleepcompanion.spc.authentication"` (`ios/Sources/App/AppCompositionRoot.swift` L10–14).
Today only the mismatch is latent; tomorrow it is two competing session slots. Define one internal
constant source (e.g. `enum SessionKeychainIdentity { static let service/account }`) in
`AuthenticationFoundation.swift`; delete the divergent default literal; have
`AppCompositionRoot` consume the constants. Grep all `KeychainSessionStore(` call sites to prove no
third instantiation exists. Add a tiny unit test asserting store round-trip with those exact values.

### B. Reconcile the unreachable-feeling `wrongAccount` catch in sign-in
`AppModel.signIn` catches `AuthenticationError.wrongAccount` (~L312–317), but on the production
path nothing in `SupabaseOAuthSessionService.signIn` throws it. Investigate
`IntegratedPhase1Store.resume(session:)` (DataInterfaces/Synchronization layers) for the actual
user-vs-protected-profile mismatch signal. Then choose deliberately: either (1) route that real
mismatch through `AuthenticationError.wrongAccount` so the existing UI branch becomes live (add a
unit test proving the mapping), or (2) remove the dead catch + its bespoke message and record why.
Document the decision in code where the choice lives.

### C. Regression guard for the OAuth callback deep link
`AppModel.openDeepLink` (`AppModel.swift` ~L1182–1195) handles `spc://sleep-session` and routed
paths, silently ignoring everything else — normally fine because `ASWebAuthenticationSession`
consumes `spc://auth/callback`, but that behavior deserves a pinned test. Add a focused unit test
(exercise the resolver/model seam as existing NavigationStateTests-style tests do) asserting an
`spc://auth/callback…` URL produces **no** navigation change, no crash, no feedback banner, from
both signed-in and signed-out states. Add a one-line comment at the guard referencing the test.

### D. Accessibility audit of the authentication screen
Audit `FigmaAuthenticationView` / `AuthenticationReferenceLayout` interactive elements (provider
buttons, mode switch link, any disabled state during `.processing`). Add only what is missing:
distinct labels ("Continue with Apple"/"Continue with Google"/mode-switch verb), button traits,
processing-state announcement/trait updates consistent with repo best-practices docs. Zero visual
or layout-coordinate changes; do not regenerate constellation/star decorations.

## Files you own

`KeychainSessionStore.swift`, `AuthenticationFoundation.swift` (constant addition),
`AppCompositionRoot.swift` (call site), small `AppModel.swift` diffs (item B/C),
`FigmaAuthenticationView.swift` (a11y-only edits), new/extended unit tests.
**Do not touch**: `OAuthSessionService.swift` logic bodies, `SupabasePublicConfiguration`,
anything under `Configurations/`.

## Environment honesty & verification

Windows workstation — no Xcode toolchain. Compile-plausible Swift 6, warnings-as-errors mindset;
run textual checks you can (e.g. prove zero remaining `"app.sleepcompanion.spc.auth"` literals,
prove callback URL strings appear in exactly the expected places); report "compile-unverified"
honestly. Never claim executed builds/tests.

## Report-back

Item-by-item summary: decision made for B (with evidence from the store-layer reading), constant
adoption diff points, new test names + asserted behaviors, a11y additions list (before→after),
open questions.
