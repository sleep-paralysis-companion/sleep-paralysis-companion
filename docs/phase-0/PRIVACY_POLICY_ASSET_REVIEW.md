# Privacy Policy Asset Review

> **29 July 2026 product-change note.** This review predates the approved local-only personal-audio and just-in-time recording scope. Its exclusions are superseded by [Persona and Personal Audio Product Realignment](./PERSONA_AND_PERSONAL_AUDIO_REALIGNMENT.md); the asset is still not publication authority.

**Review ID:** `PRIV-P0-001`  
**Reviewed:** 25 July 2026  
**Reviewer/accountable owner:** Satyam Shree  
**Source:** `Privacy_Policy.pdf`, 16 pages, effective-date text 12 May 2026  
**SHA-256:** `FA37195B6C887C5F3D787C74DD9F369B4B83B6320C11E5D703881E6F93652C7F`  
**Disposition:** **DISCOVERY TEMPLATE - NOT APPROVED FOR PUBLICATION**

## 1. Review method

All 16 pages were text-extracted and rendered for visual inspection. The file
is readable and consistently laid out, but page 1 is a stray `Tab 1` page and
the policy contains unresolved placeholders throughout:

- `[APP NAME]`;
- `[COMPANY / LEGAL ENTITY NAME]`;
- `[COMPANY MAILING ADDRESS]`; and
- `[PRIVACY CONTACT EMAIL]`.

The template cannot be published until those values, the effective date, the
jurisdictional scope, and a public URL are approved and tested.

## 2. Material conflicts with the Phase 1 contract

The following PDF statements are not descriptions of the approved product and
must be removed rather than implemented:

| PDF pages | Template statement | Phase 1 disposition |
|---|---|---|
| 3-4 | Required account using Apple ID or phone OTP | Superseded. Phase 1 is guest/local-first; optional Supabase sync offers Apple and Google only. |
| 3-4 | Health questionnaire and profile responses | Excluded from onboarding. Only the optional user-entered check-in fields in `SPEC-P1-001` are allowed. |
| 3-6, 8-10, 13-16 | Loved-one voice recording/upload and cloud backup | Excluded. No microphone or personal audio collection in Phase 1. |
| 4-8, 13-16 | Overnight microphone monitoring, detection, and real-time intervention | Prohibited. Phase 1 does not monitor, detect, predict, or automatically respond to an episode. |
| 4, 6-10, 16 | AI sleep reports, scores, inferences, recommendations, and provider sharing | Excluded. History contains user-entered facts and simple descriptive summaries only. |
| 4, 13 | Apple Pay for digital premium access | Incorrect. Premium digital functionality uses StoreKit In-App Purchase. |
| 4, 8, 16 | Cloud voice/audio storage | Excluded. Supabase stores only the approved account-linked records; catalog audio follows `AUDIO-P1-001`. |
| 5-6 | Consent/legal bases for microphone and health questionnaire processing | Remove because those collection purposes are absent. |
| 9-13 | Biometric/voice-data declarations | Remove unless a future approved scope actually collects biometric information. |
| 13 | Ages 13-17 with guardian supervision | Unapproved audience rule. Product/Legal must set the shipping age rating and child-use policy from the actual data practices. |

The policy must not claim HIPAA, medical-device, AI, biometric, voice,
detection, protection, safety, or outcome capabilities.

## 3. Required replacement policy content

The shipping policy must describe only implemented and verified practices:

- local profile, settings, alarm intent, check-ins, and optional private note;
- optional Supabase account and synchronization;
- Sign in with Apple and Sign in with Google data;
- StoreKit transaction/entitlement facts without payment-card collection;
- an approved minimal diagnostics allowlist, if diagnostics are enabled;
- no advertising, cross-app tracking, microphone, voice upload, HealthKit,
  overnight monitoring, AI inference, or automatic episode detection;
- local and Supabase storage locations and actual configured regions;
- the retention, export, entry deletion, local deletion, and account deletion
  rules in `DATA-P1-001`;
- the exact processors and links to their relevant terms or DPAs;
- how app-account deletion differs from Apple subscription cancellation;
- accurate state-specific or international rights only after applicability
  review; and
- legal entity, address, privacy contact, effective date, change notice, and a
  tested public URL.

## 4. Phase 0 decision

This PDF is useful evidence of previously proposed features, but it does not
approve those features and is not a source of implementation requirements.
`SPEC-P1-001`, `DATA-P1-001`, `CLAIMS-P1-001`, and `COM-P1-001` control.

Satyam Shree approved this supersession and correction direction on
25 July 2026. Final legal wording and publication remain a release dependency;
publication of the reviewed PDF is explicitly prohibited.
