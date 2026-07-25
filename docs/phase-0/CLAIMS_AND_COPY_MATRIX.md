# Claims and Copy Matrix

**Matrix ID:** `CLAIMS-P1-001`  
**Status:** Product/Claims direction approved by Satyam Shree; replacement
privacy/legal wording and independent release evidence pending  
**Updated:** 25 July 2026

## 1. Claims boundary

Sleep Paralysis Companion may describe what a person can manually do in the app. It may not state
or imply that the app knows the person's physiological state, recognizes sleep
paralysis, changes clinical risk, prevents an episode, treats a condition,
protects sleep, verifies safety, replaces care, or guarantees a result.

Renaming a prohibited claim does not make it acceptable. “Wellness index,”
“readiness,” “pattern,” “insight,” “guardian,” “protected,” or “smart” copy is
prohibited when the underlying behavior remains detection, prediction, risk
classification, causal inference, or treatment.

### Status

| Status | Meaning |
|---|---|
| `ALLOWED-PATTERN` | Factual pattern permitted after normal copy/localization review |
| `PROPOSED` | Exact launch wording awaiting named approval |
| `CONDITIONAL` | Allowed only after linked physical/content evidence is true for that context |
| `PROHIBITED` | Must not appear in UI, extensions, notifications, audio, metadata, screenshots, support, sales, or analytics labels |

### Figma canvas reconciliation

The read-only [Figma audit](./FIGMA_READ_ONLY_AUDIT.md) confirms visible
account-first/profile promises, `SP Confirmed`/risk/analytics language,
Guardian Mode/overnight listening/loved-one voice concepts, a legacy
trial/paywall model, and morning-check-in wording/options that conflict with this
matrix. Those canvas concepts are discovery evidence only. They remain
prohibited, excluded, or superseded under the `CLM-*` records below and do not
become approved because they are present in Figma.

Exact Figma text-layer IDs remain unavailable because page hierarchy calls
return HTTP `504`. All visual copy mappings therefore remain `Pending` until a
revisioned child-node/text export or working read-only hierarchy response is
available.

## 2. Required product-boundary copy

| ID | Surface | Proposed copy | Required behavior | Status |
|---|---|---|---|---|
| `CLM-001` | First-use scope screen | “Sleep Paralysis Companion is a nonmedical wellness tool. It does not diagnose, detect, monitor, predict, prevent, or treat sleep paralysis, and it is not an emergency service.” | Visible before Home on first use and reachable later | `OWNER APPROVED` |
| `CLM-002` | Scope screen | “The app responds only when you choose an action or enter information.” | No background/inferred episode behavior exists | `OWNER APPROVED` |
| `CLM-003` | Check-in intro | “Entries reflect what you choose to report. Sleep Paralysis Companion does not verify or interpret them.” | No derived health interpretation | `OWNER APPROVED` |
| `CLM-004` | History intro | “History summarizes only the entries you submitted.” | All values reconcile to user-entered rows | `OWNER APPROVED` |
| `CLM-005` | Help | “If you need medical advice, contact a qualified healthcare professional. Sleep Paralysis Companion cannot evaluate your situation.” | General, non-personalized statement; jurisdictional wording reviewed | `OWNER APPROVED` |
| `CLM-006` | Help | “Sleep Paralysis Companion is not emergency support.” | No emergency monitoring/contact promise; any resource list requires Legal/Safety localization | `OWNER APPROVED` |

The notice is informational. It must not be framed as consent to collect health
data, a waiver of rights, or acceptance of a medical risk.

## 3. Allowed factual patterns

| ID | Context | Allowed pattern | Conditions |
|---|---|---|---|
| `CLM-010` | Store/home | “A private, nonmedical companion for preparation, grounding, and personal notes.” | “Private” is allowed only after privacy/network/storage audit confirms the documented data flows |
| `CLM-011` | Alarm | “Set a bedtime alarm.” | The screen displays actual scheduling/authorization state |
| `CLM-012` | Manual action | “Start grounding” or “Open grounding” | Action is manual and starts the documented flow |
| `CLM-013` | Grounding | “Choose audio, visual instructions, or silent mode.” | All listed modes exist and are accessible |
| `CLM-014` | Check-in | “Add an optional check-in.” | It is genuinely optional and no entry is inferred |
| `CLM-015` | History | “View the entries you submitted.” | No derived risk, cause, prediction, or treatment content |
| `CLM-016` | Sync | “Sync approved app data across your devices.” | Exact data list is shown before account creation and RLS/isolation evidence passes |
| `CLM-017` | Offline | “Bundled grounding content is available without an internet connection.” | Physical offline test passes for the named content and app state |
| `CLM-018` | Commerce | “3 days free, then [localized StoreKit price]/[period] until canceled.” | Show only when StoreKit confirms introductory-offer eligibility for the selected monthly/annual product |
| `CLM-019` | Commerce | “The alarm stays available without a subscription.” | Commercial access tests prove it in every entitlement/account/network state |
| `CLM-019A` | Commerce | “Lifetime - one-time purchase.” | Verified non-consumable product; never describe it as a subscription or trial |
| `CLM-020` | Data | “Export a copy of the app data listed here.” | Export format and field list match actual output |
| `CLM-021` | Data | “Delete this entry,” “Delete local app data,” or “Delete account” | Each label maps to the distinct lifecycle described before confirmation |
| `CLM-022` | Optional account | “Continue with Apple,” “Continue with Google,” and “Create account with email” | Guest use remains available; provider branding, email flow, account linking, recovery, and deletion behavior pass review |

