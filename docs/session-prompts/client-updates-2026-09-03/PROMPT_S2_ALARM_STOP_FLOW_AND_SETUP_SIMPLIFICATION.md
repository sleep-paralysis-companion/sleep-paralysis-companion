# Session Prompt: S2 — Alarm Stop Redirection & Alarm Setup Simplification

> **Session ID:** `S2-ALARM-STOP-AND-SETUP`  
> **Target Branch:** `feat/alarm-stop-flow-and-setup-simplification`  
> **Input Authority:** Meeting notes from Sep 3, 2026 (Shraddha Rakshe & Satyam Shree).

---

## 1. Operating Contract

You are working on the Sleep Paralysis Companion iOS repository (`C:\Users\satya\Documents\paralux`).
This session is exclusively focused on **redirecting users directly to the Morning Check-in questions flow upon stopping the alarm, simplifying the alarm creation/editing setup layout to reduce cognitive load, and streamlining schedule navigation from the homepage**.

### Repository Context & Guidelines
- **Workstation:** Windows host. All compilation, linting, and tests run on hosted GitHub Actions (`macos-26`).
- **Language / Concurrency:** Swift 6, `SWIFT_STRICT_CONCURRENCY = complete`, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`.
- **Precedence:** Depends on Session S1 (`fix/morning-checkin-matrix-and-bugs`). Ensure you branch off or rebase on top of the S1 commit so that Morning Check-in is fully functional when redirected from the alarm screen.

---

## 2. Problem Snapshot & Detailed Requirements

### Requirement 1: Alarm Screen Post-Stop Redirection
- **Current Behavior:** Stopping the alarm can leave the user on an idle screen or require manual navigation to find the morning check-in.
- **Client Decision:**
  > *"If a user stops the alarm, the flow should transition to the morning questions flow rather than staying on the alarm screen. The stop and snooze buttons should remain, but the post-stop action is the specific change required."*
- **Implementation in [`ios/Sources/Features/Schedule/AlarmRingingView.swift`](file:///c:/Users/satya/Documents/paralux/ios/Sources/Features/Schedule/AlarmRingingView.swift) & [`AppModel.swift`](file:///c:/Users/satya/Documents/paralux/ios/Sources/App/AppModel.swift):**
  1. Both "Stop" and "Snooze" buttons remain visible and styled with high contrast.
  2. When the user taps **"Stop"** (`model.stopAlarm()`):
     - Stop alarm audio playback and cancel active snooze tasks.
     - Reset `isAlarmRinging = false`.
     - Switch `selectedTab = .sleep`.
     - Set `isMorningCheckInPresented = true`.
     - Open route `.morningCheckIn` (or present `MorningCheckInFlowView`).
     - Ensure the presentation is clean, without visual flicker, double sheet dismissal, or timing races.
  3. When the user taps **"Snooze"** (`model.snoozeAlarm()`):
     - Keeps existing behavior: temporarily silences audio and schedules next ring in 9 minutes.

### Requirement 2: Alarm Setup Page Simplification
- **Client Decision:**
  > *"Shraddha Rakshe identifies the current alarm setup page as having too much information and being overwhelming. They request a return to a simpler design, similar to previous versions that displayed dates clearly. Satyam Shree agrees to implement this simpler approach."*
- **Implementation in [`ios/Sources/Features/Schedule/AlarmScheduleEditorView.swift`](file:///c:/Users/satya/Documents/paralux/ios/Sources/Features/Schedule/AlarmScheduleEditorView.swift):**
  1. **Clear Header & Visual Hierarchy:**
     - Clean navigation header with clear "Back" and "Save" actions.
     - Distinct, calm typography matching the SPC design system (`AppFont.latoBold`, `AppFont.inter`).
  2. **Clear Time & Date Selectors:**
     - Make bedtime and wake-up time wheel pickers immediately readable.
     - For recurring schedules, show clean weekday toggle capsules with clear active state styling.
     - For one-time wake-only alarms, show date selection clearly without buried menus.
  3. **Cognitive Load Reduction:**
     - Remove unnecessary secondary or redundant form fields that overwhelm users right before sleep.
     - Clean, expandable rows for sound selection and reminder lead time (defaulting to standard 15-minute gentle reminder).
     - Remove cluttered technical diagnostics or complex multi-option matrices.

### Requirement 3: Homepage Navigation Consolidation
- **Client Decision:**
  > *"Satyam Shree suggests moving all navigation to the homepage to create a more intuitive experience, as the sleep page currently serves as the default entry point for the app. Assess intuitiveness of the Manage Alarm History feature."*
- **Implementation in [`ios/Sources/Features/Home/HomeView.swift`](file:///c:/Users/satya/Documents/paralux/ios/Sources/Features/Home/HomeView.swift) & [`AppTabShellView.swift`](file:///c:/Users/satya/Documents/paralux/ios/Sources/Features/Home/AppTabShellView.swift):**
  1. Ensure the active schedule card on the Sleep/Home screen provides an obvious, single-tap entry to edit or view schedules (`home.editSchedule` / `home.sleepSchedule`).
  2. Make schedule access obvious without burying it in submenus or confusing "History" labels.
  3. Ensure pressing "Back" from the schedule editor returns predictably to the Sleep tab.

---

## 3. Files You Own vs. Do Not Touch

### Files You Own
- [`ios/Sources/Features/Schedule/AlarmRingingView.swift`](file:///c:/Users/satya/Documents/paralux/ios/Sources/Features/Schedule/AlarmRingingView.swift)
- [`ios/Sources/Features/Schedule/AlarmScheduleEditorView.swift`](file:///c:/Users/satya/Documents/paralux/ios/Sources/Features/Schedule/AlarmScheduleEditorView.swift)
- [`ios/Sources/Features/Schedule/ScheduleUIModels.swift`](file:///c:/Users/satya/Documents/paralux/ios/Sources/Features/Schedule/ScheduleUIModels.swift)
- [`ios/Sources/Features/Home/HomeView.swift`](file:///c:/Users/satya/Documents/paralux/ios/Sources/Features/Home/HomeView.swift) (Only schedule action cards and navigation hooks)
- [`ios/Sources/App/AppModel.swift`](file:///c:/Users/satya/Documents/paralux/ios/Sources/App/AppModel.swift) (Only alarm stopping and schedule navigation methods: `stopAlarm`, `snoozeAlarm`, `saveScheduleUI`)
- [`ios/Tests/Unit/ScheduleTests.swift`](file:///c:/Users/satya/Documents/paralux/ios/Tests/Unit/ScheduleTests.swift) (or new alarm flow tests)

### Do Not Touch
- `ios/Sources/Features/CheckIn/*` (Settled in S1)
- `ios/Sources/Features/Sleep/*` (Owned by S3)
- `ios/Sources/Features/Audio/*` (Owned by S3)
- `ios/Sources/Authentication/*`
- `ios/Sources/LocalPersistence/LocalSchema.swift`

---

## 4. Verification & Testing Plan

### Automated Unit Tests
Create or update tests in `ios/Tests/Unit/` (e.g., `AlarmFlowTests.swift`):
1. **Stop Alarm Redirection Test:**
   - Verify that when `stopAlarm()` is executed, `isAlarmRinging` is set to `false`, `isMorningCheckInPresented` is set to `true`, and `selectedTab` becomes `.sleep`.
2. **Snooze Alarm Test:**
   - Verify that when `snoozeAlarm()` is called, `isAlarmRinging` is false, but check-in is NOT presented, and snooze task is active.
3. **Simplified Schedule Model Validation:**
   - Verify `ScheduleUIModel` validates standard bedtime and wake-up times without requiring unnecessary input fields.
   - Verify saving a schedule persists correctly and updates legacy schedule summary.

### Hosted CI Verification
Run verification via GitHub Actions:
```powershell
# 1. Create and checkout the branch
git checkout -b feat/alarm-stop-flow-and-setup-simplification

# 2. Commit your changes
git add ios/Sources/ ios/Tests/
git commit -m "feat(alarm): redirect to morning check-in on stop, simplify alarm setup UI"

# 3. Push and watch the hosted macOS-26 battery
git push origin feat/alarm-stop-flow-and-setup-simplification
gh workflow run phase-1-integrated-app.yml --ref feat/alarm-stop-flow-and-setup-simplification
gh run list --workflow phase-1-integrated-app.yml --limit 3
gh run watch <run-id> --exit-status
```

---

## 5. Definition of Done
- [ ] Tapping "Stop" on `AlarmRingingView` reliably redirects to `MorningCheckInFlowView`.
- [ ] Tapping "Snooze" silences the alarm without triggering morning check-in.
- [ ] Alarm setup page is simplified: clear time wheel pickers, dates/days clearly displayed, zero overwhelming clutter.
- [ ] Saving a schedule completes smoothly and returns to the Home/Sleep tab.
- [ ] All unit tests pass and GitHub Actions `phase-1-integrated-app.yml` run is **GREEN**.
