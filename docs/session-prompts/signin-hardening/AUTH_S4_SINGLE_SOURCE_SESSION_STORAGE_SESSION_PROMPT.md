# Session Prompt: Sign-in Hardening S4 — One Sanctioned Secret Store (SDK-owned Tokens)

You are working in the Sleep Paralysis Companion repository (`C:\Users\satya\Documents\paralux`).
Exclusively **S4: eliminate duplicate persistence of session secrets by making supabase-swift the
runtime owner of access/refresh tokens through a hardened custom keychain storage bridge**.
Operating contract; no memory of other chats. Prerequisites: **S1–S3 merged** (this session touches
nearly every auth file). Read `AGENTS.md` + folder `README.md` standing facts first.

## Problem being fixed (verified current behavior)

supabase-swift persists sessions in its own internal local storage *in addition* to
`KeychainSessionStore`'s app-owned copy of `AuthenticationSessionMaterial` (which includes
`accessToken`/`refreshToken`). Two secret stores must be kept in sync by hand across restore /
sign-out / reauthentication (`OAuthSessionService.swift`) — workable today, fragile forever.

## Required outcome

Exactly **one** sanctioned persistence location for refresh/access tokens: supabase-swift's SDK
storage, backed by a secure iOS keychain implementation under our control. The app-side store keeps
only a non-secret identity record used for offline restore decisions (S1), wrong-account guards,
and deletion flows.

## Implementation requirements

1. **Verify API surface against the pinned dependency first** (`supabase-swift` 2.53.0 tag):
   confirm the storage injection point on `SupabaseClientOptions.auth` (expected protocol like
   `AuthLocalStorage` with retrieve/store/remove methods and the option key likely named
   `storage`). Do not code against guessed names; cite the source lines you verified.
2. Implement a bridge type conforming to that protocol over the existing hardened primitives:
   generic-password items, `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`, service string namespaced
   per bundle id + Supabase project ref (derive from the validated config URL host prefix),
   deterministic item key per SDK convention. Reuse/extend `SystemKeychainClient` rather than
   duplicating SecItem plumbing where practical.
3. Reshape the app-side store: introduce e.g. `AuthenticationIdentityRecord`
   (`userID`, `provider`, coarse `expiresAt`) replacing secret-bearing persistence there.
   In-memory transport types may still carry tokens (signatures stay stable if possible); the
   requirement is that **at rest**, `refreshToken`/`accessToken` exist solely in the SDK-managed
   bridge storage. Prove it with a grep audit added to your report (no secret fields written via
   `KeychainSessionStore` after migration completes).
4. One-time safe migration in `restore()`: if the legacy full-material entry exists → use its
   refresh token to rehydrate via the SDK (S1 flow), write the identity record, then delete legacy
   secrets. Crash-ordering rule: legacy entry must never be deleted before both the SDK-stored
   session and identity record are durable; partial states must always remain recoverable into a
   complete state without user-visible error.
5. Sign-out/reauthenticate/deletion paths updated so all observers agree on the single store
   (`client.auth.signOut()` triggers SDK remove; app store drops identity record). Preserve S1/S2
   classification + logging behavior fully.
6. Tests extending the established seam fakes: bridge round-trip via fake `KeychainClient`;
   migration success/partial-failure scenarios; post-signOut assertions that both stores emptied;
   identity-record-driven wrongAccount guard intact.

## Files you own

All four files under `Sources/Authentication/`, `Sources/Configuration/SupabasePublicConfiguration.swift`
(client options only), `AppCompositionRoot` wiring, related unit tests.
**Do not touch**: Configurations/*.xcconfig, entitlements, Widget, DataRights flows beyond compiling.

## Environment honesty & verification

Windows workstation, no executable toolchain — compile-plausible Swift 6 strict-concurrency code,
extra care since this is concurrency-adjacent actor/state surgery. Cite supabase-swift source
locations you consulted (fetchable from GitHub). Mark "compile-unverified"; propose the exact macOS
commands (`make lint unit ui`) the user should run post-merge.

## Report-back

Verified SDK API citation, final at-rest inventory (what is stored where, every field),
migration state machine diagram (text), test matrix, residual risks.