“Private” never means anonymous, zero-data, encrypted end-to-end, medically
confidential, HIPAA-compliant, or invisible to processors unless each narrower
statement has separate verified evidence and legal approval.

## 4. Conditional platform and reliability statements

| ID | Candidate statement | Evidence required before use | Required qualification |
|---|---|---|---|
| `CLM-030` | “The alarm can sound in Silent mode or Focus.” | AlarmKit physical results on every supported device/OS and authorization state | Explain authorization and the exact unsupported/denied state |
| `CLM-031` | “Start grounding from the Lock Screen.” | Chosen App Intent/control/widget surface works in locked, terminated, offline, and authentication states | Name the actual surface and any unlock step |
| `CLM-032` | “Works offline.” | Per-feature offline matrix passes | Replace broad claim with exact functions available offline |
| `CLM-033` | “Your data syncs across devices.” | Conversion, RLS, conflicts, retries, deletion, sign-out, and reinstall pass | “When you create an account and enable sync”; list exclusions |
| `CLM-034` | “Your alarm is set.” | Reconciled system schedule exists | Otherwise use “Couldn’t schedule,” “Permission needed,” or “Checking” |
| `CLM-035` | “Download for offline use.” | Rights, manifest, integrity, atomic install, eviction, and playback pass | Show download state, size, and removal control |
| `CLM-036` | “Premium active until [date].” | Verified StoreKit transaction/renewal state | Use Apple's localized product/renewal facts; distinguish grace/expired/refunded |
| `CLM-037` | “Account deleted.” | Backend completion and local cleanup are confirmed | While pending, state the deadline and what remains |

The app must not generalize a passing test on one device, OS, locale, or
permission state into a universal claim.

## 5. Exact-source check-in copy

`S-PRD-P1-COPY` is the exact wording authority inside the approved four-field
scope. Satyam Shree approved the minimal completion below on 25 July 2026.

| ID | Element | Exact copy/options or source state | Guardrail |
|---|---|---|---|
| `CLM-040` | Entry date | “Night of” | Default to the previous local date before noon and current local date otherwise; editable; never a detected event time |
| `CLM-041` | Occurrence | “Did you have an episode last night?” → “Yes” / “No” | Manual self-report only; local-date and “last night” behavior must be explicit |
| `CLM-042` | Intensity | “How intense did it feel? (Optional)” → “Mild” / “Moderate” / “Severe” / “Extreme” | Subjective only; no clinical/computed score |
| `CLM-043` | Present state | “How are you feeling now?” → “I’m fine now” / “Still a bit shaken” / “Exhausted” | Present self-description only; do not label as recovery score or product outcome |
| `CLM-044` | Note | “Anything you'd like to remember? (Optional)” | 500 user-perceived-character limit; no prompt for diagnosis, trauma, medication, or contact data |
| `CLM-045` | Submit | “Save entry” | “Save” only after the data is durably local |
| `CLM-046` | Skip/exit | “Not now” | No shame, warning, streak loss, or repeated coercive prompt |

## 6. Proposed calm-state copy

| ID | Context | Proposed wording | Reason |
|---|---|---|---|
| `CLM-050` | Manual action | “I just had an episode” | Exact PRD self-report direction; use only on an intentional manual control and only where locked-surface privacy review accepts the disclosure |
| `CLM-051` | Grounding start | “Take a moment. Choose what feels helpful.” | Does not assert wakefulness, safety, or an outcome |
| `CLM-052` | Breathing/visual instruction | “If it feels comfortable, follow the pace on screen.” | Provides choice; not treatment instruction |
| `CLM-053` | Exit | “Stop” / “Done for now” | Clear, non-evaluative exit |
| `CLM-054` | No audio | “Audio isn’t available. You can continue with silent instructions.” | Honest recovery without danger language |
| `CLM-055` | Premium unavailable | “Grounding and the other companion features require Premium. Your alarm and account/data controls remain available.” | No safety coercion; exact StoreKit details follow |

