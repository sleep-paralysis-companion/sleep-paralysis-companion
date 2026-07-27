# Commercial Access, Permissions, and Entitlements

**Contract ID:** `COM-P1-001`  
**Status:** Product/Finance model approved; App Store Connect, Sandbox, and
physical evidence pending  
**Updated:** 25 July 2026

## 1. Commercial model

### Adopted by Satyam Shree; updated 28 July 2026

- The bedtime alarm remains free at all times.
- Every other product feature requires one logical RevenueCat entitlement:
  `premium_access`.
- Eligible customers may start one Apple-managed **three-day introductory free
  trial** in the subscription group. Customer-facing copy says `three-day
  free trial`, not `three-night trial`, because StoreKit measures the offer as
  a three-day duration.
- Two auto-renewable products are planned: monthly at **USD 8.99** and annual
  at **USD 59.99** in the United States storefront.
- One non-consumable lifetime unlock is planned at **USD 149.99** in the
  United States storefront. Customer-facing copy uses `Lifetime`, not
  `lifelong`.
- The introductory offer applies to eligible monthly/annual purchases. Apple
  permits one introductory-offer redemption per customer per subscription
  group. The lifetime product has no automatic trial or renewal.
- The paywall fetches localized prices and eligibility from StoreKit; the USD
  amounts in this contract are not hardcoded UI strings.
- Family Sharing is disabled for Phase 1.
- Apple Billing Grace Period and any RevenueCat/custom grace are **disabled**.
  When the verified `premium_access` entitlement becomes inactive at
  expiration, refund, or revocation, premium access ends immediately.
- A noncoercive in-app expiration reminder begins at most 72 hours before a
  known expiration only when the subscription/trial is not expected to renew.
  It appears no more than once per local day and links to subscription
  management. It is not a push/local notification unless separately approved.
- Privacy, legal, support, data export/deletion, applicable account deletion,
  purchase restoration, subscription management, refund help, and accurate
  access status remain available regardless of entitlement.
- Supabase account state never grants premium access.

The monthly and annual products use one subscription group at the same service
level. The lifetime non-consumable grants the same logical entitlement and
takes precedence over subscription presentation. Product IDs, localized
descriptions, and App Store configuration remain evidence work rather than
open product decisions.

## 2. Feature access matrix

| Feature | No verified premium | Verified trial/subscription/lifetime | Expired/refunded/revoked/unknown |
|---|---:|---:|---:|
| View/configure/edit/remove bedtime alarm | Yes | Yes | Yes |
| View actual alarm/permission state | Yes | Yes | Yes |
| First-use product boundary and Home shell | Yes | Yes | Yes |
| Manual system surface | Visible as a neutral route to the paywall; no premium grounding starts | Yes | Same as no premium |
| Grounding session and bundled audio/visual content | No | Yes | No |
| Preparation/audio library and downloads | No | Yes | No new starts/downloads |
| Optional check-in | No | Yes | No new/edit; see expired-data rule below |
| History | No | Yes | No ordinary view; export/delete remain available |
| Optional account creation/sync | No | Yes | Sync pauses; export/delete/account utilities remain |
| Existing local/remote data export | Yes | Yes | Yes |
| Delete entry/local data/account | Yes | Yes | Yes |
| Privacy, terms, wellness notice, support | Yes | Yes | Yes |
| Paywall/purchase/restore | Yes | Yes | Yes |
| Manage subscription/refund help | Yes | Yes | Yes |

### Expired-data rule

Expiry never deletes or corrupts a person's data. Local history and check-ins
remain stored until the person exports, deletes, or regains access. Data-rights
screens may list counts/scope necessary to export/delete but must not expose
premium history content through a loophole.

Satyam Shree explicitly approved putting manual grounding and ordinary history
access behind the paywall while keeping the alarm and all account/data/purchase
utilities available. The paywall must remain calm, dismissible, and must never
claim that payment is needed for safety.

## 3. Trial, product, and offline policy

### 3.1 Authority and eligibility

Apple App Store Connect and StoreKit remain the payment, product, transaction,
renewal, refund, and banking authorities. RevenueCat is the approved
entitlement-orchestration layer over those Apple transactions. Supabase does
not start a trial, store a client-writable premium Boolean, or grant
entitlement. The app:

