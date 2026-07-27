# Sleep Paralysis Companion Privacy Policy - Phase 1 Draft

**Document ID:** `PRIV-P1-002`  
**Status:** Product-accurate working draft - not legal advice and not approved
for publication  
**Prepared:** 25 July 2026  
**Replaces:** the rejected template reviewed under `PRIV-P0-001`

Before publication, replace every bracketed field and complete an
applicability review for every distribution territory.

## Privacy Policy

**Effective date:** `[PUBLICATION DATE]`  
**Provider:** Sleep Paralysis Companion  
**Address:** `[MAILING ADDRESS]`  
**Privacy contact:** `[PRIVACY EMAIL]`

This policy explains how Sleep Paralysis Companion handles information in the
Sleep Paralysis Companion iPhone application.

### What the app is

Sleep Paralysis Companion is a nonmedical wellness tool. It does not diagnose,
detect, monitor, predict, prevent, or treat sleep paralysis and is not an
emergency service. The app responds only when you choose an action or enter
information.

### Information kept on your iPhone

The app may store:

- local profile and settings information;
- bedtime-alarm choices and the last known system scheduling state;
- optional check-ins you choose to submit, including the reported night,
  occurrence, optional perceived intensity, optional present state, and
  optional private note;
- downloaded content and its integrity/cache state;
- pending synchronization operations; and
- verified StoreKit product and entitlement presentation state.

Guest use does not require an account. Guest data stays on the device unless
you explicitly create or sign in to an account and enable synchronization, or
you export data to a destination you choose.

### Optional account and synchronization

If you enable synchronization, Supabase provides authentication, database, API,
and storage services in the configured `[SUPABASE REGION]` region. Account
options are Sign in with Apple and Sign in with Google. Email/password,
passwordless email, phone, and OTP login are not offered.

The app may synchronize the approved profile mapping, settings, alarm
preference, submitted check-ins, revisions, conflicts, and deletion tombstones.
It does not remotely schedule an alarm on another device.

Authentication tokens are kept in the iOS Keychain. Full tokens, email
one-time codes, private notes, and check-in answers are not placed in
diagnostics or notification text.

### Purchases

Apple processes monthly, annual, trial, and lifetime In-App Purchases through
StoreKit. RevenueCat processes pseudonymous product, transaction, entitlement,
renewal, and expiration state needed to provide Premium access and purchase
support. Billing Grace Period is disabled. We do not receive your payment-card
details, and RevenueCat is not given check-ins, private notes, alarm times, or
audio-listening history.

The alarm and privacy, support, export, deletion, restore, and purchase-
management utilities remain available without Premium. Deleting a Sleep
Paralysis Companion account does not cancel an Apple subscription. Subscription
management and refund requests are handled through Apple.

### Information the app does not collect in Phase 1

The app does not request microphone access and does not record, upload, or
analyze your voice or overnight audio. It does not use HealthKit, location,
contacts, photos, camera, advertising identifiers, cross-app tracking, or
behavioral advertising. It does not generate AI sleep reports, risk scores,
diagnoses, or episode detection.

Operational diagnostics are off unless this policy and the app are updated
after a separate provider, purpose, event allowlist, retention period, and
consent/legal review are approved.

### Why information is used

Information is used only to:

- provide the alarm and user-initiated app features;
- save and display information you choose to enter;
- synchronize approved records when you enable account sync;
- process data export and deletion;
- verify StoreKit access; and
- secure, operate, and troubleshoot the service using approved, minimized
  operational information.

The app does not sell personal information or use check-ins, notes, alarm
times, or content use for advertising or marketing audiences.

### Retention

- Local profile/settings remain until you delete local app data.
- Alarm intent remains until you remove the alarm or delete local data.
- Submitted check-ins remain until you delete an entry, local data, or the
  linked account.
- Local drafts are deleted seven days after last edit.
- Successful synchronization-operation metadata is deleted after seven days;
  unresolved failures are retained until resolved or for at most 30 days.
- Acknowledged deletion tombstones are retained for 30 days to prevent deleted
  information from returning.
- Temporary exports are removed after completion/cancel or within 24 hours
  after an interrupted export.
- A minimal account-deletion completion record with no content or direct
  account identifier is retained for 30 days, unless a documented legal hold
  requires otherwise.

Downloaded content follows the cache/removal rules shown in the app. Apple
controls transaction-record retention under its policies.

### Your controls

The app provides controls to:

- view and edit information you submitted;
- export the documented local and synchronized data;
- delete an individual entry;
- delete all local app data;
- sign out and choose whether to keep an account-bound protected local copy;
- initiate complete account deletion in the app; and
- restore purchases or open Apple's subscription-management and refund routes.

Account deletion hides data immediately in the app and completes the remote
workflow within the disclosed period. A failure remains visible and retryable;
support contact is not the only deletion route.

### Security

The design uses iOS Data Protection for local files, Keychain for tokens, TLS
for network transport, environment-separated Supabase projects, and
account-owner Row Level Security. These are design commitments; publication
requires verification against the implemented app, configured Supabase
project, built binary, network traffic, and deletion tests.

No service can promise absolute security. Contact `[PRIVACY EMAIL]` if you
believe your account or information is at risk.

### Children and territories

Sleep Paralysis Companion is intended for people aged 13 or older in the
United States. The parental-consent rule and jurisdiction-specific rights
remain `[LEGAL REVIEW REQUIRED]`. Do not reuse the rejected template's age or
state-law statements without confirming that they apply to the provider,
audience, data, and launch territory.

### Changes

Material changes will be dated and communicated through the app or another
appropriate channel. Renewed consent will be requested when required for a new
optional collection or processing purpose.

### Contact

Sleep Paralysis Companion  
`[MAILING ADDRESS]`  
`[PRIVACY EMAIL]`

## Publication checklist

- provider name verified as a legal contracting entity; mailing address,
  monitored email, publication date, and Supabase region completed;
- age 13+ and United States distribution scope legally reviewed;
- actual Supabase/Auth/processor configuration reconciled;
- App Store privacy nutrition label reconciled;
- App binary/permissions/SDK/network observation matches this policy;
- export, local deletion, account deletion, token revocation, and retention
  tests pass;
- StoreKit products and account-deletion/subscription wording match;
- owner and any required independent legal review approve the exact version;
  and
- public HTTPS URL is available, stable, readable, and linked in-app and in
  App Store Connect.
