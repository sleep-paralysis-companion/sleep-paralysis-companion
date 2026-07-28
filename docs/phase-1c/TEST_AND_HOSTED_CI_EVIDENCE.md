# Phase 1C Test and Hosted-CI Evidence

Workflow: `.github/workflows/phase-1c-onboarding.yml`

Status: **PENDING EXACT FINAL HEAD**

The workflow has two jobs:

1. Xcode 26.6 / iPhone 17 / iOS 26.5: pinned bootstrap, formatting, lint, contract/static/privacy/
   secret scans, warnings-as-errors build, unit tests, and UI tests on the exact created simulator
   UDID. Unit/UI xcresults and exported screenshot attachments are retained for 30 days.
2. Supabase 2.110.0 / PostgreSQL 17 / pgTAP: isolated reset, database tests/lint, Edge Function
   formatting/lint/type-check/tests, and secret scan. It never links the live project.

## Coverage map

| Requirement | Automated evidence |
|---|---|
| Clean install reaches Home as guest | UI clean-install flow; app-model state test |
| No account/paywall/network/permission blocker | UI absence checks; Phase 1C contract scan; composition inspection |
| Every onboarding restoration point | app-model launch truth-table test; UI termination/relaunch test |
| Duplicate Continue | app-model call-count test; database idempotence test |
| Database failure and retry | fault-injected GRDB rollback test; app-model failure/retry test |
| Current/superseded notice | launch routing and acknowledgement tests |
| Malformed/stale/future route | restoration codec/app-model fallback tests |
| Offline guest launch | in-memory/local-store launch tests and no-network composition scan |
| Wrong-account/auth-required | app-model preservation test |
| Accessibility text sizes | five-category UI loop and design-token unit tests |
| VoiceOver semantics | UI labels/order plus heading and feedback focus/update-trait checks |
| Reduce Motion/contrast/appearance/RTL/narrow | hosted UI launch configurations and screenshots |
| Prohibited copy/framework/permission/entitlement/secret/network | contract, static, manifest, and secret scripts |

Exact head SHA, run/job IDs, simulator UDID, test counts, toolchain, artifact names/IDs/digests,
and final verdict will be recorded only after the documentation-inclusive pushed head is green.
