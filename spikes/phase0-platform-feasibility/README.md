# Phase 0 Platform Feasibility Spike

**DISPOSABLE - NOT FOR SHIPPING**

This isolated iOS 26 project exists only to collect `FEAS-P1-001` evidence. It
does not import production modules, connect to Supabase, collect personal data,
use a microphone, implement check-ins, or establish production architecture.

## What it exercises

- AlarmKit authorization, scheduling, reconciliation, cancellation, and a
  neutral custom `Open` action;
- locked, terminated, offline, Silent/Focus, restart, and time-change behavior;
- an explicit low-volume synthetic local tone for lock/background and
  interruption/route observations;
- a silent/text alternative and a clear Stop action; and
- StoreKit product loading, purchase-sheet, verified entitlement, restore, and
  transaction-state observations for the disposable products; and
- privacy-safe JSONL evidence events that the tester can export.

The Lock Screen title is deliberately neutral: `Bedtime reminder`. The custom
action is `Open`. It makes no episode, safety, detection, or medical claim.

## Hosted build prerequisites

1. Register bundle ID `com.satyamshree.spc.phase0spike`.
2. Create an App Store Connect app record for the disposable spike.
3. Under that record, configure these disposable products exactly:
   - `com.satyamshree.spc.phase0spike.premium.monthly` - monthly
     auto-renewable, US price USD 8.99, three-day introductory free trial;
   - `com.satyamshree.spc.phase0spike.premium.annual` - annual
     auto-renewable, US price USD 59.99, same subscription group and offer;
   - `com.satyamshree.spc.phase0spike.premium.lifetime` - non-consumable,
     US price USD 149.99;
   - Family Sharing off; Billing Grace Period 16 days, paid-to-paid renewals
     only.
4. In Codemagic, create an App Store Connect API integration named
   `codemagic` with App Manager access.
5. Generate/fetch an Apple Distribution certificate and matching App Store
   provisioning profile in Codemagic.
6. Add this repository to Codemagic and run workflow
   `phase0-platform-feasibility`.
7. Add Satyam Shree as an internal TestFlight tester and install the build on
   the confirmed iOS 26 iPhone.

The monthly and annual products must be in one subscription group. Apple
controls introductory-offer eligibility; the app does not create a custom
trial clock.


Never commit `.p8`, certificates, provisioning profiles, Apple credentials, or
Codemagic secrets. The root `codemagic.yaml` is intentionally limited to this
disposable project.

## Evidence protocol

Before each run, record device model/hardware identifier, OS version/build,
locale, time zone, appearance, accessibility settings, AlarmKit authorization,
network, Focus, silent state, and app lifecycle. Run the matching test IDs in
`docs/phase-0/PLATFORM_FEASIBILITY_REPORT.md`.

Export the app's `phase0-evidence.jsonl` file and pair it with:

- expected versus observed notes;
- a second-camera recording for Lock Screen/system behavior;
- the signed build number and spike commit;
- pass/fail/unsupported classification;
- reproduction count; and
- tester/reviewer name.

The in-app log records actions, not private content. A passing spike must still
be reviewed and entered into the Phase 0 evidence table before Gate 0 changes.
