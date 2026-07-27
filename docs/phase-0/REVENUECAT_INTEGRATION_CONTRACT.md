# RevenueCat and Apple Commerce Integration Contract

**Contract ID:** `RC-P1-004`
**Owner:** Satyam Shree
**Status:** Architecture approved 28 July 2026; external configuration and
runtime evidence pending

## 1. System responsibilities

| System | Approved responsibility | Must not do |
|---|---|---|
| App Store Connect / StoreKit | Products, prices, introductory offer, transaction/payment truth, renewal, refunds, banking, tax, agreements | Store private wellness data |
| RevenueCat | Purchases SDK, Offering/package mapping, `premium_access` entitlement, customer-information updates, restore orchestration, entitlement webhooks/analytics | Receive bank details, become a writable source of wellness data, or expose secret keys in the app |
| Supabase | Optional Apple/Google account sync and, if later approved, a server-side RevenueCat webhook audit/mirror | Grant premium from a client-writable row or couple purchase restore to login |
| iPhone app | Present localized store facts and derive feature access from active `premium_access` | Hardcode localized prices, invent trial/grace state, or transmit check-ins/audio history to RevenueCat |

RevenueCat is not the payment processor for Apple In-App Purchases. Apple pays
the developer through the bank account configured in App Store Connect after
the applicable Paid Apps Agreement and tax requirements are completed.

## 2. External account and ownership

Create the RevenueCat project under a durable organization-owned email rather
than sharing one password. Enable two-factor authentication and store recovery
codes outside the repository.

Project name: `Sleep Paralysis Companion`

To share access with Satyam:

1. obtain Satyam's exact RevenueCat email;
2. invite that email under **Project settings > Collaborators**;
3. use `Administrator` only if Satyam must configure apps, integrations,
   products, entitlements, Offerings, and collaborators;
4. enforce two-factor authentication after every existing collaborator has
   enabled it; and
5. never send passwords, MFA seeds, recovery codes, Apple keys, or RevenueCat
   secret keys through chat or commit them.

Only the RevenueCat project owner manages RevenueCat account billing.
RevenueCat project collaboration is separate from App Store Connect banking.

## 3. Product model

One entitlement:

- `premium_access`

One current Offering:

- `default`

Planned packages:

| Package | Apple product | Access |
|---|---|---|
| Monthly | USD 8.99 auto-renewable | `premium_access` while active |
| Annual | USD 59.99 auto-renewable | `premium_access` while active |
| Lifetime | USD 149.99 non-consumable | `premium_access` unless refunded/revoked |

The monthly and annual products are in one Apple subscription group. Eligible
customers may receive Apple's three-day introductory free trial. Family
Sharing is off. App Store Connect Billing Grace Period is disabled.

Production product IDs remain unset until the production bundle identifier and
App Store Connect app record exist. Disposable spike IDs are not silently
promoted to production.

## 4. Identity and restore

- Purchases do not require a Supabase account.
- Before optional sign-in, RevenueCat may use its anonymous App User ID.
- After Apple/Google account sign-in, the app may identify RevenueCat with a
  stable pseudonymous identifier derived for commerce; it must not send email,
  name, note text, alarm time, check-in answers, or audio/listening history.
- Login/logout/alias behavior must be tested so one person's purchase never
  appears for another local profile.
- Restore remains a user-visible action and follows Apple/RevenueCat supported
  restore behavior regardless of Supabase availability.

## 5. Immediate cutoff and reminder

- No Apple Billing Grace Period and no custom RevenueCat/app grace.
- When `premium_access` becomes inactive at expiration, refund, or revocation,
  premium closes immediately; alarm and mandatory utilities remain.
- If the store reports a known nonrenewing expiration, an in-app reminder may
  start at `expiration - 72 hours`, no more than once per local day.
- Normally auto-renewing subscriptions do not receive a false "expiring"
  warning.
- Billing failure discovered at renewal cannot be warned three days in
  advance. Show the billing-recovery route after the inactive/billing-issue
  state is observed.
- No push/local reminder notification is authorized yet.

## 6. Secrets, webhooks, and privacy

- Only the RevenueCat **public iOS SDK key** may ship in the app.
- RevenueCat secret keys, Apple `.p8` keys, shared secrets, and webhook
  authorization secrets remain in approved secret stores.
- If a Supabase Edge Function receives RevenueCat webhooks, it verifies the
  authorization secret, validates schema/environment, deduplicates and orders
  events, uses idempotency, rejects replay, and logs no payload containing
  direct customer or transaction secrets.
- Webhook state is an audit/server-enforcement mirror, not a client-writeable
  entitlement grant.
- RevenueCat data collection, retention, subprocessors, SDK privacy manifest,
  required-reason APIs, and deletion behavior must be reconciled with the
  privacy policy and App Store privacy answers.

## 7. Required evidence

- RevenueCat owner/project ID and Satyam collaborator role, without secrets;
- 2FA status and least-privilege review;
- iOS app/bundle mapping and public SDK-key provenance;
- imported Apple products and `premium_access`/Offering/package mappings;
- App Store Connect agreement, tax, and banking status recorded without bank
  details;
- trial eligible/ineligible, purchase, pending, cancel, restore, renewal,
  cancellation-at-period-end, immediate billing-failure cutoff, refund,
  revocation, Lifetime, offline, reinstall, multi-device, and identity-change
  evidence;
- 72-hour/48-hour/24-hour/expiration reminder boundary tests;
- webhook signature/auth, replay, idempotency, ordering, environment, and
  negative isolation tests if webhook integration is enabled; and
- named Product, Commerce, Privacy, Security, iOS, QA, and Release approval.
