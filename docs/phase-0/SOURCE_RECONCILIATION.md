# Source Reconciliation

**Status:** Evidence baseline  
**Reconciled:** 23 July 2026  
**Clarified:** 25 July 2026  
**Purpose:** Establish source authority and prevent older discovery material
from silently becoming Phase 1 scope.

## Source register

| ID | Source and revision evidence | Use | Result |
|---|---|---|---|
| `S-P0` | Phase 0 session prompt supplied for this work, 23 July 2026 | Adopted product direction and Gate 0 contract | Controlling |
| `S-EXEC` | [Phase 1 execution plan](../PHASE_1_EXECUTION_PLAN.md), repository version inspected 23 July 2026 | Internal execution authority and phase boundaries | Controlling |
| `S-IOS` | [iOS 2026 best practices](../IOS_2026_BEST_PRACTICES.md), inspected 23 July 2026 | Platform, privacy, accessibility, test, and release standard | Mandatory |
| `S-SWIFT` | [Swift/SwiftUI best practices](../SWIFT_SWIFTUI_BEST_PRACTICES.md), inspected 23 July 2026 | Language, architecture, concurrency, state, and test standard | Mandatory |
| `S-PRD` | [Master PRD - SP](https://docs.google.com/document/d/1ccudhMzM18k5dMel4uQNpK80yihWJNmJE5N-kXTzDZA/edit), native Google Doc, last-modified date shown as 18 July 2026; all 24 tabs read on 23 July 2026 | Research, proposed flows, naming, pricing, privacy drafts, and later-phase ideas | Discovery only |
| `S-PRD-P1-COPY` | [Master PRD - SP — Phase 1 Userflow](https://docs.google.com/document/d/1ccudhMzM18k5dMel4uQNpK80yihWJNmJE5N-kXTzDZA/edit?tab=t.ptx1blwstnqb), tab `t.ptx1blwstnqb`; reread 24 July 2026 | User-designated exact wording source | Authoritative for exact strings that remain inside approved scope and claims rules; conflicting strings require disposition rather than silent rewriting |
| `S-MEETING` | [Meeting started 2026/07/15 17:57 IST - Notes by Gemini](https://docs.google.com/document/d/160QELWcVYsm0YyATZXlrox7fE7CKg5VdtzHxmSzisvI/edit), Notes tab `t.n66f881tpwcq`, Transcript tab `t.gblbtka0p3uk`; both read in full on 23 July 2026 | Discovery decisions and historical commercial/delivery discussion | Discovery only |
| `S-TECH` | `SP_App_Tech_Stack_and_Phase_1_Plan_Client.docx`, prepared 5 July 2026 | Older architecture and delivery recommendation | Discovery only |
| `S-TECH-ALT` | `SP_App_Tech_Stack_and_Phase_1_Plan.docx` and `SP_App_Tech_Stack_and_Phase_1_Plan_scrubbed.docx` | Alternate packages of the same plan | Discovery only |
| `S-USERFLOW-2026-05-16` | `Sleep Paralysis Companion — User Flow`, Phase 1 v1.0 draft, attributed to Shraddha Rakshe, last-updated text 16 May 2026; attachment SHA-256 `9CBCE9C1D76BA39E7FCB98A53B16B88A373FBE79FEED897C26554125AE76121F`; inspected 25 July 2026 | Discovery flow and historical screen/copy evidence | Superseded where it requires signup, profiling, voice recording, automatic audio, partner calling, extra outcome questions, or excluded claims |
| `S-PRIVACY-PDF-2026-05-12` | `Privacy_Policy.pdf`, 16 pages, effective-date text 12 May 2026; SHA-256 `FA37195B6C887C5F3D787C74DD9F369B4B83B6320C11E5D703881E6F93652C7F`; [review](./PRIVACY_POLICY_ASSET_REVIEW.md) `PRIV-P0-001` | Discovery privacy template | **Not approved for publication:** placeholders plus excluded microphone, voice, detection, AI, questionnaire, phone OTP, and cloud-audio claims |
| `S-FIGMA` | [SP Figma file](https://www.figma.com/design/vjbC6so9SSpuRpJPsYuXEw/SP?node-id=299-358) with supplied file key `vjbC6so9SSpuRpJPsYuXEw`; user identifies intended account as `main.satyamshee@gmail.com` and reports editor access granted 25 July 2026; [read-only audit](./FIGMA_READ_ONLY_AUDIT.md) `FIGMA-P0-001` | Strictly read-only discovery reference | File/page identity and three canvas renders confirmed. Satyam Shree approved superseding the legacy visual source with `SPEC-P1-001`; unavailable hierarchy/prototype evidence no longer blocks the controlling specification. |

## Apple verification register

All entries below were checked against official Apple sources on
**23 July 2026**. They are requirements or platform facts, not Paralux
feasibility evidence.

| ID | Official source | Verified constraint |
|---|---|---|
| `S-APPLE-SDK` | [Upcoming requirements](https://developer.apple.com/news/upcoming-requirements/) | Since 28 April 2026, App Store Connect uploads must use Xcode 26 or later and the iOS/iPadOS 26 SDK or later. The exact stable accepted toolchain must be rechecked at archive time. |
| `S-APPLE-ARG` | [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/) | Submissions must be complete and tested on-device; login apps need review access; premium digital functionality uses In-App Purchase; privacy policy and honest metadata are required; account creation implies in-app deletion. |
| `S-APPLE-ALARM` | [AlarmKit](https://developer.apple.com/documentation/AlarmKit) and [WWDC25 AlarmKit session](https://developer.apple.com/videos/play/wwdc2025/230/) | AlarmKit is an iOS/iPadOS 26 framework for prominent alarms/timers, including Lock Screen surfaces. People opt in per app. Actual Paralux behavior must be proven physically. |
| `S-APPLE-ALARM-KEY` | [NSAlarmKitUsageDescription](https://developer.apple.com/documentation/BundleResources/Information-Property-List/NSAlarmKitUsageDescription) | A clear nonempty purpose string is required; without it the app cannot schedule AlarmKit alarms. |
| `S-APPLE-INTENT` | [Creating your first App Intent](https://developer.apple.com/documentation/appintents/creating-your-first-app-intent) | App Intents can expose approved actions to system experiences; execution context, privacy, authentication, idempotency, and lifecycle still require Paralux-specific device tests. |
| `S-APPLE-AUDIO` | [Handling audio interruptions](https://developer.apple.com/documentation/AVFAudio/handling-audio-interruptions) | Audio-session interruption and route behavior must follow observed system events; the exact resume/background policy remains a product and physical-device decision. |
| `S-APPLE-DELETE` | [Offering account deletion in your app](https://developer.apple.com/support/offering-account-deletion-in-your-app/) | An app that supports account creation must let every user initiate full account deletion in-app, explain timing and subscription consequences, and revoke Sign in with Apple tokens when applicable. |
| `S-APPLE-STOREKIT` | [StoreKit current entitlements](https://developer.apple.com/documentation/storekit/transaction/currententitlements) and [billing grace period](https://developer.apple.com/help/app-store-connect/manage-subscriptions/enable-billing-grace-period-for-auto-renewable-subscriptions) | Apple transaction and renewal state remains purchase authority. The owner selected Billing Grace Period off; RevenueCat must not add custom grace. |
| `S-APPLE-IAP-TYPES` | [In-App Purchase types](https://developer.apple.com/help/app-store-connect/reference/in-app-purchases-and-subscriptions/in-app-purchase-types) | Monthly/annual access uses auto-renewable subscriptions; a lifetime unlock is a non-consumable that does not expire. |
| `S-APPLE-INTRO` | [Introductory offers](https://developer.apple.com/help/app-store-connect/manage-subscriptions/set-up-introductory-offers-for-auto-renewable-subscriptions) | Apple supports a three-day free introductory offer; each customer can redeem one introductory offer per subscription group. |
| `S-APPLE-GRACE` | [Billing Grace Period](https://developer.apple.com/help/app-store-connect/manage-subscriptions/enable-billing-grace-period-for-auto-renewable-subscriptions/) | Apple offers optional grace configurations. Phase 1 deliberately disables Billing Grace Period and cuts premium access when the verified entitlement becomes inactive. |
| `S-APPLE-BANK` | [Enter banking information](https://developer.apple.com/help/app-store-connect/manage-banking-information/enter-banking-information) and [receiving payments](https://developer.apple.com/help/app-store-connect/getting-paid/overview-of-receiving-payments/) | Developer payout banking, agreements, tax, and payments are managed in App Store Connect, not RevenueCat. |
| `S-RC-ROLE` | [RevenueCat developer store payments](https://www.revenuecat.com/docs/platform-resources/developer-store-payments) | RevenueCat does not process or receive App Store customer payments; Apple pays the developer. |
| `S-RC-SETUP` | [RevenueCat projects](https://www.revenuecat.com/docs/projects/overview), [collaborators](https://www.revenuecat.com/docs/projects/collaborators), and [authentication](https://www.revenuecat.com/docs/projects/authentication) | Use project collaborators instead of shared credentials, keep secret keys server-side, and expose only the correct public SDK key in the app. |
| `S-RC-ENTITLEMENT` | [RevenueCat entitlements](https://www.revenuecat.com/docs/getting-started/entitlements) | A single `premium_access` entitlement maps the approved Apple products to application access. |
| `S-APPLE-PRIVACY` | [Third-party SDK requirements](https://developer.apple.com/support/third-party-SDK-requirements/) and [privacy manifests](https://developer.apple.com/documentation/bundleresources/adding-a-privacy-manifest-to-your-app-or-third-party-sdk) | Required-reason APIs, privacy manifests, listed SDK signatures, and declared data use must match the shipped binary. |

## Extraction and access notes

### Technical-plan documents

Structured DOCX extraction produced identical body text for all three
technical-plan files:

- extracted-body SHA-256:
  `62c80a9b48d28ade655933207f780a9ad9c632ad7f28b502df08a0e552024c55`;
- body length: 23,178 characters;
- package hashes differ for one file because package metadata differs.

LibreOffice was not available in the current Windows workspace, so the DOCX
files could not be rendered for page-level visual inspection. Phase 0 uses
their extracted text only and makes no statement about their visual fidelity.

### PRD

All 24 native tabs were read, including Phase 1 flow, problem statement,
privacy drafts, audio ideas, later phases, pricing, names, and go-to-market.
The PRD is not missing; the earlier reference to `Master PRD - SP.pdf` was a
stale filename. The native Google Doc linked above is the reviewed source.

On 24 July 2026 the user designated the `Phase 1 Userflow` tab
`t.ptx1blwstnqb` as the exact-wording source. On 28 July the user superseded
its account direction with Apple and Google only. Exact source wording is
preserved below rather than reconstructed:

| Source area | Exact source text | Phase 1 disposition |
|---|---|---|
| Splash | “Understand your nights.” | `COPY REVIEW`: may imply analysis; do not ship until Claims approves |
| Account | “Apple ID or email” | `SUPERSEDED`: optional sync account offers only Apple and Google; guest use remains available |
| Manual action | “I just had an episode” | `ADOPTED COPY DIRECTION`: a manual self-report, subject to locked-surface privacy and physical feasibility |
| Post-action statement | “You’re awake. You’re safe.” | `PROHIBITED AS WRITTEN`: the app cannot verify either fact; user must supply revised exact wording or approve the neutral scoped alternative |
| Occurrence | “Did you have an episode last night?” — “Yes / No” | `ADOPTED EXACT SOURCE COPY` for the optional check-in |
| Present state | “How are you feeling now?” — “I’m fine now” / “Still a bit shaken” / “Exhausted” | `ADOPTED EXACT SOURCE COPY`, subject to accessibility/localization review |
| Intensity summary | “Q2 — Intensity” — “Mild / Moderate / Severe / Extreme” | `PARTIAL`: exact option words exist, but the tab does not contain one unambiguous full question sentence and elsewhere uses Q2 for a different question |
| App benefit question | “Did Paralux help?” / “How did you feel after using SPC?” | `OUT OF CURRENT FOUR-FIELD CONTRACT`: would add outcome/benefit data and needs an explicit scope/data decision |
| Partner/voice/call | “Do you have someone whose voice calms you down?”, “Call Partner”, “Hear Partner’s Voice” | `EXCLUDED`: conflicts with the no-voice/no-partner-call Phase 1 boundary |
| Audio assertions | “All audio is originally produced” and “all audio downloads and plays offline” | `PLACEHOLDER GOAL, NOT CURRENT FACT`: user will provide assets later |

The tab contains both a three-question summary and a longer, different morning
question set. It also contains voice recording, partner calling, auto-play,
and profile-routing material that conflicts with the adopted Phase 1 boundary.
Designating the tab as exact-wording authority does not silently reopen those
excluded capabilities or make contradictory strings simultaneously canonical.

### Meeting record

Both the generated notes and the 52:51 transcript were read. The transcript
confirms that SQLite and Supabase were discussed, the locked/manual entry needs
early feasibility testing, and documentation was expected before
implementation. It also contains historical voice-recording, external-payment,
delivery-date, support, and maintenance discussions that are not automatically
Phase 1 requirements.

### Figma

Metadata requests on 23 and 24 July 2026 failed with:

> You don't have edit access to this file. The file owner can share it with
> you and make you an editor.

Figma debug references:

- 23 July: `1da2c4c3-3fe3-43ac-b925-1bd945602e53`
- 24 July: `d07b742e-da32-4ded-bc59-6b6e987963a7`

Initial 25 July calls returned MCP error `-32603: Internal error`. A later
strictly read-only Plugin API identity query succeeded and returned:

- `figma.fileKey = vjbC6so9SSpuRpJPsYuXEw`;
- `299:358` = page `Components`;
- `0:1` = page `Screens`; and
- `5:2` = page `Mascot`.

The screenshot endpoint then rendered all three page canvases. The `Screens`
canvas exposed enough visible copy and flow concepts to confirm material
conflicts: account-first onboarding, a sleep-paralysis questionnaire/profile,
risk scoring/analytics, Guardian Mode, overnight listening, loved-one voice
recording, per-user trial/paywall concepts, and check-in wording/options that
do not match the approved exact-copy contract. Those concepts remain excluded,
prohibited, or superseded; Figma does not reopen them.

The successful access remains partial. `get_metadata` and read-only Plugin API
page loads for `Screens` returned HTTP `504`. Component-property inspection
failed because a component set reports existing errors. Design-context and
variable-definition calls on `299:358` reported that nothing renderable was
selected because the node is a page/canvas. Child node IDs, components,
variables, exact text properties, and prototype reactions therefore remain
unavailable. The full evidence, debug UUIDs, canvas dimensions, stable-ID
mapping, and missing-state inventory are recorded in
[FIGMA-P0-001](./FIGMA_READ_ONLY_AUDIT.md).

No Figma mutation occurred. Every app-state/Figma column remains `Pending`
until a child-node and reaction map is available. The MCP request schema does
not expose an email/account selector, and `figma.currentUser` is unsupported,
so the connected email cannot be independently verified through the connector.

The user explicitly prohibits design mutations. Even if Figma requires editor
permission for MCP inspection, that permission authorizes only read operations:
metadata, screenshots, design context, node/state/copy inventory, prototype
inspection, and mapping into repository documentation. Do not create, edit,
move, rename, delete, annotate, publish, or otherwise mutate any Figma node,
component, variable, prototype, comment, or file setting.

## Reconciled source conflicts

| ID | Lower-authority proposal | Controlling Phase 1 result |
|---|---|---|
| `SC-001` | Sign-up-first onboarding and required account | Guest/local-first; account only when the user chooses sync |
| `SC-002` | Several profiles or partner-oriented setup | One local profile |
| `SC-003` | User/partner voice recording and social sharing | Excluded; no microphone permission |
| `SC-004` | Automatic/continuous microphone classification | Excluded; all episode input is manual |
| `SC-005` | Risk score renamed as “wellness index” | Excluded regardless of label |
| `SC-006` | Diagnostic quiz, trigger prediction, prevention, treatment, or clinician prompts | Excluded; nonmedical wellness only |
| `SC-007` | HealthKit, wearables, Watch, Android, AI, community, telehealth, EHR, or B2B portal | Excluded from Phase 1 |
| `SC-008` | Ambiguous “three-night” or seven-day trial variants | Replaced through change control by one StoreKit three-day introductory offer for eligible monthly/annual customers |
| `SC-009` | Conflicting product and price variants | Approved US model: monthly USD 8.99, annual USD 59.99, lifetime non-consumable USD 149.99; alarm always free; all other features premium |
| `SC-010` | Polar or other external payment for in-app digital functionality | Apple In-App Purchase controls the transaction; RevenueCat orchestrates the resulting app entitlement |
| `SC-011` | AWS as preferred Phase 1 backend | Supabase is the account/sync backend |
| `SC-012` | Remote APNs foundation | Not included unless a separately approved user need requires remote push |
| `SC-013` | “HIPAA-ready,” “protected sleep,” “peaceful sleep,” “knows,” or guaranteed-result language | Prohibited without a future legal/product scope change; Phase 1 makes no such claim |
| `SC-014` | “You’re awake. You’re safe.” | Not approved: the app cannot verify either fact. Use neutral grounding copy. |
| `SC-015` | Eight-week or specific August release commitment | Retired historical estimate; re-estimate only after Gate 0 |

## Discovery material retained without adoption

The following remain useful research context but have no Phase 1 authority:

- competitor privacy-policy excerpts and YouTube references;
- patent, domain, and name lists;
- Phase 2/3 detection, health, AI, wearable, community, and clinician concepts;
- commercial maintenance figures and milestone percentages;
- copied Apple/privacy prose that has not been reviewed by counsel; and
- proposed statistics, benefit percentages, or user testimonials without an
  approved evidence package.

No source may reopen an excluded capability without a decision record that
updates requirements, claims, fields, permissions, security, offline behavior,
tests, disclosures, schedule, and Gate approval.
