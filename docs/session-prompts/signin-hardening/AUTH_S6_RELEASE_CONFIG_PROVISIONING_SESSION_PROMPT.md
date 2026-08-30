# Session Prompt: Sign-in Hardening S6 — Release Configuration Provisioning Guard

> **Amended before execution:** This prompt was authored under the assumption that Codemagic
> participates in CI. The team later confirmed **GitHub Actions is the only CI/CD in use**
> (`codemagic.yaml` is retained but never executed). Where this prompt says to wire provisioning
> into `codemagic.yaml` or Codemagic environment groups, treat the GitHub Actions
> `testflight-internal.yml` path as the sole integration target. The completed S6 work followed
> this amendment; see `docs/phase-1c/AUTH_CONFIG_PROVISIONING.md`.

You are working in the Sleep Paralysis Companion repository (`C:\Users\satya\Documents\paralux`).
Exclusively **S6: ensure Staging/Production archives can never silently ship with dead
authentication**. Operating contract; no memory of other chats. This session is **independent of
S1–S5** (zero Swift source ownership) and is the recommended first session to run because it
protects the next TestFlight upload. Read `AGENTS.md` + folder `README.md` standing facts first.

## Problem being fixed (verified current facts)

All three Supabase values are supplied **only** by `ios/Configurations/Local.xcconfig`, which is
gitignored; only `Local.xcconfig.example` is tracked. `Base.xcconfig` leaves
`SPC_SUPABASE_PUBLISHABLE_KEY` and `SPC_OAUTH_REDIRECT_URL` blank. A clean clone without the local
file therefore produces a release build where `SupabasePublicConfiguration.load(...)` returns nil
(`ios/Sources/Configuration/SupabasePublicConfiguration.swift`: https + pinned-host check, key
prefix check, `spc://` redirect-with-nonempty-host check) and authentication resolves to
`UnavailableOAuthSessionService` — sign-in renders "Provider sign-in will be available once
configuration is complete." The build otherwise succeeds and could reach TestFlight silently.
Codemagic workflows (`codemagic.yaml`) invoke `scripts/verify_phase_1c_codemagic_ios.sh` and the
persona-audio/backend variants; whether they provision `Local.xcconfig` from Codemagic environment
variables is currently unverified.

## Required outcome

1. **Mechanism identified**: document exactly how Supabase configuration reaches Development /
   Staging / Production builds on CI today (or prove it does not). Inspect
   `scripts/verify_phase_1c_codemagic_ios.sh`, `scripts/bootstrap.sh`, sibling verify scripts,
   `codemagic.yaml`, and any env-group references.
2. **Provisioning**: if absent, add a safe provisioning path — a script step that writes
   `ios/Configurations/Local.xcconfig` before archive from secret environment variables defined in
   Codemagic's UI-side environment group(s) (never committed YAML plaintext). Respect Codemagic's
   variable exposure rules; verify against current official Codemagic documentation (fetch it;
   record verification date) including variable-prefix/publishing behavior for groups.
3. **Fail-loud preflight**: add a preflight check that fails the workflow (non-zero exit with a
   clear, non-secret-leaking message) when a Staging or Production build would embed an empty
   publishable key or redirect URL. Wire it into the relevant workflow scripts ahead of xcodebuild,
   and optionally guard Debug-with-auth too. Nothing may echo key contents; length/format presence
   checks only (e.g., starts with `sb_publishable_` and length > 20).
4. **Runbook**: create `docs/phase-1c/AUTH_CONFIG_PROVISIONING.md` covering: required values and
   their provenance (publishable key source; redirect must exactly equal an approved Supabase Auth
   allow-list entry such as `spc://auth/callback`; NEVER service-role/secret keys in xcconfig),
   developer setup steps via `Local.xcconfig.example`, CI env-group checklist, and failure-mode
   table mapping the preflight errors to fixes.
5. Update `Local.xcconfig.example` comments to point to the runbook.

## Files you own

`scripts/*` (new preflight/provisioning scripts plus wiring edits in existing verify scripts where
the investigated design requires), `codemagic.yaml` (additive steps/env-group references only),
`ios/Configurations/Local.xcconfig.example`,
`docs/phase-1c/AUTH_CONFIG_PROVISIONING.md`.
**Do not touch**: any Swift sources, `project.yml`, `Base/Development/Staging/Production.xcconfig`
values (blank keys stay blank locally by design), signing/plist files.

## Constraints & honesty

- Secrets stay out of git, logs, and this repo's docs entirely; runbooks reference "the value in
  the environment group", never placeholders resembling real keys.
- Fetch and cite current Codemagic + Apple docs where the prompt asks you to verify external
  behavior (e.g., `#include?` semantics are already known-repo-local; don't re-litigate Swift).
- Windows workstation: shell scripts can be syntax-reviewed but not executed; state so. Prefer
  plain POSIX bash consistent with existing scripts' style.
- If your investigation shows CI already provisions correctly, skip changes and deliver the runbook
  + preflight anyway (defense-in-depth), documenting the discovered mechanism as primary evidence.

## Report-back

Investigation findings (with file:line citations) → chosen provisioning mechanism → scripts added →
workflow diffs → runbook outline → the exact manual steps the owner must perform in the Codemagic
dashboard (variable names/group names only, no values).
