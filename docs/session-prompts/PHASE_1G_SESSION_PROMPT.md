# Session Prompt: Phase 1G - Settings, Privacy, Accounts, and Purchases

You are working in the Sleep Paralysis Companion repository. This session is exclusively for **Phase 1G: Settings, privacy, accounts, RevenueCat/StoreKit access, paywall, and purchases**. Treat this prompt as the session's operating contract. Do not assume access to earlier chat.

## Entry gate

Read the execution plan, engineering guides, approved Phase 0 data/account/legal/commercial/access artifacts, RevenueCat/StoreKit product map, introductory-offer/no-grace decisions, and prior handoffs. Inspect repository guidance and `git status`; preserve unrelated changes. Confirm public legal/support URLs, RevenueCat and App Store Connect product configuration, entitlement rules, and Apple purchase authority. If any missing choice materially affects access, billing, retained data, or user rights, stop and ask rather than inventing it.

## Objective

Give users deterministic control over settings, identity, data, and purchases while implementing the approved RevenueCat/StoreKit access model that leaves the alarm and mandatory utilities available without premium.

## Commercial contract

- The alarm remains available without payment at all times.
- All other product functionality requires active RevenueCat `premium_access` backed by an eligible Apple three-day introductory trial, monthly/annual subscription, or lifetime non-consumable.
- Apple is purchase and payment authority; RevenueCat `premium_access` is the app entitlement boundary. Do not implement a custom trial clock, global promotion interval, Supabase premium Boolean, or device-clock-derived entitlement.
- Show trial copy only when StoreKit confirms introductory-offer eligibility.
- Family Sharing and Billing Grace Period are off for Phase 1. Do not add custom grace. Cut premium immediately when verified `premium_access` becomes inactive, and start the in-app reminder at most 72 hours before a known nonrenewing expiration.
- Privacy policy, terms, support, data export, individual/all-data deletion, applicable account deletion, purchase restoration, and subscription management remain accessible without entitlement.
- Do not delete, corrupt, or silently hide ownership of user data when entitlement ends. Follow the approved access/data UX.

## Required implementation

- Implement schedule/alarm, audio, notification, accessibility, privacy, support, account, purchase restoration, and subscription-management settings with deterministic persisted effects.
- Reflect actual system authorization state and link to iOS Settings only where appropriate.
- Implement export, individual-record deletion, complete local-data deletion, and approved remote deletion behavior.
- If account creation exists, implement in-app complete account deletion, token revocation where applicable, retained-data disclosure, interruption/retry, and completion notice.
- Publish and link approved privacy policy, terms, support, wellness disclaimer, and account-deletion information.
- Implement the RevenueCat Purchases SDK over Apple StoreKit product and transaction state. Never unlock from an unverified client claim or writable Supabase row.
- Display localized StoreKit prices/terms; do not hard-code product prices or trial language.
- Implement purchase, pending, cancellation, Ask to Buy, renewal, billing retry without grace, known-expiration reminder, immediate cutoff, expiration, refund, revocation, restore, reinstall, and multi-device behavior.
- When server enforcement is approved, use trusted Supabase Edge Functions with verified App Store Server API/Notifications payloads, environment separation, deduplication, replay protection, and idempotency.
- Implement one typed access-policy service driven by RevenueCat CustomerInfo backed by Apple transaction and renewal state. Define refresh, offline signed-expiration behavior, no-grace cutoff, reminder, pending, expiry, refund/revocation, clock tampering, customer/transaction updates while the app is running, and recovery.
- Feature access must use one deterministic matrix: alarm free; active `premium_access` backed by trial/subscription/lifetime opens premium; expired/refunded/revoked/unknown closes premium immediately; mandatory controls always open.
- Complete App Store privacy answers from observed behavior and the data inventory, including every SDK.

## Architecture/security rules

- Views do not call StoreKit, Supabase, Keychain, export/delete, system settings, or network APIs directly.
- Keep RevenueCat CustomerInfo, Apple transaction/renewal state, derived access decision, and feature availability separate and explicitly modeled. Supabase account state must not grant premium.
- Verify signed transactions/payloads before use; secrets and privileged credentials remain server-only.
- Use structured concurrency, cancellation, idempotent transaction handling, typed errors, injected clocks/configuration, privacy-safe logs, and deterministic state transitions.
- Never block the free alarm on network, account, purchase, or entitlement verification.
- Never put privacy/data rights or restoration behind a paywall.
- Do not expose external checkout to unlock in-app digital functionality unless a current approved App Review exception/entitlement explicitly applies.

## Required tests/evidence

- Settings persistence and real system-authorization refresh/recovery.
- Export/deletion reconciliation against local/remote data inventory, including interrupted deletion and offline state.
- Account conversion/sign-in/out/token expiry/reinstall/account deletion, including Keychain and private local data.
- RevenueCat configuration, StoreKit configuration tests, Sandbox, and TestFlight for every purchase/entitlement lifecycle state.
- Introductory-offer and entitlement tests cover eligible/ineligible presentation, trial start/conversion/expiry, time zones and clock changes, offline signed expiration, reinstall, multiple devices, app-running transitions, reminder, no-grace cutoff, and recovery.
- Access matrix tests prove the alarm is always free and mandatory controls are always accessible.
- Refund/revocation tests remove premium access without deleting user data or blocking export/deletion.
- Privacy manifest, required-reason API, SDK, network-traffic, policy, purpose-string, and App Store privacy-answer reconciliation.
- Accessibility tests for settings, paywall, purchase errors, restore, subscription management, export, and destructive/account deletion.

## Evidence rule

Local StoreKit configuration is not sufficient evidence for RevenueCat/Sandbox/TestFlight behavior. Do not claim App Store Connect, RevenueCat webhooks, trial, no-grace cutoff, refund, or production entitlement behavior without the corresponding environment evidence.

## Gate 1G exit

Pass only when every setting is deterministic, export/deletion matches the inventory, account deletion works end to end when accounts exist, the full RevenueCat/StoreKit access matrix passes, the alarm remains free, mandatory controls remain available, and disclosures match observed behavior.

## Handoff

Report requirement IDs, outcome, files/systems/URLs changed, product IDs and environments used without secrets, access decisions, automated/Sandbox/TestFlight evidence, accessibility/privacy/security impact, limitations, blockers, whether Gate 1G passed, and the next safe Phase 1H work item. State what remains unverified.
