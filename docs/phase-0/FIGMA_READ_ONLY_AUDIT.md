# Figma Read-Only Audit

**Audit ID:** `FIGMA-P0-001`  
**Inspection date:** 25 July 2026  
**Authority:** Strictly read-only visual and interaction evidence  
**Status:** `PARTIAL` evidence retained as superseded discovery material; child
node IDs, component properties, variables, and prototype reactions remain
unavailable  
**Figma mutation:** None

No Figma mutation occurred.

## 1. Confirmed identity and scope

The supplied file key was sent directly to the connected Figma MCP:

- file key: `vjbC6so9SSpuRpJPsYuXEw`;
- supplied starting node: `299:358`;
- `figma.fileKey` returned `vjbC6so9SSpuRpJPsYuXEw`;
- node `299:358` resolved to the page `Components`;
- the file also exposed `Screens` (`0:1`) and `Mascot` (`5:2`);
- editor type: `figma`.

This proves that the supplied node belongs to the supplied file key. The Plugin
API exposes the document root name only as `Document`, so the MCP result does
not independently attest the display filename `SP`. The file URL and key are
the identity authority for that label.

The MCP schema has no account/email selector. Reading `figma.currentUser`
failed because that API is unsupported in this connector. Therefore this audit
cannot independently prove that the connected session email is
`main.satyamshee@gmail.com`; it proves only the file/key/node access above.

## 2. Evidence levels

| Level | Meaning in this audit |
|---|---|
| `NODE-CONFIRMED` | The MCP returned the exact node ID, name, type, and file key. |
| `CANVAS-VISUAL` | A screenshot endpoint rendered the page; visible copy and concepts may be reconciled, but child IDs and prototype semantics are not known. |
| `NOT-VERIFIED` | The hierarchy, property, variable, reaction, or state evidence did not return and must not be inferred. |

## 3. Connector evidence

| Endpoint/query | Result | Evidence |
|---|---|---|
| File/root metadata without a node | Returned top-level page `Mascot` (`5:2`) | Partial orientation only; the response did not enumerate every page |
| Read-only Plugin API identity query | Returned exact file key, pages `Mascot`, `Screens`, `Components`, and node `299:358` as `Components` page | `NODE-CONFIRMED` |
| `Screens` screenshot (`0:1`) | Succeeded; natural canvas `19,424 × 22,074`, inspected at up to `7,209 × 8,192` | `CANVAS-VISUAL` |
| `Components` screenshot (`299:358`) | Succeeded; natural canvas `102,410 × 17,672`, inspected at `4,096 × 707` | `CANVAS-VISUAL`; too wide for reliable child/component-name enumeration |
| `Mascot` screenshot (`5:2`) | Succeeded; natural canvas `5,673 × 3,220`, inspected at `2,048 × 1,163` | `CANVAS-VISUAL` |
| `get_metadata` for `Screens` | HTTP `504` | No hierarchy |
| Read-only page inventories for `Screens` and `Mascot` | HTTP `504` | No child IDs or reactions |
| Components inventory | `Error: in get_variantProperties: Component set for node has existing errors`; debug UUID `a43dcb47-8b0e-442b-b12d-a32ac439b686` | No component-property inventory |
| Design context for `299:358` | “You currently have nothing selected”; debug UUID `ca2e6ff2-9f6d-4851-90ca-8d8d619f3e25` | Expected for a page/canvas node; no renderable child ID was available |
| Variable definitions for `299:358` | “You currently have nothing selected”; debug UUID `d94bafc2-b3fa-4b5b-90f4-1725e2f0758f` | No variable inventory |
| Read of connected user identity | `Error: in get_currentUser: "currentUser" is not a supported API`; debug UUID `bfe7a7c1-908d-439b-91dc-6a9dfca3a698` | Connected email not verifiable through this MCP |

All Plugin API scripts used read-only getters and returned data. They contained
no create, edit, set, move, rename, delete, annotate, comment, publish, or file
mutation operation.

## 4. Canvas-level Phase 1 reconciliation

This table maps only concepts visibly identifiable in the rendered canvases.
It is not a substitute for the required child-node/state/prototype map.

