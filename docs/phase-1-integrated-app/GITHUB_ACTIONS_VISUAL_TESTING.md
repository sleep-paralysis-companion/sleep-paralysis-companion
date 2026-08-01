# GitHub Actions visual testing

## Purpose

The `Phase 1 Integrated App` workflow is the hosted macOS gate and visual
presentation path for `codex/phase-1-integrated-app`. It uses GitHub Actions
only. It does not call Codemagic, sign an app, publish a build, or access the
live Supabase project.

## What the workflow produces

The macOS job:

1. selects the pinned Xcode 26.6 toolchain;
2. generates the Xcode project from `ios/project.yml`;
3. runs formatting, lint, privacy, secret, build, unit, and UI checks;
4. creates and boots the pinned iPhone 17 / iOS 26.5 Simulator by UDID;
5. exercises the integrated visual journey;
6. retains the full `.xcresult` bundles;
7. exports named screenshots for sixteen product checkpoints; and
8. records the journey as `paralux-visual-journey.mp4`.

The Linux job starts an isolated local Supabase stack and runs the repository
migrations, pgTAP tests, database lint, and Edge Function verification. It does
not connect to or mutate production.

## Viewing the app presentation

After an explicitly authorized push of the candidate:

1. open the repository's **Actions** tab;
2. open **Phase 1 Integrated App**;
3. wait for both jobs to reach a terminal result;
4. verify that both jobs reference the exact pushed commit;
5. download `phase-1-integrated-visual-journey-<run>-<attempt>`;
6. open `paralux-visual-journey.mp4`; and
7. review the named screenshots and `README.md` in the same artifact.

Before this workflow reaches the default branch, its branch-specific `push`
event is the trigger. GitHub exposes **Run workflow** for `workflow_dispatch`
only after the workflow definition exists on the default branch. Every run
still requires its reported commit SHA and both terminal job results to be
recorded.

## Visual journey

The presentation covers:

- splash and three product-introduction screens;
- the real unconfigured-provider boundary;
- the three-question persona flow;
- recommended setup;
- comfort-audio setup;
- sleep schedule;
- Home;
- manual grounding;
- optional morning check-in;
- History; and
- Settings.

After showing the provider boundary, the presentation relaunches through the
Debug-only UI-test authentication seam. This makes the remaining local product
journey visible without adding test credentials, a backdoor, or a production
authentication bypass.

## Evidence boundary

A green workflow plus its artifacts proves repository compilation and the
recorded Simulator behavior only for the exact commit built by that run. It
does not prove:

- production Apple or Google OAuth;
- Apple-team signing or installation;
- TestFlight distribution;
- physical-iPhone behavior;
- locked-device or terminated-app widget behavior;
- microphone, speaker, interruption, or production-audio quality; or
- live-production backend behavior.

Those remain separate configuration and physical-device gates.
