# Phase 1C Test and Hosted-CI Evidence

> **SUPERSEDED FOR PRODUCT ACCEPTANCE - 29 July 2026.** The jobs and coverage below test the obsolete guest-only flow. They do not validate the approved authenticated persona, local-only audio, recording/import, or widget/manual-action scope in [Persona and Personal Audio Product Realignment](../phase-0/PERSONA_AND_PERSONAL_AUDIO_REALIGNMENT.md).

Workflows:

- `.github/workflows/phase-1c-onboarding.yml`
- `codemagic.yaml`

Status: **PENDING EXACT FINAL HEAD**

The hosted configurations have two equivalent verification jobs:

1. Xcode 26.6 / iPhone 17 / iOS 26.5: pinned bootstrap, formatting, lint, contract/static/privacy/
   secret scans, warnings-as-errors build, unit tests, and UI tests on the exact created simulator
   UDID. Unit/UI xcresults and exported screenshot attachments are retained for 30 days.
2. Supabase 2.110.0 / PostgreSQL 17 / pgTAP: isolated reset, database tests/lint, Edge Function
   formatting/lint/type-check/tests, and secret scan. It never links the live project.

## Hosted provider recovery

GitHub Actions run `30359181461` for pushed head
`f66bbaf18ecdbfa1d0a3af635aef4d616ed596d8` was rejected before runner assignment
because the repository owner's Actions payment or spending limit blocked both jobs. It executed
zero steps and is not passing evidence.

The Codemagic workflows perform no signing, deployment, TestFlight upload, or live Supabase
access. The iOS workflow pins Xcode 26.6 and uses the repository's exact iPhone 17/iOS 26.5
simulator-UDID preparation. The backend workflow uses Ubuntu 24.04, Docker, pinned Supabase CLI
2.110.0, Postgres 17, pgTAP, and Deno 2.8.1. Both wrappers assert that the checked-out Git SHA
equals Codemagic's `CM_COMMIT` before testing.

Codemagic build IDs, URLs, test counts, artifacts, and the final evidence SHA remain pending until
both workflows complete successfully.

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
