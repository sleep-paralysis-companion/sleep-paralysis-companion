# Build, Test, and Onboarding

## Pinned host

- GitHub runner: `macos-26`
- Xcode: `26.6` (`17F113`)
- Swift: `6.3.3`, project language mode `6`
- iOS Simulator SDK: `26.5`
- Destination: `iPhone 17`, iOS `26.5`, `arm64`
- Deployment target: centralized at iOS `26.0`

The App Store upload floor has required Xcode 26 and the iOS 26 SDK or later
since 28 April 2026. Apple released stable Xcode 26.6 build 17F113 on
25 June 2026; prerelease Xcode 27 is not used.

## Clean-checkout commands

Run from repository root on the pinned macOS/Xcode host:

```bash
bash scripts/select_xcode.sh
bash scripts/bootstrap.sh
bash scripts/format_check.sh
bash scripts/lint_check.sh
bash scripts/static_check.sh
bash scripts/privacy_manifest_check.sh
bash scripts/secret_scan.sh
bash scripts/prepare_simulator.sh
bash scripts/build.sh
bash scripts/unit_tests.sh
bash scripts/ui_tests.sh
```

`bash scripts/verify_ci.sh` (or `make verify`) runs the complete sequence and
stops on the first error. Checks never silently skip a missing tool.

`prepare_simulator.sh` validates the pinned iOS 26.5 runtime and iPhone 17
device type, creates and boots a dedicated simulator when needed, and records
its generated UDID under the ignored `ios/.generated/` directory. Build and
test commands address that exact device instead of depending on a runner's
pre-created simulator inventory.

`bootstrap.sh` obtains the official XcodeGen 2.45.4 release archive, verifies
SHA-256 `090ec29491aad50aec10631bf6e62253fed733c50f3aab0f5ffc86bc170bdbef`,
generates the project, and asks `xcodebuild` to enumerate targets and schemes.
The release maps to upstream commit
`8d3d3476a69ae3e5d68e1adccc701c410c05eb36`. Bootstrap also downloads
SwiftLint 0.65.0 from its official release and verifies SHA-256
`d6cb0aa7a2f5f1ef306fc9e37bcb54dc9a26facc8f7784ac0c3dd3eccf5c6ba6`
before the linter can run.

## Later Apple-team signing

Simulator CI intentionally sets `CODE_SIGNING_ALLOWED=NO`. When release signing
is authorized, add a local/CI-only xcconfig with `DEVELOPMENT_TEAM` and signing
inputs, select automatic or managed signing in the release pipeline, and leave
source modules, bundle IDs, configurations, and schemes unchanged. Never
commit certificates, provisioning profiles, `.p8`, private keys, or passwords.
