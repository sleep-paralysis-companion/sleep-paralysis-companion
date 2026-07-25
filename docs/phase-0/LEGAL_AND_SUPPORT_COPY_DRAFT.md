# Phase 1 Legal, Wellness, and Support Copy Draft

**Document ID:** `LEGAL-P1-003`  
**Product:** Sleep Paralysis Companion  
**Owner:** Satyam Shree  
**Status:** Product-accurate draft; **NOT APPROVED FOR PUBLICATION**  
**Updated:** 25 July 2026

## 1. Purpose and publication gate

This document supplies the companion copy required beside
[`PRIV-P1-002`](./PRIVACY_POLICY_PHASE_1_DRAFT.md). It is controlled by the
canonical product, data, claims, and commerce contracts. It is not legal advice
and does not become public merely because it exists in the repository.

Before publication, Satyam Shree must provide and approve:

- verification that `Sleep Paralysis Companion` is the exact legal contracting
  entity, plus its mailing address;
- support and privacy email addresses;
- governing law and venue;
- the configured Supabase processing region;
- final Apple subscription/product localizations;
- final content licenses and third-party notices; and
- stable privacy, terms, support, and account-deletion URLs.

The published pages and in-app copy must be versioned and reconciled against
the shipped binary, observed network behavior, App Store privacy answers, and
backend retention/deletion tests.

## 2. Wellness notice

### Full notice

> Sleep Paralysis Companion is a general wellness and self-management tool. It
> is not a medical device and does not diagnose, detect, predict, prevent, or
> treat sleep paralysis or any health condition. It does not monitor you while
> you sleep or contact another person automatically. The alarm, grounding
> content, and private check-in are optional tools and may not work in every
> device, network, power, notification, Focus, or audio state. Do not rely on
> the app for emergencies or personal safety. If you have concerns about your
> health, seek advice from a qualified healthcare professional. If you believe
> you are in immediate danger, contact local emergency services.

### Compact first-run version

> A general wellness tool—not medical care or emergency monitoring. The app
> does not detect episodes or listen while you sleep.

Action labels:

- `Continue`
- `Read full wellness notice`

Acceptance rule: continuing acknowledges display of the notice; it is not
medical consent and must not be described as one.

## 3. Alarm and grounding copy

### Alarm setup

Title: `Bedtime alarm`

Body:

> Set an optional reminder using the device's alarm capability. Availability
> and presentation depend on your iPhone settings and system state.

Permission purpose:

> Sleep Paralysis Companion uses alarm access only to schedule and manage the
> bedtime alarms you create.

Neutral system title: `Bedtime reminder`  
Primary action: `Open`  
Secondary action: `Stop`

### Manual grounding entry

Title: `Grounding`

Body:

> Open a short grounding exercise when you choose. Sleep Paralysis Companion
> does not detect when an episode starts.

Never use `Emergency`, `Rescue`, `Keep me safe`, `Detection active`,
`Episode detected`, `Prevents episodes`, or equivalent copy.

## 4. Premium and purchase copy

### Access summary

> The bedtime alarm is always free. Grounding, check-ins, history, optional
> sync, and other product features require Premium.

For an eligible subscription product:

> 3 days free, then **[localized StoreKit price]/[period]** until canceled.

For an ineligible subscription product:

> **[localized StoreKit price]/[period]**, automatically renews until canceled.

For the non-consumable:

> **Lifetime — [localized StoreKit price]**  
> One-time purchase for Premium access on the Apple Account used to buy it.

Required adjacent actions:

- `Continue`
- `Restore purchases`
- `Manage subscription`
- `Privacy`
- `Terms`
- `Not now`

Required disclosure:

> Payment is charged to your Apple Account. Subscriptions renew automatically
> unless canceled through Apple. Trial eligibility, prices, billing, refunds,
> and renewal status are managed by Apple. Deleting your Sleep Paralysis
> Companion account does not cancel an Apple subscription.

Do not hardcode the numeric price in customer-facing runtime copy. Do not show
trial language unless StoreKit reports the customer as eligible. Do not imply
that Premium is required for safety.

## 5. Account, export, and deletion copy

### Optional account

