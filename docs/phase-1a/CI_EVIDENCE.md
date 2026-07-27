# Hosted CI Evidence

**Status:** PASS

**Verification date:** 28 July 2026 (27 July 2026 UTC)

| Field | Evidence |
|---|---|
| Branch | `codex/phase-1a-foundation` |
| Candidate commit | `bd239116df78f4616006cd38fd46ea5a3970107e` |
| Workflow | `.github/workflows/phase-1a-ios.yml` |
| Run | [30312994016, attempt 1](https://github.com/sleep-paralysis-companion/sleep-paralysis-companion/actions/runs/30312994016) — `success` |
| Job | [90132487700](https://github.com/sleep-paralysis-companion/sleep-paralysis-companion/actions/runs/30312994016/job/90132487700) — `success` |
| Runner | `macos-26-arm64`; macOS 26.4 (`25E246`) |
| Xcode/Swift/SDK | Xcode 26.6 (`17F113`); Swift 6.3.3 in Swift 6 language mode; iOS Simulator SDK 26.5 |
| Destination | iPhone 17, iOS 26.5, `arm64`; deployment target iOS 26.0 |
| Build | Unsigned Development simulator app; `BUILD SUCCEEDED`; warnings treated as errors |
| Unit tests | 19 executed, 0 failures |
| UI tests | 2 executed, 0 failures |
| Format/lint/static | 0/20 formatting changes; 0 SwiftLint violations; static boundary checks passed |
| Privacy/security | Manifest syntax/content, target membership, built-app presence, required-reason source review, worktree/history secret scan, and forbidden permission/entitlement checks passed |
| Artifact | [`phase-1a-evidence-30312994016-1`](https://github.com/sleep-paralysis-companion/sleep-paralysis-companion/actions/runs/30312994016/artifacts/8671256606), SHA-256 `8fd1adc84804153f05c9c2b17a52ca94f5a3db9eec074fe56744826fa6eec0cc`, retained 30 days |

The successful job ran `scripts/verify_ci.sh` from a full-history clean
checkout. The compile command confirmed Swift 6, strict concurrency,
warnings-as-errors, `arm64-apple-ios26.0-simulator`, and the iOS 26.5 SDK.
The build log copied both `PrivacyInfo.xcprivacy` and
`en.lproj/Localizable.strings` into the application.

The UI suite proved launch and typed navigation with meaningful localized
labels. It also launched the shell explicitly in light mode and in dark mode
with accessibility XXXL text, increased contrast, and Reduce Motion enabled;
the critical control remained present and hittable.

This evidence is simulator-only. It does not prove Apple-team signing,
physical-device behavior, TestFlight distribution, or any remaining Gate 0
external requirement.
