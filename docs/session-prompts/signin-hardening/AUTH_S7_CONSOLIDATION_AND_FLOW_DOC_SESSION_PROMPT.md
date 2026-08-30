# Session Prompt: Sign-in Hardening S7 — Architecture Consolidation & Flow Documentation

You are working in the Sleep Paralysis Companion repository (`C:\Users\satya\Documents\paralux`).
Exclusively **S7: reconcile/document the dual authentication architectures and author the final
sign-in flow narrative**. Operating contract; no memory of other chats. Prerequisites: **S1–S6 all
merged** — this session reads their end-state and produces mostly documentation plus verdict-level
comments. Read `AGENTS.md` + folder `README.md` standing facts first.

## Problem being fixed

Two parallel auth stacks coexist: (a) the hand-hardened stack — `OAuthChallengeFactory`
(state + raw/hashed nonce + PKCE proofs) and `AuthenticationCoordinator`
(`begin/complete/reauthenticate/signOut`, `AuthenticationFoundation.swift`) with strict validation
and unit coverage — used today only by data-rights/deletion flows
(`SignOutCoordinator` in `Sources/DataRights/DeletionFoundation.swift`); and (b) the production
sign-in path delegating to supabase-swift's `signInWithOAuth` (SDK-managed PKCE/state). The split
is defensible but undocumented, inviting drift; nothing describes the end-to-end flow anywhere in
`docs/`.

## Required outcome

1. **Verdict on architecture**: trace every live consumer of `AuthenticationCoordinator` /
   `SignOutCoordinator` (grep production sources AND tests) and either
   - (A) confirm deletion-flow-only scope still fits product needs → keep both, adding precise
     doc-comment headers stating why sign-in delegates to the SDK and what invariant each stack
     owns (who validates state/nonce, who owns secrets post-S4, who can throw wrongAccount); or
   - (B) identify genuinely dead code (referenced by nothing but its own tests) → list it with a
     proposed removal plan; implement removal ONLY if trivially provable dead, else document.
     Big refactors are out of scope for this session.
2. **Author `docs/PHASE_SIGN_IN_FLOW.md`**: the authoritative narrative — launch composition
   (`AppCompositionRoot` decision tree incl. fail-closed configuration), restore strategy
   (offline-tolerant per S1, migration story per S4), storage inventory at rest (post-S4 single
   sanctioned token store + identity record), provider web-session flow incl. `spc://auth/callback`
   handling, failure taxonomy table with user-facing copy (S2) and log events, wrong-account
   guards across sign-in / reauthentication-for-deletion / account deletion, accessibility notes
   (S3/S5 outcomes). Include a text sequence diagram and file map with responsibilities.
3. Cross-link: folder `README.md` gets a "Completed — see `docs/PHASE_SIGN_IN_FLOW.md`" banner per
   issue (keep history, house convention uses amended-banners over deletions).
4. Confirm zero regressions of earlier sessions' contracts via targeted greps: no direct
   `client.auth.refreshSession` outside the seam, no duplicate keychain service literals, no
   secret-bearing fields in the app-side store, taxonomy exhaustiveness compiles plausibly.
5. If this repo expects design-system/token conformance for docs artifacts, follow existing
   `docs/phase-*` document style (title block, sectioning) rather than inventing format.

## Files you own

New `docs/PHASE_SIGN_IN_FLOW.md`, doc-comments across `Sources/Authentication/**` and
`Sources/DataRights/DeletionFoundation.swift` headers, README banner updates inside
`docs/session-prompts/signin-hardening/`. Optional minimal comment-only touches elsewhere where a
verdict demands one sentence.
**Do not touch**: behavior-bearing code lines, tests' logic, Configurations, workflows.

## Environment honesty & verification

Windows workstation; documentation-first session — verify claims strictly by reading code (cite
file:line for every architectural assertion) and fetching supabase-swift docs if needed. No builds
to claim; say so.

## Report-back

Chosen verdict (A/B) with evidence table of coordinator consumers; doc file delivered (link);
residual risks/tech-debt register worth a future phase (e.g., refresh-on-foreground policy,
token revocation nuance after `signOut()` + identity-record restoration edge cases noted in prior
reviews).
