# Partner call scope addendum

**Owner-directed scope update: 15 August 2026**

This addendum supersedes the earlier Phase 1 exclusion of partner calling for
this narrowly defined capability only. It does not reopen partner voice,
automatic episode detection, monitoring, or emergency response.

## Approved behavior

- The person may optionally enter one partner name and phone number.
- The contact is stored in the protected local database only.
- The contact is not included in Supabase synchronization, structured export,
  diagnostics, or analytics.
- From the manually opened grounding screen, the person explicitly taps
  “Call Partner.” The app opens the iOS `tel:` flow with the saved number.
- Clearing the contact fields removes the local record.

## Explicit boundaries

- The app never detects an episode or dials automatically.
- The app does not request Contacts permission or read the address book.
- The app does not contact emergency services.
- The partner-call preference remains a user preference/check-in value; it is
  not evidence that a call occurred.

Physical-device verification is still required to confirm the iOS Phone flow
on the supported iPhone and to confirm behavior when no phone service is
available.
