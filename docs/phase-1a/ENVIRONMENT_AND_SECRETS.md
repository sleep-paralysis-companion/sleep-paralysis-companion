# Environment and Secret-Handling Contract

## Structural isolation

| Environment | Bundle ID | Configuration | Scheme |
|---|---|---|---|
| Development | `com.satyamshree.spc.dev` | `Development` | `SPC-Development` |
| Staging | `com.satyamshree.spc.staging` | `Staging` | `SPC-Staging` |
| Production | `com.satyamshree.spc` | `Production` | `SPC-Production` |

The Phase 0 spike remains separate at
`com.satyamshree.spc.phase0spike`.

No environment has a backend URL or credential in Phase 1A. An absent public
endpoint resolves to a disabled external resource. A nonproduction endpoint
must be HTTPS, explicitly allowlisted for that build, and must not match any
declared production host. Otherwise configuration fails closed with a
constant, user-safe diagnostic. Unit tests cover development and staging
rejection of production hosts and rejection of unallowlisted hosts.

## Public configuration

Public, non-authenticating values may later be supplied through an ignored
`ios/Configurations/Local.xcconfig` or CI build settings:

- `SPC_PUBLIC_API_BASE_URL`
- `SPC_ALLOWED_API_HOSTS`
- `SPC_PRODUCTION_API_HOSTS`

These values enter Info.plist and are therefore public. They must never contain
credentials or secret-bearing URLs.

## Secrets

Tokens, service-role/secret keys, Apple private keys, passwords, client
secrets, webhook secrets, and credentials are not public configuration and
must never enter source, xcconfig, plist, logs, arguments, artifacts, or the
app binary. Later phases must inject necessary secrets into trusted server
infrastructure or CI secret stores; a public iOS client may receive only an
explicitly approved public/publishable key. Logging accepts fixed event codes,
not arbitrary payload strings.

Ignored patterns cover `.env*` (except examples), local xcconfig, secrets,
keys, signing material, generated projects, DerivedData, results, and logs.

The live Supabase project `nfzvlvukbeapcnlmyecf` is not referenced by any iOS
runtime configuration. Phase 1A makes no Supabase/API/database call or change.
