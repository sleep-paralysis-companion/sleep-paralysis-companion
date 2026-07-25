# Session Prompt: Phase 1H - Integrated Quality, Security, and Release Readiness

You are working in the SP / Paralux repository. This session is exclusively for **Phase 1H: Integrated quality, security, and release readiness**. Treat this prompt as the session's operating contract. Do not assume access to earlier chat.

## Entry gate

Read the execution plan, both engineering guides, all approved Phase 0 artifacts, every prior phase handoff/gate record, release checklist, current App Store requirements, and repository guidance. Inspect `git status`; preserve unrelated changes. Confirm required features and environments are complete enough for integrated validation. Do not conceal an earlier gate failure.

## Objective

Prove the complete Phase 1 product is safe, accessible, privacy-consistent, commercially correct, physically reliable, reviewable, supportable, and reproducibly buildable for App Store submission.

## Product contract to verify

- Non-medical wellness positioning; manual episode action only; no detection/prediction/prevention/treatment/emergency/guarantee claims.
- Guest/local-first core architecture; approved account-scoped Supabase sync; offline promises honored.
- No microphone/voice, HealthKit, Watch, AI, tracking, or other excluded capability.
- Ultra-light optional check-in limited to episode occurrence, perceived intensity, recovery state, and optional note.
- The alarm remains free; all other product functionality requires a verified StoreKit trial, subscription, approved grace state, or lifetime entitlement.
- Eligible monthly/annual customers may receive Apple's three-day introductory offer; there is no custom or global promotion clock.
- Privacy/legal/support, export/deletion, applicable account deletion, restoration, and subscription management remain accessible without entitlement.

## Required integrated work

- Run unit, integration, contract, migration, RLS/policy, UI, snapshot where useful, accessibility, performance, energy, security, privacy, audio, alarm, App Intent, StoreKit access, and recovery suites.
- Exercise the full core journey on the oldest supported device class and current iPhone hardware.
- Test clean install, upgrade from every supported schema/app version, reinstall, offline launch, poor/intermittent network, Supabase outage, token expiry/revocation, permission denial/revocation, full storage, corrupt/missing audio, background/termination/restart, time-zone/clock changes, and interrupted deletion.
- Complete the physical matrix for AlarmKit/fallback, locked/unlocked action, App Intent/control/widget, silent mode, Focus, notification settings, audio routes/interruptions, and app lifecycle.
- Complete the commercial matrix: introductory-offer eligibility/start/conversion/expiry, offline signed-expiration state, clock tampering, alarm-free behavior, paywall access, StoreKit purchase/pending/cancel/renew/retry/grace/refund/revoke/restore/reinstall/multi-device/lifetime, and data-rights availability.
- Audit privacy manifests, required-reason APIs, SDK manifests/signatures/provenance, entitlements, permissions/purpose strings, binary content, network traffic, logs, Keychain/file protection, secrets, Supabase RLS/storage policies, and environment isolation.
- Resolve crashes, hangs, data loss, semantic duplication, cross-account access, inaccessible critical flows, misleading copy, broken deletion/restoration, and commercial-access errors before release candidacy.
- Run external TestFlight with reproducible feedback capture and requirement/build traceability.
- Prepare accurate App Store metadata, screenshots, age rating, privacy details, review notes, support/privacy URLs, demo account/mode, purchase guidance, and special hardware instructions.
- Verify production backend and public URLs are live/stable for review.
- Establish monitoring, privacy-safe crash triage, support ownership, escalation, rollback, and approved feature-disable procedures.
- Produce the archived build from the approved pipeline and tagged source revision.

## Quality rules

- Fix root causes; do not suppress warnings, disable tests, broaden permissions, weaken RLS/TLS, hide features from review, or add production-only test bypasses.
- Use current official Apple/Swift/Supabase documentation for unstable release rules and record verification dates.
- Simulator evidence cannot replace required physical-device or StoreKit Sandbox/TestFlight evidence.
- Treat every mismatch between code, metadata, screenshots, policy, privacy answers, manifests, network behavior, and review notes as a release blocker until reconciled.
- Measure responsiveness, launch, scroll/input/navigation, audio start, grounding entry, memory, disk, network, and energy on approved target devices.

## Release blockers

Always block release for: core crash/hang/navigation corruption; user-visible data loss or meaning-changing duplication; cross-account access; promised offline grounding unavailable; hidden microphone/data transfer; broken account deletion/restoration/refund/revocation; inaccessible critical flow; prohibited claim; privacy/disclosure mismatch; alarm, trial, entitlement, or paywall behavior contradicting copy; mandatory controls gated; review credentials/URLs/products/backend unavailable.

## Accessibility evidence

Verify the complete core flow with VoiceOver, all Dynamic Type accessibility sizes, Voice Control, Switch Control, increased contrast, Reduce Motion/Transparency, right-to-left layout, silent/text alternatives, focus/announcements, and comfortably reachable controls. Charts require equivalent text.

## Definition of done

Mark Phase 1 done only when every included requirement maps to passing evidence; no release blocker remains; physical/offline flows pass; StoreKit trial/subscription/grace/lifetime rules are correct; no data crosses account boundaries or appears in logs; accessibility passes; privacy policy/App Store answers/SDK manifests/observed behavior agree; review notes are reproducible; and named product/engineering/QA/privacy/security/content/release owners sign the release record.

## Required release record

Include source revision/tag, version/build, Xcode/Swift/SDK/deployment target, Supabase migration and policy-test result, dependency lockfile and SDK/privacy audit, requirement traceability, device/OS matrix, accessibility/privacy/security/StoreKit-access/audio/alarm/offline reports, metadata/review-note revision, public URLs, known limitations, named approvals, and archived build provenance.

## Handoff

Report the release verdict first. Then list requirement coverage, source revision/build, automated evidence, physical-device evidence, TestFlight/StoreKit evidence, accessibility/privacy/security/commercial results, resolved blockers, remaining blockers/limitations, public review dependencies, rollback/monitoring readiness, and named approvals. State exactly what remains unverified. Do not claim App Store readiness if any required evidence is absent.
