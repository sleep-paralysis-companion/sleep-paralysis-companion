# Authentication Lifecycle

Accepted providers are exactly `apple` and `google`. Email/password, magic links, OTP, phone/SMS,
anonymous Auth, username/password, and other identity providers are rejected by the domain policy.

The native-provider adapter exchanges an Apple or Google ID token with Supabase Auth. OAuth
challenge creation uses independent cryptographic state, nonce, and PKCE verifier/challenge values.
Callback completion checks provider, state, and raw nonce before exchange. Cancellation is checked
before and after external work.

Session access and refresh tokens exist only in `AuthenticationSessionMaterial` and are persisted
through `KeychainSessionStore`, using `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`. Tokens are not
GRDB fields, preferences, files, fixtures containing real credentials, or logs. Keychain write
failure signs the remote session out and returns an error. Refresh, expiry, revocation, sign-out,
provider collision, wrong-account rejection, and reauthentication are deterministic test paths.

Supabase session revocation and provider-grant revocation are distinct operations. A Supabase JWT
is never passed to Apple or Google as a revocation token. Provider revocation accepts only an
ephemeral Apple authorization code or Google OAuth access token matching the signed-in provider;
that credential is non-Codable and cannot cross the GRDB, export, resource, or logging boundaries.
Provider-revocation failure is reported separately after the Supabase session and Keychain session
have been cleared, so guest/local use remains available. A provider mismatch fails before either
revocation.

Sensitive account deletion requires a fresh native-provider exchange for the same provider and
same Supabase user. The resulting `RecentReauthentication` contains only user ID, provider, and
authentication time. A collision or wrong account signs out the newly exchanged remote session,
preserves the existing Keychain session, and cannot mint deletion authority.

Provider configuration and production credentials are deliberately absent. Real Apple/Google
console configuration, Apple token exchange/revocation secrets, Google grant behavior, and
production callback proof are external integration evidence and remain unverified; they are not
claimed by this repository work.

On sign-out, pending work requires an explicit outcome. A protected former-account copy is visible
only after the same user authenticates; a different account receives no profile. The alternate
choice removes the account profile and all cascaded data from the device.