1. configures the RevenueCat Purchases SDK with the iOS app's **public SDK
   key only**;
2. loads monthly, annual, and lifetime packages through the approved
   RevenueCat Offering, whose product/price facts come from StoreKit;
3. shows trial copy only when the Apple/RevenueCat product state confirms the
   introductory offer is applicable;
4. grants premium only when RevenueCat `CustomerInfo` reports the
   `premium_access` entitlement active;
5. observes RevenueCat customer-information updates and provides restore on
   every supported device;
6. treats the lifetime non-consumable mapped to `premium_access` as
   non-expiring unless Apple reports revocation/refund; and
7. never infers trial or entitlement from install date, account date, a
   Supabase row, or device wall clock.

RevenueCat secret API keys and Apple credentials are server/dashboard secrets.
They never ship in the app or enter this repository. A verified RevenueCat
webhook may update a server-side audit/mirror for support or server
enforcement, but a client-writable Supabase row can never grant access.

### 3.2 Paywall UX

- The alarm remains usable before, during, and after the paywall.
- The recommended default selection is annual, but no pre-checked purchase or
  automatic purchase call occurs.
- Eligible subscription copy follows `3 days free, then [localized StoreKit
  price]/[period] until canceled`.
- Ineligible customers see the current localized price and renewal period
  without trial copy.
- Lifetime is shown separately as `One-time purchase` with its localized
  StoreKit price and no cancellation or trial language.
- Monthly, annual, and lifetime provide the same premium feature set.
- The paywall includes Restore Purchases, Manage Subscription where
  applicable, Privacy, Terms, and a clear close action.
- Renewal, cancellation, billing, and trial eligibility use Apple-supplied
  facts; deleting a Sleep Paralysis Companion account does not cancel billing.

### 3.3 Offline, cutoff, and reminder behavior

The former `global-promotion UTC interval and offline grace` question meant:
when a server-defined public launch window starts and ends, and how long cached
free access continues without a network. That mechanism is now retired.

For the approved model:

- an unexpired, cryptographically verified StoreKit trial/subscription
  transaction represented by RevenueCat's trusted cached customer state may
  remain active offline through its known expiration;
- lifetime remains active from its verified non-consumable transaction;
- App Store Connect Billing Grace Period is disabled and the app invents no
  custom, RevenueCat, 24-hour, or device-clock grace;
- after verified expiry, revocation, refund, or an unverifiable state beyond
  the signed period, only the alarm and utility routes remain; and
- a Supabase outage never changes RevenueCat/StoreKit access.

The three-day reminder is defined precisely:

- calculate from the store-provided expiration instant, never from device
  install/account dates;
- show only when 72 hours or less remain and auto-renewal is known to be off,
  or when a trial has a known nonrenewing end;
- show at most once per local day on an ordinary app surface, never inside an
  active grounding sequence;
- include `Manage subscription` or an honest resubscribe action;
- do not schedule a local/push notification without a separately approved
  permission, copy, and device test; and
- a payment failure discovered at renewal cannot be pre-announced. With grace
  disabled, access ends when the entitlement becomes inactive and the next
  app-open message explains the billing issue and recovery route.

## 4. StoreKit state machine

| State | Evidence | Access |
|---|---|---|
| `not_purchased` | No verified current entitlement | Utility-free access |
| `purchasing` | Purchase call active | No premium yet; prevent duplicate request |
| `pending` | StoreKit pending/Ask to Buy | No premium yet; explain non-error pending state |
| `cancelled` | User cancels | Preserve prior state; neutral close |
| `failed` | StoreKit failure | Preserve prior state; recoverable message |
| `unverified` | Transaction verification fails | Never unlock; security/error handling |
| `active` | Verified current entitlement | Premium |
| `in_grace_period_unexpected` | Store reports grace despite approved disabled configuration | Do not extend access through app logic; flag configuration mismatch and use the verified active/inactive RevenueCat entitlement result |
| `billing_retry_no_grace` | No verified entitled grace state | Utility-free access; billing help |
| `expired` | Verified expiration | Utility-free access; retain data |
| `refunded` | Verified revocation/refund | Remove premium access; retain data |
| `revoked` | Verified revocation | Remove premium access; retain data |

