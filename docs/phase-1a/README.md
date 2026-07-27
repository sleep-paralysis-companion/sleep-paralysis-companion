# Phase 1A Evidence Index

**Status:** Gate 1A PASS — hosted macOS verification complete

**Owner authorization:** Satyam Shree, 28 July 2026

**Scope:** Repository and platform foundation only

The owner authorized this foundation implementation as a narrow exception
while Gate 0 remains `NOT PASSED`. The exception does not authorize Phase 1B,
feature screens, backend work, live Supabase changes, commerce configuration,
signing, TestFlight, Figma mutation, or unsupported claims.

## Evidence records

- [Architecture and dependency boundaries](./ARCHITECTURE.md)
- [Build, test, and onboarding commands](./BUILD_AND_TEST.md)
- [Environment and secret contract](./ENVIRONMENT_AND_SECRETS.md)
- [Dependency and SDK register](./DEPENDENCIES.md)
- [Privacy manifest and required-reason review](./PRIVACY_REVIEW.md)
- [Hosted CI evidence](./CI_EVIDENCE.md)
- [Gate 1A review](./GATE_1A_REVIEW.md)

## Requirement mapping

| Requirement | Implementation/evidence |
|---|---|
| `P1A-PROJ` native project and targets | `ios/project.yml`, three schemes/configurations, unit/UI targets |
| `P1A-ARCH` inward boundaries | `ios/Sources/`, `ARCHITECTURE.md` |
| `P1A-SHELL` accessible shell | Shell sources and UI tests |
| `P1A-ENV` environment isolation | Configuration sources, xcconfig files, unit tests |
| `P1A-CONC` Swift 6 concurrency | Project settings, `AppModel`, hosted compile |
| `P1A-DS` semantic design foundation | `DesignTokens.swift`, unit/UI tests |
| `P1A-LOG` privacy-safe logging | Logging boundary and redaction tests |
| `P1A-PRIV` privacy/dependency review | `PrivacyInfo.xcprivacy`, registers, validation script |
| `P1A-ACCESS` centralized access seam | `AccessPolicy.swift` and invariant tests |
| `P1A-CI` reproducible hosted proof | Scripts, workflow, `CI_EVIDENCE.md` |

The passing candidate is
`0a3046e3a1e12e6024fe244466d374cfcb12e772`, verified by
[GitHub Actions run 30313980331](https://github.com/sleep-paralysis-companion/sleep-paralysis-companion/actions/runs/30313980331).