Satyam Shree accepted the documented stressed-moment paywall risk on
25 July 2026. The paywall remains dismissible, never blocks the alarm or data
rights, and never uses danger, urgency, safety, or outcome pressure.

## 7. Prohibited claim families

| ID | Prohibited examples | Why |
|---|---|---|
| `CLM-100` | “Detects sleep paralysis,” “knows when it happens,” “smart detection,” “episode recognized” | No sensing/detection capability |
| `CLM-101` | “Predicts your next episode,” “high-risk night,” “risk score,” “wellness index,” “readiness score” | Prediction/risk classification is excluded |
| `CLM-102` | “Prevents episodes,” “reduces attacks,” “stop sleep paralysis,” “protected sleep,” “guardian mode” | Prevention/protection and outcome claims are unsupported/excluded |
| `CLM-103` | “Treats,” “therapy,” “clinically proven,” “medical-grade,” “doctor approved” | Medical/treatment substantiation and regulated scope are absent |
| `CLM-104` | “You are awake,” “You are safe,” “The episode is over,” “Your body is normal” | The app cannot verify the person's state |
| `CLM-105` | “Guaranteed calm,” “peaceful sleep,” “sleep better tonight,” “recover faster” | Outcome guarantee or benefit claim without approved evidence |
| `CLM-106` | “Find your triggers,” “X caused your episode,” “your pattern means…” | Causal/inferential interpretation is excluded |
| `CLM-107` | “Always works,” “never misses,” “works even if your phone is off,” “100% offline” | Platform/network behavior has limits |
| `CLM-108` | “Anonymous,” “zero data,” “nothing leaves your phone” | False when optional sync/commerce/diagnostics are enabled |
| `CLM-109` | “HIPAA-ready,” “HIPAA-compliant,” “GDPR compliant,” “fully secure” | Broad legal/security status cannot be claimed from architecture intent |
| `CLM-110` | “Free tonight,” “3-night trial,” “free forever,” or trial copy shown to an ineligible customer | The approved offer is Apple’s eligibility-controlled three-day introductory trial |
| `CLM-111` | “Cancel by deleting your account” | Apple subscription continues until separately managed/cancelled |
| `CLM-112` | Percent reductions, success rates, “#1,” “first app,” testimonials as typical results | Evidence and qualification package is absent |
| `CLM-113` | “AI,” “personalized coaching,” “clinician report,” “health insights” | Those capabilities are excluded |
| `CLM-114` | Emergency monitoring, rescue, alerting a partner/clinician, or calling emergency services | No such operational capability |

Prohibited terms are scanned in source, localized resources, audio transcripts,
notification payloads, App Intents, widgets/controls, metadata, screenshots,
support macros, and web copy. A simple keyword scan is necessary but not
sufficient; reviewers assess implied meaning.

## 8. Surface checklist

Every approved `CLM-*` copy record must identify all applicable surfaces:

- onboarding and in-app UI;
- AlarmKit presentation, App Intent, Control, widget, Live Activity, Lock
  Screen, Dynamic Island, and notification;
- audio title, script, transcript, filename, metadata, and download manifest;
- paywall, StoreKit product display name/description, offer copy, restore,
  refund, subscription, and account-deletion notice;
- App Store name, subtitle, description, keywords, promotional text, age
  rating, screenshots, preview video, and review notes;
- privacy policy, terms, support, FAQ, emails, social/web marketing, and sales
  material; and
- analytics event/property names and internal dashboards.

Approval of one surface does not approve a stronger version elsewhere.

## 9. Claims acceptance evidence

Required before Gate 0:

- named Content/Claims and Privacy/Legal approvers;
- approved English source copy and localization brief;
- link from each screen/state and audio item to a `CLM-*` record;
- prohibited-family scan with human semantic review;
- technical owner confirmation that every conditional claim matches physical
  evidence;
- privacy owner confirmation that privacy statements match the data/SDK
  inventory; and
- Product confirmation that paywall placement does not use fear, urgency, or a
  vulnerable moment coercively.

Required test examples:

- `T-GRD-006-COPY-EN`
- `T-HIS-001-COPY-NO-INFERENCE`
- `T-SET-007-COPY-GLOBAL-PROMOTION`
- `T-SLP-004-DEVICE-SILENT-FOCUS`
- `T-X-001-COPY-ALL-SURFACES`
