# Session Prompt: S4 — Integrated CI Battery, Visual Journey & App Store Release Sign-Off

> **Session ID:** `S4-INTEGRATED-RELEASE-GATE`  
> **Target Branch:** `release/app-store-candidate` (or merged `main`)  
> **Input Authority:** Meeting notes from Sep 3, 2026 (Shraddha Rakshe & Satyam Shree).

---

## 1. Operating Contract

You are working on the Sleep Paralysis Companion iOS repository (`C:\Users\satya\Documents\paralux`).
This session is exclusively focused on **running integrated verification across all updates from Sessions S1, S2, and S3, ensuring 100% green CI pipelines, capturing the visual product journey, performing TestFlight release preflights, and generating the founder sign-off report for App Store submission**.

### Pre-Requisites & Branch State
- All code changes from S1, S2, and S3 must be merged and reconciled:
  - **S1:** Morning Check-in matrix logic, save bug, skip error fix, dynamic moon stages.
  - **S2:** Alarm post-stop redirection to Morning Check-in, simplified alarm setup UI.
  - **S3:** Sleep Player redesign (no hero vector, vertical audio list, Quick/Slow Unwind, auto-start).
- Workstation: Windows host. All automated builds and UI validations run via GitHub Actions runners (`macos-26`).

---

## 2. Integrated Verification Matrix

### Verification Suite 1: Code Health, Formatting & Lints
Verify strict compliance with repository standards before building:
- **SwiftFormat:** Verify zero formatting violations according to [`.swiftformat`](file:///c:/Users/satya/Documents/paralux/.swiftformat).
- **SwiftLint:** Verify zero warnings or errors under [`.swiftlint.yml`](file:///c:/Users/satya/Documents/paralux/.swiftlint.yml) (`SWIFT_TREAT_WARNINGS_AS_ERRORS = YES`).
- **Product Contract:** Verify [`scripts/phase_1c_contract_check.sh`](file:///c:/Users/satya/Documents/paralux/scripts/phase_1c_contract_check.sh) passes without contract violations.

### Verification Suite 2: Full Test Battery (`verify_ci.sh`)
Trigger and verify the full automated test battery via GitHub Actions workflow `.github/workflows/phase-1-integrated-app.yml`:
- **Unit Tests:** `FocusedRepairTests`, `NavigationStateTests`, `MorningCheckInTests`, `ScheduleTests`, `SleepPlayerTests`, `OAuthSessionServiceRestoreTests`.
- **UI Tests:** Full app launch and navigation tests (`ApplicationLaunchUITests`).
- **Target:** 0 failures, 0 leaked state, 0 strict concurrency warnings.

### Verification Suite 3: Visual Product Journey (`visual_journey.sh`)
- Run visual journey automation to ensure the updated flows render accurately.
- Verify key checkpoints:
  - Checkpoint 11: Simplified sleep schedule setup.
  - Checkpoint 14: Morning check-in (validating both 2-step NO branch and 4-step YES branch).
  - Checkpoint 15a: Sleep session & streamlined Sleep Player without hero vector.
  - Checkpoint 30–36: Curated audio library and unwind streaming.
- Verify `sleep-paralysis-companion-visual-journey.mp4` is exported and attached as a workflow artifact.

### Verification Suite 4: TestFlight & App Store Preflight
Run the release configuration checks:
- **Configuration Check:** Execute [`scripts/testflight_configuration_check.sh`](file:///c:/Users/satya/Documents/paralux/scripts/testflight_configuration_check.sh) to verify:
  - App bundle ID: `app.sleepcompanion.spc`
  - Widget bundle ID: `app.sleepcompanion.spc.widget`
  - Shared App Group: `group.app.sleepcompanion.spc`
  - App Store provisioning profile: `Sleep Paralysis Companion - App Store`
  - Widget App Store provisioning profile: `Sleep Paralysis Companion Widget - App Store`
- **Auth Preflight:** Execute [`scripts/auth_config_preflight.sh --configuration Production`](file:///c:/Users/satya/Documents/paralux/scripts/auth_config_preflight.sh) to ensure production keys, redirect URLs, and entitlements are intact.

---

## 3. GitHub Actions Execution Playbook

From the Windows workstation, execute the following commands using the `gh` CLI:

```powershell
# 1. Ensure working directory is clean and checkout release branch
git checkout -b release/app-store-candidate
git push origin release/app-store-candidate

# 2. Trigger the integrated battery workflow
gh workflow run phase-1-integrated-app.yml --ref release/app-store-candidate

# 3. Monitor the run
gh run list --workflow phase-1-integrated-app.yml --limit 3
gh run watch <run-id> --exit-status

# 4. If any test or step fails, inspect log output immediately
gh run view <run-id> --log-failed

# 5. Trigger internal TestFlight archive workflow
gh workflow run testflight-internal.yml --ref release/app-store-candidate
gh run watch <testflight-run-id> --exit-status
```

---

## 4. Final Notification for Shraddha (Founder Sign-Off Template)

Once all verification suites and the TestFlight build pass, prepare the following update to notify Shraddha before the planned deployment:

```markdown
Hi Shraddha,

All requested updates and fixes from our September 3 meeting have been implemented, verified across our test suites, and validated through our hosted CI pipeline:

1. Alarm Stop Redirection: Tapping "Stop" on the alarm screen now transitions directly into the Morning Check-in flow. Stop and Snooze controls remain in place.
2. Morning Check-in Logic & Bugs Resolved:
   - Check-in saving bug is fixed; local SQLite persistence verified for both guest and authenticated states.
   - The skip check-in error banner has been eliminated.
   - The matrix logic is corrected: if no episode occurred, the app presents exactly 2 questions before the affirmation.
   - Moon stage progress indicators now dynamically display 2 stages for the "No Episode" path and 4 stages for the "Yes Episode" path.
3. Alarm Setup Simplification: The alarm creation/editing layout has been streamlined to clearly display dates and times with reduced cognitive load.
4. Sleep Player Redesign:
   - Hero vector removed from the bedtime player for a cleaner, modern layout.
   - Direct audio track access at the top in a vertically scrollable list supporting "Quick Unwind" (15m) and "Slow Unwind" (1h 15m), complete with download indicators and consistent ambient visuals.
   - Grounding feature and audio fade-away timer retained.
   - Saving an alarm schedule now automatically launches and initiates the Sleep Player.
   - "Second Sleep" remains dedicated to post-episode recovery with its single large CTA button.
5. CI & Release Readiness:
   - Automated tests and visual journey checkpoints passed 100% on macOS hosted runners.
   - TestFlight build candidate is packaged and ready for App Store submission tomorrow.
```

---

## 5. Definition of Done
- [ ] `phase-1-integrated-app.yml` passes with zero failures on macOS runner.
- [ ] Visual journey artifact (`.mp4`) generated with all updated screens.
- [ ] TestFlight configuration and preflight scripts exit 0 in Production mode.
- [ ] Build uploaded to App Store Connect / TestFlight.
- [ ] Notification update sent to Shraddha for final deployment sign-off.