Rules:

- observe RevenueCat customer-information updates for the app lifecycle;
- let the supported RevenueCat SDK/StoreKit integration finish verified
  transactions according to the pinned integration contract;
- use active RevenueCat entitlements for current access and the supported
  restore flow for restoration;
- fetch product display data from RevenueCat/StoreKit and never hardcode
  localized price;
- prevent two simultaneous products in the same subscription group;
- test purchase, Ask to Buy/pending, cancel, failure, unverified, renewal,
  expiry, retry without grace, refund, revoke, restore, reinstall, multiple
  devices, reminder boundaries, and absence of Family Sharing;
- do not require Supabase login to purchase or restore;
- show Apple's manage-subscription surface and refund-request route;
- explain that app account deletion does not cancel Apple billing; and
- App Store metadata/screenshots identify paid features honestly.

## 5. Commercial access evaluation

Evaluate in this order:

1. Always-free alarm or utility route? Grant.
2. Active RevenueCat `premium_access` from an Apple trial, subscription, or
   lifetime
   entitlement? Grant premium.
3. Otherwise deny the premium route with `SCR-015`.

Server account claims, a database Boolean, install date, onboarding date,
device clock, analytics flag, unverified receipt string, or
client-side debug override cannot grant production premium access.

The app keeps one pure access decision function whose inputs are:

- feature ID;
- active/inactive RevenueCat `premium_access` state plus known expiration and
  renewal facts;
- network/freshness state; and
- build environment.

Every cell of §2 has a test. Debug/store-review overrides exist only in
nonproduction or an approved review mode that cannot leak into production
customer access.

## 6. Permission and entitlement register

### Requested permissions

| ID | Capability | Phase 1 state | Just-in-time purpose | Denied/restricted behavior |
|---|---|---|---|---|
| `PERM-001` | AlarmKit authorization | `REQUIRED` if AlarmKit path selected | After person confirms an alarm; purpose string explains scheduling bedtime alarms | No alarm is scheduled; show actual state and proven fallback/settings route |
| `PERM-002` | User notifications authorization | `CONDITIONAL` only for approved reminder/fallback | Immediately before scheduling that specific notification behavior | AlarmKit path/local app remain; explain fallback limitation |

`NSAlarmKitUsageDescription` is required and must match `CLM-*` copy. The exact
string needs Content/Claims approval and physical validation.

### Capabilities without a general permission prompt

| ID | Capability/entitlement | State | Constraint |
|---|---|---|---|
| `PERM-010` | In-App Purchase / StoreKit | `REQUIRED` | One approved subscription group and verified transactions |
| `PERM-021` | RevenueCat Purchases SDK | `REQUIRED` | Public iOS SDK key only; pinned dependency; privacy manifest/SDK signature/provenance review; no wellness content or secret key |
| `PERM-011` | App Intents | `CONDITIONAL REQUIRED` | Only the surface selected by device spike; no private parameter exposed |
| `PERM-012` | Widget/Control extension | `CONDITIONAL` | Include only if selected surface proves useful; shared data minimized |
| `PERM-013` | App Group | `CONDITIONAL` | Only if an approved extension needs minimal route/state; no full history/note database |
| `PERM-014` | Live Activities / Alarm presentation support | `CONDITIONAL` | Only the selected AlarmKit configuration; neutral content and lifecycle test |
| `PERM-015` | Background audio mode | `CONDITIONAL` | Enable only if approved locked/background playback requires it and physical/privacy review passes |
| `PERM-016` | Sign in with Apple | `REQUIRED FOR ACCOUNT MODE` | Offered alongside Google for optional sync; Apple branding/nonce/reauth/linking and token revocation on deletion |
| `PERM-017` | Associated Domains | `CONDITIONAL` | Only if the approved OAuth callback or universal-link flow needs it |
| `PERM-018` | Keychain access group | `CONDITIONAL` | Only if an approved extension/auth design requires sharing; least privilege |
| `PERM-019` | Sign in with Google / OAuth callback | `REQUIRED FOR ACCOUNT MODE` | Offered alongside Apple; approved SDK or browser flow, nonce/state/PKCE as applicable, privacy manifest, callback, reauth, linking, and revocation behavior |
| `PERM-020` | Email/password, passwordless email, phone, or OTP account authentication | `EXCLUDED` | Phase 1 optional account mode offers only Sign in with Apple and Sign in with Google |