| Visible concept or wording | Stable mapping | Reconciliation |
|---|---|---|
| Marketing/splash copy including “Understand your nights. Own your sleep.” and a personalized-profile promise | `SCR-002`, `SCR-003`; `CLM-001`, `CLM-002`, `CLM-010`; `P1-ONB-001`–`003` | `CONFLICT`. “Understand your nights” remains claims review, and the visible profile promise implies analysis/personalization beyond the approved first-use contract. |
| Account creation and “Welcome Back” login before the questionnaire, with full name/email/password and Apple/Google options | `SCR-002`, `SCR-003`, `SCR-018`; `CLM-022`; `P1-ONB-003`, `P1-AUTH-001`, `P1-AUTH-002` | `CONFLICT`. Phase 1 is guest/local-first; authentication is optional and offered only for sync/account management. Full name is not an approved onboarding field. |
| Multi-question sleep-paralysis profile questionnaire, including questions about inability to move/speak and episode experiences | `SCR-003`; `P1-ONB-005`, `P1-ONB-009`, `P1-SEC-001` | `CONFLICT`. First use asks no wellness questionnaire. These questions do not become approved fields because they are visible in Figma. |
| Profile result with “SP Confirmed,” “Intruder Type,” “High Distress,” “Guardian Mode,” “Pattern Tracker,” and a moderate paralysis-risk score | `CLM-100`–`CLM-106`, `CLM-113`; `P1-X-001`; rejected `R0-005` | `EXCLUDED/PROHIBITED`. No Phase 1 `SCR-*` may implement this result or an equivalent renamed score. |
| Alarm and sleep/wellness-hours concepts, including Apple alarm references | `SCR-005`–`SCR-007`, `SCR-SYS-001`, `SCR-SYS-002`; `ST-007`–`ST-010`; `CLM-011`, `CLM-030`, `CLM-034`; `P1-SLP-001`–`004` | `VISUAL DIRECTION ONLY`. The canvas does not prove AlarmKit authorization, scheduling truth, denial, Silent/Focus, restart, or fallback behavior. |
| “Record a loved one’s voice,” voice recording controls, overnight audio detection/listening, and Guardian Mode watching through the night | No approved app screen; `P1-X-002`, `P1-X-003`; `CLM-100`, `CLM-102`, `CLM-107`, `CLM-114`; rejected `R0-003`, `R0-004` | `EXCLUDED/PROHIBITED`. No microphone, personal/partner voice, overnight monitoring, detection, or partner intervention is in Phase 1. |
| Audio/preparation cards and “What would you like to hear tonight?” | `SCR-008`, `SCR-009`, `SCR-011`, `SCR-012`; `CLM-013`, `CLM-017`, `CLM-035`; `P1-SLP-006`–`011`, `P1-GRD-001`–`005` | `PARTIAL VISUAL MATCH`. Approved local audio/visual/silent grounding may reuse visual intent only after the tracking/detection/voice concepts are removed and content/rights/device evidence exists. |
| Plan chooser, annual/monthly/three-night choices, “7 days free,” “Try everything free for a week,” payment/card/Apple Pay concepts | `SCR-015`, `SCR-016`, `SCR-023`, `SCR-SYS-005`; `ST-012`–`ST-017`; `CLM-018`, `CLM-019`, `CLM-036`, `CLM-110`, `CLM-111`; `P1-SET-007`, `P1-SET-008` | `PARTIALLY SUPERSEDED`. Approved model is StoreKit three-day trial, monthly USD 8.99, annual USD 59.99, and lifetime USD 149.99; Apple Pay/card entry cannot unlock digital features. |
| Profile/settings screens with notification, privacy/data, plan, voice/audio, and Guardian Mode rows | `SCR-017`–`SCR-019`, `SCR-023`, `SCR-024`; `P1-SET-001`–`008`, `P1-AUTH-001`–`005` | `PARTIAL/CONFLICT`. General settings structure is useful visual intent; voice/Guardian Mode rows are excluded, and optional-sync, export, deletion, restoration, recovery, and account lifecycle states are not visibly complete. |
| Morning journal/check-in asking “Did you experience sleep paralysis last night?” with `Yes`, `Not sure / partial`, and `No, slept fine` | `SCR-013`, `SCR-014`; `CLM-041`–`CLM-046`; `P1-CHK-001`–`005` | `COPY CONFLICT`. The approved exact occurrence copy is “Did you have an episode last night?” with `Yes` / `No`. Figma does not override it or add a third occurrence state. |
| Additional episode-experience questions after the morning journal | `SCR-013`; `P1-CHK-002`, `P1-SEC-001` | `OUT OF CONTRACT`. The ultra-light check-in remains occurrence, perceived intensity, present state, and optional note only. |
| Sleep report, “Analytics & Risk Intelligence,” moderate-risk score/trend, suggested actions, and sharing a risk report with a doctor/expert | `SCR-014`; `CLM-101`, `CLM-106`, `CLM-113`; `P1-HIS-001`–`004`, `P1-X-001`, `P1-X-008` | `EXCLUDED/PROHIBITED`. Phase 1 history is descriptive user-entered history only; no risk intelligence, causal interpretation, clinician report, or doctor-sharing workflow. |
| Lock-screen notification/action concepts | `SCR-SYS-002`–`SCR-SYS-004`; `ST-025`; `CLM-031`; `P1-ACT-002`, `P1-ACT-003`, `P1-ACT-006` | `VISUAL CONCEPT ONLY`. Exact system surface, privacy wording, unlock behavior, latency, idempotency, and offline/terminated behavior remain physical-spike decisions. |
| Lumi/moon/bear mascot and multiple mood/pose variations | `AUD-SLOT-001`–`003` only if later assigned an approved content role | `ASSET CONCEPT ONLY`. The canvas is not evidence of ownership, rights, provenance, accessibility purpose, final asset choice, or release approval. |