Title: `Sync across devices`

Body:

> An account is optional. Sign in with Apple, Google, or an email code to sync
> approved settings and entries through Supabase. You can continue on this
> iPhone without an account.

### Export

Title: `Export my data`

Body:

> Create a portable file containing the local and, when signed in and
> reachable, synced data associated with your account. The file may contain
> sensitive wellness notes. Choose where you share or store it.

### Delete local data

Title: `Delete data from this iPhone?`

Body:

> This removes local profile settings, check-ins, notes, drafts, cached
> downloads, and app-created alarm state from this iPhone. It does not cancel
> an Apple subscription or, when you are signed in, delete your remote account.

Actions: `Cancel` / `Delete local data`

### Delete account

Title: `Delete account?`

Body:

> This permanently deletes your Sleep Paralysis Companion account and
> non-legally-retained synced data after reauthentication. It also signs out
> connected sessions and removes local account data from this iPhone. Deleting
> the account does not cancel an Apple subscription; manage billing separately
> through Apple.

Actions: `Cancel` / `Continue to reauthenticate`

Completion:

> Account deletion requested. Your account is no longer available. We will
> complete deletion within the period stated in the Privacy Policy, except for
> information we are legally required to retain.

The final completion period must match the approved backend implementation and
published policy.

## 6. Support page

Title: `Support`

Body:

> Need help with the app, an alarm, access, sync, export, or deletion? Contact
> **[SUPPORT EMAIL]**. Do not include private check-in text, health details,
> passwords, email codes, or purchase credentials in your message.

Include:

- app version and build;
- supported iOS version range;
- privacy policy, terms, and wellness-notice links;
- `Restore purchases`, `Manage subscription`, and Apple's refund-help route;
- account-deletion instructions;
- accessibility contact path;
- expected response-time statement, once operationally approved; and
- service-status link only if a real maintained status page exists.

Support diagnostics remain opt-in and contain no check-in content, note text,
alarm time, listening history, account token, or advertising identifier.

## 7. Terms of Use drafting contract

The final Terms of Use must be reviewed for the selected jurisdictions and
contain, at minimum:

1. legal provider identity, effective date, acceptance, minimum age, and
   territorial availability;
2. a limited personal, revocable, non-transferable license to use the app;
3. the general-wellness boundary and no medical, detection, emergency, or
   availability guarantee;
4. the optional-account model, credential responsibilities, identity linking,
   suspension, and deletion;
5. user ownership/responsibility for private notes and a limited license only
   to process them to provide sync/export/deletion;
6. Apple-managed monthly, annual, introductory-offer, renewal, cancellation,
   refund, grace, restoration, and Lifetime purchase terms;
7. content/IP ownership, final audio licenses, and prohibited misuse;
8. service changes, interruption, termination, and data handling on closure;
9. warranty disclaimer and legally permissible liability limitations that do
   not waive non-waivable consumer rights;
10. governing law, venue/dispute terms, severability, assignment, changes,
    notices, and contact details; and
11. Apple-required end-user terms or a separately approved custom EULA.

Recorded owner inputs:

- provider named by owner: `Sleep Paralysis Companion` (legal registration
  status still requires verification);
- effective date: the date the approved policy is first published;
- minimum age: `13`;
- supported territory: `United States`.

Placeholders that still require owner/legal input:

- `[MAILING ADDRESS]`
- `[SUPPORT EMAIL]`
- `[GOVERNING LAW]`
- `[VENUE / DISPUTE TERMS]`

## 8. Approval record

| Role | Name | Decision/date | Evidence |
|---|---|---|---|
| Product/Claims | Satyam Shree | `DRAFTED — OWNER REVIEW PENDING` | Canonical scope and claims matrix |
| Privacy/Legal | Satyam Shree | `PENDING FACTUAL VALUES AND LEGAL REVIEW` | `PRIV-P1-002`, this draft |
| Commerce | Satyam Shree | `PRODUCT MODEL APPROVED 25 JULY 2026` | `COM-P1-001` |
| Accessibility/QA | Satyam Shree | `PENDING RUNTIME AND COPY EVIDENCE` | Device/AT matrix |
