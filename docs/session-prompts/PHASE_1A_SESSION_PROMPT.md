# Session Prompt: Phase 1A - Repository and Platform Foundation

You are working in the SP / Paralux repository. This session is exclusively for **Phase 1A: Repository and platform foundation**. Treat this prompt as the session's operating contract. Do not assume access to earlier chat.

## Entry gate

Before changing production code, read `docs/PHASE_1_EXECUTION_PLAN.md`, both engineering best-practice guides, all `docs/phase-0/` artifacts, and the Gate 0 approval record. Inspect repository guidance and `git status`; preserve unrelated changes.

If Gate 0 has not passed, do not create the production app foundation. Report the specific unmet entry conditions and continue only with safe Phase 0 documentation/evidence work if it is within scope. Do not silently waive the gate.

### Owner-authorized Phase 1A exception — 28 July 2026

Satyam Shree explicitly authorized the repository/application foundation work
for Phase 1A before the remaining external Gate 0 evidence is complete. This
exception authorizes only Phase 1A foundation code and evidence. It does not
mark Gate 0 passed and does not authorize Phase 1B, live Supabase changes,
RevenueCat/App Store product creation, Figma mutation, feature implementation,
or unsupported platform, medical, privacy, or commercial claims.

## Objective

Establish a reproducible, secure native Swift/SwiftUI foundation that later feature sessions can extend without bypassing privacy, accessibility, concurrency, testing, or environment boundaries.

## Adopted product constraints

Carry forward the approved Phase 0 contract, including guest/local-first operation, manual episode action, no prohibited medical/detection claims, excluded microphone/HealthKit/Watch/AI capabilities, offline grounding, ultra-light check-in, and the commercial access model: alarm and mandatory utilities free; all other functionality requires active RevenueCat `premium_access` backed by an Apple trial, subscription, or lifetime purchase; no grace. Mandatory privacy/data/account/purchase-management controls are never entitlement-gated.

## Working method

1. Confirm approved bundle identifiers, Apple team roles, deployment target, environments, and stable Xcode/Swift toolchain.
2. Create a concise implementation plan and map each change to requirement IDs.
3. Implement only Phase 1A. Do not build feature screens, Supabase production schemas, paywalls, or final platform integrations.
4. Use current official Apple/Swift documentation for unstable toolchain and platform facts.
5. Run relevant checks after each meaningful slice and preserve evidence.

## Required implementation

- Create the native iOS SwiftUI app and required unit/UI test targets using the stable toolchain accepted by App Store Connect.
- Enable the approved Swift language mode and strict concurrency checks. Project-owned code must build without warnings.
- Establish clear feature, domain, data, platform, design-system, configuration, and test boundaries with inward dependency direction.
- Create environment injection for development, staging, and production. Nonproduction builds must not reach production resources. Commit no credentials.
- Add deterministic formatting, linting, build, unit-test, and UI-test commands suitable for clean checkout and CI.
- Establish typed, value-based navigation and dependency composition seams without prematurely implementing feature flows.
- Add semantic design tokens for color, typography, spacing, shape, motion, contrast, Dynamic Type, Reduce Motion, and light/dark behavior.
- Establish privacy-safe unified logging with redaction and no sensitive payloads.
- Create the initial `PrivacyInfo.xcprivacy`, required-reason API review process, dependency/SDK provenance register, and third-party privacy review gate.
- Define typed feature flags/access-policy seams for platform-dependent and release-gated behavior. Do not implement time or entitlement logic as scattered view conditionals.
- Document build, test, environment, configuration, and onboarding commands.

## Code-generation and review rules

- SwiftUI views render state and send user intent; they do not call persistence, Supabase, StoreKit, AlarmKit, AVFoundation, files, or raw networking.
- Use protocols only at real replaceable boundaries. Avoid generic repositories, managers/helpers, service locators, and speculative abstractions.
- UI-facing observable state is `@MainActor`; use value semantics by default and actors for genuinely shared mutable state.
- Use structured concurrency and explicit cancellation. Do not use `@unchecked Sendable`, `nonisolated(unsafe)`, detached tasks, semaphores, forced unwraps/casts, or empty catches as shortcuts.
- Use typed errors and user-safe messages; never expose tokens, paths, policy details, backend errors, or stack traces.
- Use native semantic controls, localization-ready strings, adaptive layout, stable identity, and meaningful previews.
- Tests must be deterministic and inject clocks, calendars, identifiers, storage, network, permissions, and access policy where relevant.
- Never weaken production behavior to make tests pass.

## Verification

- From a clean checkout, run documented format/lint/build/unit/UI checks.
- Verify development and staging cannot resolve production endpoints.
- Scan repository history/resources/log output for secrets or privileged Supabase keys.
- Validate privacy manifest structure and dependency register.
- Verify the shell at accessibility Dynamic Type sizes, VoiceOver basics, light/dark mode, increased contrast, and Reduce Motion.
- Record the exact Xcode, Swift, SDK, and deployment target used.

## Gate 1A exit

Mark Gate 1A passed only if clean checkout builds/tests reproducibly, environment isolation is proven, dependency/privacy provenance is recorded, the accessible shell works, and no secret/privileged key exists in resources, logs, or history.

## Handoff

Report requirement IDs, outcome, files/systems changed, decisions used, commands and results, accessibility/privacy/security evidence, known limitations, unresolved blockers, whether Gate 1A passed, and the next safe Phase 1B work item. State what remains unverified.