## 5. Prototype and transition evidence

The `Screens` render visibly groups screens and includes a small number of
drawn arrows, including purchase and journal/report branches. A screenshot
cannot establish whether an arrow is a real Figma prototype reaction, which
trigger/action it uses, or its destination node.

Prototype reaction extraction timed out before returning any reaction data.
Therefore:

- no prototype entry/exit is `NODE-CONFIRMED`;
- no `SCR-*` transition changes because of the screenshot;
- the canonical transitions remain those in
  [Navigation and screen/state map](./NAVIGATION_AND_STATE_MAP.md); and
- Design must still provide node-level reactions or a revisioned prototype
  export before `G0-C-002` can pass.

## 6. Required-state coverage visible on the canvases

| Required state family | Canvas result | Stable mapping |
|---|---|---|
| Ready/default | Many screens visible | `ST-003`; visual-only |
| Loading | At least one grey/skeleton-like morning screen is visible | `ST-002`; exact node/behavior not verified |
| Empty | No unambiguous Phase 1 empty state identified | `ST-004` missing |
| Offline usable/blocked | No explicit offline state identified | `ST-005`, `ST-006` missing |
| Permission not determined/denied/restricted | No complete AlarmKit/notification state set identified | `ST-007`, `ST-008` missing |
| Unsupported capability | No honest unsupported/fallback state identified | `ST-009` missing |
| Recoverable or integrity error | No complete error/retry/corrupt-asset state identified | `ST-010`, `ST-011` missing |
| Free/trial/subscription/lifetime/grace/unknown | Paywall/trial/default purchase visuals exist, but the approved access-state set is not represented | `ST-012`–`ST-017` incomplete and commercially conflicting |
| Authentication | Create-account/login visuals exist | Optional-sync entry, cancellation/provider error, verification, recovery, reauthentication, collision/linking, and guest fallback are missing or not identifiable |
| Sync | No complete pending/syncing/failed/conflicted set identified | `ST-018`, `ST-019` missing |
| Destructive | No complete entry/local/account deletion confirmation-progress-complete-partial set identified | `ST-020`–`ST-023` missing |
| Accessibility variants | No Dynamic Type, VoiceOver order/focus, contrast, motion, or compact/large-device rule could be verified | `ST-024` missing |
| Sensitive lock/background | Lock-screen concepts exist | `ST-025` remains unapproved pending copy/privacy/device evidence |
| Purchase and recovery | Plan/payment/free-trial visuals exist | Pending/cancel/unverified/grace/refund/revoke/restore/manage/refund-help recovery is missing or not identifiable |

## 7. Copy disposition

Figma is visual-intent evidence and cannot override
[Claims and copy matrix](./CLAIMS_AND_COPY_MATRIX.md) or the exact-wording
authority `S-PRD-P1-COPY`.

The canvas confirms material conflicts that must be removed or superseded
before implementation:

- account-first and personalized-profile promises;
- `SP Confirmed`, type/distress labels, risk score, analytics/risk
  intelligence, trigger/pattern claims, and doctor/expert report sharing;
- Guardian Mode, overnight listening/detection, and loved-one voice recording;
- a per-user seven-day/three-night free-trial model; and
- morning occurrence wording/options that differ from `CLM-041`.

The prohibited statement “You’re awake. You’re safe.” was not readable enough
in the canvas render to attest whether it exists in a Figma text node. It
remains prohibited under `CLM-104` regardless.

## 8. Gate result and exact closure

`FIGMA-P0-001` improved evidence from “file identity unavailable” to
“file/node identity confirmed and canvases visually inspected.” On
25 July 2026, Satyam Shree approved `D0-025`: retain this audit as discovery
evidence and supersede conflicting/unmappable legacy Figma with the canonical
specification, state map, and claims matrix. This closes the design-source
disposition criterion without pretending that unavailable child/prototype data
was inspected.

Any future design or implementation must add the required loading, empty,
offline, permission, unsupported, error, destructive, authentication, sync,
purchase/recovery, and accessibility states and map them to the canonical
stable IDs. No Figma mutation occurred.
