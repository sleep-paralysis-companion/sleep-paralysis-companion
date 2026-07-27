# Dependency and SDK Register

## Runtime

There are no third-party runtime SDKs or Swift packages in Phase 1A. The app
links only Apple system frameworks imported by project code: SwiftUI,
Observation, Foundation, and OSLog. It has no Supabase, GRDB, RevenueCat,
StoreKit, AlarmKit, AVFoundation, analytics, advertising, tracking, or crash
reporting dependency.

## Build and CI dependencies

| Dependency | Provenance | Pin | Runtime/privacy impact |
|---|---|---|---|
| Xcode | Apple | 26.4.1 / 17E202 | Build tool only |
| Swift | Apple/Swift project, bundled with Xcode | 6.3; language mode 6 | Compiler/standard library |
| XcodeGen | `github.com/yonaskolb/XcodeGen` | 2.45.4, commit `8d3d3476a69ae3e5d68e1adccc701c410c05eb36` | Build-time project generation only; source-built after commit verification |
| SwiftFormat | `github.com/nicklockwood/SwiftFormat` | 0.61.1 | CI formatting check only |
| SwiftLint | `github.com/realm/SwiftLint` | 0.63.2 | CI static lint only |
| `actions/checkout` | GitHub | major tag `v6` | CI source checkout; read-only token permission |
| `actions/upload-artifact` | GitHub | major tag `v4` | Uploads generated project and test results only |
| GitHub runner image | `github.com/actions/runner-images` | `macos-26`; tool versions verified at runtime | Hosted build/test environment |

## Update review procedure

1. Open a dedicated dependency update.
2. Verify upstream source, release notes, license, immutable commit/checksum, and
   maintainer provenance.
3. Review transitive dependencies, network behavior, collected data,
   required-reason APIs, privacy manifest, permissions, entitlements, binary
   size, and App Store policy impact.
4. Update this register and `scripts/versions.env`.
5. Regenerate from a clean cache and run the full hosted workflow.
6. Do not merge if provenance, privacy declarations, or reproducibility differ
   from the reviewed record.