### Explicitly absent

| ID | Permission/capability | Phase 1 rule |
|---|---|---|
| `PERM-X-001` | Microphone / speech recognition | Must not appear |
| `PERM-X-002` | HealthKit/clinical health records | Must not appear |
| `PERM-X-003` | Camera/photos/media library | Must not appear |
| `PERM-X-004` | Contacts | Must not appear |
| `PERM-X-005` | Location | Must not appear |
| `PERM-X-006` | Bluetooth | Must not appear |
| `PERM-X-007` | Tracking/IDFA/AdSupport | Must not appear |
| `PERM-X-008` | Push Notifications/APNs | Must not appear unless new approved remote-push requirement reopens it |
| `PERM-X-009` | Critical alerts | Must not appear |
| `PERM-X-010` | Apple Watch/watchOS target | Must not appear |

Absence is verified in target settings, entitlements, Info.plist purpose strings,
linked frameworks/SDKs, privacy manifest, built binary, runtime prompts,
network traffic, and App Store privacy answers.

## 7. Request timing and UX

For each requested permission:

1. person selects the feature;
2. in-app copy explains the concrete value, data/system effect, and fallback;
3. person may continue/cancel without losing local data;
4. the system prompt appears once at the moment of need;
5. app reads and displays actual result;
6. denial is respected—no prompt loop or false success;
7. when appropriate, a clearly labeled iOS Settings route is available; and
8. foreground return refreshes actual state.

Onboarding must not front-load AlarmKit or notification prompts.

## 8. Refund, revoke, expiry, and account deletion

- Refund/revoke/expiry removes premium access after verified transaction update;
  it does not delete personal data.
- Account deletion does not cancel or refund an Apple subscription.
- Before account deletion, show Apple subscription state when available and the
  Manage Subscription/Refund Help routes, while still allowing immediate
  deletion.
- A former subscriber can always export/delete data and restore/manage
  purchases.
- Re-purchase/restore uses the same retained local data unless the person
  deleted it.
- No bespoke refund promise overrides Apple policy.

## 9. Environment and release gates

Before release:

- product IDs, group, durations, prices, territories, review screenshots, and
  localization are approved in App Store Connect;
- monthly/annual/lifetime products, United States prices, one subscription
  group, three-day introductory offer, Family Sharing off, and Billing Grace
  Period disabled are configured exactly as approved;
- RevenueCat project/app, `premium_access` entitlement, default Offering,
  monthly/annual/lifetime package mappings, restore behavior, Apple
  credentials, webhook security, collaborator access, and SDK public key are
  reviewed and evidenced;
- Sandbox and TestFlight pass every state/boundary;
- Billing Grace Period setting exactly matches app logic and tests;
- production policy cannot be changed by the client or staging credentials;
- store-review access/notes explain alarm-free and premium/trial behavior;
- privacy/terms/support URLs are live;
- the paywall remains closable and utility routes reachable; and
- manual-grounding paywall placement has explicit Product/UX acceptance.

## 10. Open approvals

| Decision | Owner required | Gate impact |
|---|---|---|
| App Store Connect product IDs, localized metadata, storefront price-point confirmation, and review screenshots | Release + Product | Blocks StoreKit configuration evidence, not the product decision |
| RevenueCat plus StoreKit Sandbox coverage for trial eligibility/conversion, monthly/annual switching, lifetime, immediate cutoff, reminder boundary, restore, refund, and revoke | iOS + QA | Blocks commercial acceptance evidence |
| Minimum iOS target and notification fallback | Product + iOS + QA | Blocks permission set |
| App Intent/control/widget/background audio capabilities | iOS + Design + Privacy + QA | Blocks entitlements/binary manifest |
| Supabase Apple/Google callbacks, provider linking/collision, reauthentication, recovery, and abuse-control test evidence | Backend + Security + Privacy | UX direction is approved; blocks implementation acceptance evidence |
