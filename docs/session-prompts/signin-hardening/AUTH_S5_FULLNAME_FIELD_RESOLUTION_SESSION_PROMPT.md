# Session Prompt: Sign-in Hardening S5 — Resolve the Discarded Full-Name Field

You are working in the Sleep Paralysis Companion repository (`C:\Users\satya\Documents\paralux`).
Exclusively **S5: resolve the create-account Full Name affordance**. Operating contract; no memory
of other chats. Independent of S1–S4 (isolated file); may run in any slot, including parallel with
them. Read `AGENTS.md` + folder `README.md` standing facts first.

## Problem being fixed (verified current behavior)

Create-account mode of `FigmaAuthenticationView` requires a non-empty Full Name
(`createAccount()` gate, ~L73–82; TextField within `AuthenticationReferenceLayout`,
~L141–150) and then discards it: neither OAuth sign-in nor profile bootstrap ever consumes
`fullName`. Asking for input that has no effect erodes trust and invites review scrutiny. Log-in
mode does not show the field.

## Required outcome (default direction)

Remove the misleading field entirely. Create-account and log-in become provider-choice screens with
accurate copy; the app already supports later name management via the existing profile/edit
surfaces (`EditProfileView` route exists in `AppRootView` destinations).

## Implementation requirements

1. Delete `fullName` state, `@FocusState`, the focus-management calls tied to it, and the
   `createAccount` closure chain from `FigmaAuthenticationView` +
   `AuthenticationReferenceLayout`; the create-account primary action becomes a plain continue into
   provider selection (preserve current layout proportions/moon/constellation composition — no
   decorative redesign).
2. Adjust copy to stay truthful and calm: heading/subtitle keep their intent; any microcopy that
   references entering a name disappears; keep the existing "Choose Google or Apple…" guidance
   pattern where sensible.
3. Sweep for dependents before deleting: grep Tests/, AppIntents, snapshot/UI tests, and analytics
   seams for references to the name field / `fullName` / this screen's accessibility tree. If a UI
   test drives the field, update the test to the new flow (author the edit even though it cannot be
   executed here). If something product-critical unexpectedly depends on collecting a name here,
   STOP that aspect and surface it in the report instead of silently rewiring data flow.
4. Do NOT implement server/profile pass-through of a name in this session. Instead, append a short
   "Option B annex" section (design notes only, ≤15 lines) describing how capture would work later
   — likely post-OAuth into profile bootstrap near `EditProfile`/questionnaire identity — so the
   product conversation has a written anchor.
5. VoiceOver/accessibility text stays complete after removal (no dangling focus/hints).

## Files you own

`Sources/Features/Onboarding/FigmaAuthenticationView.swift`, affected UI/unit tests referencing
this screen.
**Do not touch**: any Authentication domain/service file, AppModel beyond trivially compiling call
sites, Onboarding siblings (`WelcomeView`, `IntegratedOnboardingViews`) unless a compile or test
reference forces a mechanical fix — then keep it minimal and note it.

## Environment honesty & verification

Windows workstation, no runnable UI toolchain. Provide textual self-checks (e.g. Select-String
proving `fullName` fully removed from the module, zero leftover `localMessage = "Enter your name`
strings), plus the honest "compile-unverified / UI-run-unverified" statement. List the Make targets
the user should run on macOS after merge (`make lint format ui`).

## Report-back

Diff narrative (what was removed where), dependent-reference sweep results, accessibility
post-check, Option B annex content, open questions for product (e.g., should introduction skip
target include profile naming later?).
