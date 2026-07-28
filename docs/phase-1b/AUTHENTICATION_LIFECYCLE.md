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

Provider configuration and production credentials are deliberately absent. Real Apple/Google
console configuration is external integration evidence, not a repository secret.

On sign-out, pending work requires an explicit outcome. A protected former-account copy is visible
only after the same user authenticates; a different account receives no profile. The alternate
choice removes the account profile and all cascaded data from the device.
