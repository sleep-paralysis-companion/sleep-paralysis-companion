# Session Prompt: S1 — Morning Check-In Matrix Logic, Save Bug & Skip Error Fix

> **Session ID:** `S1-CHECKIN-LOGIC-BUGS`  
> **Target Branch:** `fix/morning-checkin-matrix-and-bugs`  
> **Input Authority:** Meeting notes from Sep 3, 2026 (Shraddha Rakshe & Satyam Shree).

---

## 1. Operating Contract

You are working on the Sleep Paralysis Companion iOS repository (`C:\Users\satya\Documents\paralux`).
This session is exclusively focused on **fixing the Morning Check-in saving bug, eliminating the skip error message, implementing the 2-question vs 4-question matrix logic, and making the moon stage progress indicator dynamic**.

Do not touch alarm scheduling, sleep session player audio, or authentication code in this session.

### Repository Context & Guidelines
- **Workstation:** Windows host. All compilation, linting, and tests run on hosted GitHub Actions (`macos-26`).
- **Language / Concurrency:** Swift 6, `SWIFT_STRICT_CONCURRENCY = complete`, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`. All domain models outside actors must be `nonisolated` and `Sendable`.
- **Local Persistence:** GRDB SQLite under `LocalSchema` (current version 10). Do not bump schema unless strictly required. Local-first architecture: guest users must be able to save check-ins locally before any Supabase sign-in.

---

## 2. Problem Snapshot & Root Cause Analysis

### Bug 1: Check-in Failing to Save
- **Symptoms:** User completes the morning check-in, but the check-in is not persisted or captured in the history.
- **Root Cause:** In [`ios/Sources/App/AppModel.swift`](file:///c:/Users/satya/Documents/paralux/ios/Sources/App/AppModel.swift#L1294-L1297):
  ```swift
  guard let profileID, let userID, let occurrence = form.occurrence, form.canSubmit else {
      return false
  }
  ```
  For guests who have not authenticated with Supabase, `userID` is `nil`. This causes `submitCheckIn` to fail immediately and return `false`, preventing local SQLite persistence. The app is local-first: check-in submissions must succeed for guest profiles using the local guest identifier (`profileID.uuidString` or existing local store guest credentials).

### Bug 2: Skip Button Throws Error Regarding Saved Answers
- **Symptoms:** Skipping during the check-in flow causes an error banner: *"The check-in could not be saved. Your answers remain on screen."*
- **Root Cause:** In [`ios/Sources/Features/CheckIn/MorningCheckInFlowView.swift`](file:///c:/Users/satya/Documents/paralux/ios/Sources/Features/CheckIn/MorningCheckInFlowView.swift#L220-L235):
  ```swift
  case .postEpisodeSupport:
      saveAndShowAffirmation(for: .yes)
  case .sleepHelp:
      saveAndShowAffirmation(for: .no)
  ```
  When the user taps "Skip" on these questions, `saveAndShowAffirmation` is invoked with missing fields, or fails due to the `userID` guard. When `submitCheckIn` fails, it populates `model.feedbackMessage`, triggering an alert/banner. Skipping should cleanly complete or save whatever partial answers were given without displaying a failure alert.

### Bug 3: Matrix Logic & Moon Stages Mismatch
- **Founder Requirement:**
  - If user answers **NO** to having an episode: skip follow-up episode questions and show only **2 questions total**:
    1. *"Did you have an episode last night?"* → NO
    2. *"Did SPC help you fall asleep?"* → Audio helped / Didn't use it / Forgot it was there
    Then navigate to the affirmation screen.
  - If user answers **YES** to having an episode: show **4 questions total**:
    1. *"Did you have an episode last night?"* → YES
    2. *"How are you feeling now?"*
    3. *"How did you feel after using guided sleep meditation?"*
    4. *"What did you use after the episode?"*
    Then navigate to the affirmation screen.
- **Moon Stages Bug:**
  - The header in [`MorningCheckInHeader`](file:///c:/Users/satya/Documents/paralux/ios/Sources/Features/CheckIn/MorningCheckInFlowView.swift#L348-L355) hardcodes `ForEach(0 ..< 4, id: \.self)` regardless of whether the branch is 2 questions or 4 questions.
  - When the user is on the NO branch, the header says `"QUESTION 2 OF 2"` but renders 4 moon circles. The moon circles must reflect the active branch: exactly 2 moons for the NO branch, and 4 moons for the YES branch.

---

## 3. Files You Own vs. Do Not Touch

### Files You Own
- [`ios/Sources/Features/CheckIn/MorningCheckInFlowView.swift`](file:///c:/Users/satya/Documents/paralux/ios/Sources/Features/CheckIn/MorningCheckInFlowView.swift)
- [`ios/Sources/Domain/IntegratedPhase1Models.swift`](file:///c:/Users/satya/Documents/paralux/ios/Sources/Domain/IntegratedPhase1Models.swift) (Check-in models)
- [`ios/Sources/App/AppModel.swift`](file:///c:/Users/satya/Documents/paralux/ios/Sources/App/AppModel.swift) (Only check-in submission and navigation methods: `submitCheckIn`, `completeMorningCheckIn`)
- [`ios/Tests/Unit/MorningCheckInTests.swift`](file:///c:/Users/satya/Documents/paralux/ios/Tests/Unit/MorningCheckInTests.swift) (or new check-in unit tests)

### Do Not Touch
- `ios/Sources/Features/Schedule/*` (Owned by Session 2)
- `ios/Sources/Features/Sleep/*` (Owned by Session 3)
- `ios/Sources/Authentication/*`
- `ios/Sources/Features/Audio/*`
- `.github/workflows/*`

---

## 4. Implementation Requirements

### Requirement 1: Robust Local-First Check-In Persistence
1. Modify `submitCheckIn(_ form: MorningCheckInForm, editing: SubmittedCheckIn? = nil)` in `AppModel.swift`:
   - Do not require an active Supabase `userID`. If `userID` is `nil`, use `profileID.uuidString` or the local store guest identifier so that guest users can save morning check-ins to local SQLite seamlessly.
   - Guard condition should require:
     ```swift
     guard let profileID, let occurrence = form.occurrence, form.canSubmit else {
         return false
     }
     let effectiveUserID = userID ?? profileID.uuidString
     ```
   - Ensure `SubmittedCheckIn` is saved via `store.saveCheckIn(value, userID: effectiveUserID)`.
   - Update `checkIns` array on `@MainActor` without crashing or race conditions.

### Requirement 2: Clean Skip Behavior
1. In `MorningCheckInFlowView.swift`:
   - If user taps "Skip check-in" at step `.episode`, dismiss cleanly via `model.completeMorningCheckIn()`.
   - If user taps "Skip" on subsequent questions (`.feeling`, `.spcOutcome`, `.postEpisodeSupport`, `.sleepHelp`):
     - Advance or save whatever was answered.
     - If saving upon skipping the final question, handle any error silently or display a non-alarming dismissal, ensuring `model.feedbackMessage` does NOT display the error alert.
     - Ensure the user is transitioned to the appropriate `.affirmation(occurrence)` screen.

### Requirement 3: Conditional Matrix Flow (2-Question vs. 4-Question)
1. Ensure the step transitions strictly follow the matrix:
   ```
   [Step 1: Episode]
      ├── YES ──> [Step 2: Feeling] ──> [Step 3: SPCOutcome] ──> [Step 4: PostEpisodeSupport] ──> Affirmation (YES)
      └── NO  ──> [Step 2: SleepHelp] ──> Affirmation (NO)
   ```
2. For each step:
   - In YES branch:
     - Step 1: "QUESTION 1 OF 4" (Index 0 of 4)
     - Step 2: "QUESTION 2 OF 4" (Index 1 of 4)
     - Step 3: "QUESTION 3 OF 4" (Index 2 of 4)
     - Step 4: "QUESTION 4 OF 4" (Index 3 of 4)
   - In NO branch:
     - Step 1: "QUESTION 1 OF 2" (Index 0 of 2)
     - Step 2: "QUESTION 2 OF 2" (Index 1 of 2)

### Requirement 4: Dynamic Moon Stage Indicator
1. In `MorningCheckInHeader`:
   - Determine `totalSteps` based on `occurrence`:
     - If `occurrence == .no`, `totalSteps = 2`.
     - Otherwise (initial step or `occurrence == .yes`), `totalSteps = 4`.
   - Render dynamic moon indicators:
     ```swift
     HStack(spacing: 0) {
         ForEach(0 ..< totalSteps, id: \.self) { index in
             progressMoon(index: index, currentIndex: step.progressIndex, total: totalSteps)
             if index < totalSteps - 1 {
                 Spacer(minLength: 0)
             }
         }
     }
     .padding(.horizontal, totalSteps == 2 ? 110 : 62)
     ```
   - Visual styling:
     - `index < currentIndex`: Completed moon phase.
     - `index == currentIndex`: Active glowing moon.
     - `index > currentIndex`: Empty/unreached stroke moon.

---

## 5. Verification & Testing Plan

### Automated Unit Tests
Create or update tests in `ios/Tests/Unit/` (e.g., `MorningCheckInMatrixTests.swift`):
1. **Guest Save Test:** Verify `submitCheckIn` succeeds when `userID` is `nil` but `profileID` is valid.
2. **NO Episode Path Test:** Verify sequence is strictly 2 steps, correctly populates `occurrence = .no` and `sleepHelpOutcome`.
3. **YES Episode Path Test:** Verify sequence is strictly 4 steps, correctly populates all 4 fields.
4. **Skip Test:** Verify skipping at any step does not populate `feedbackMessage` with an error and successfully transitions to affirmation or dismisses.
5. **Moon Count Test:** Verify computed moon stage count is 2 for `.sleepHelp` and 4 for `.postEpisodeSupport`.

### GitHub Actions CI Verification
Because the workstation is Windows, run validation through GitHub Actions:
```powershell
# 1. Create and checkout the branch
git checkout -b fix/morning-checkin-matrix-and-bugs

# 2. Commit your changes
git add ios/Sources/ ios/Tests/
git commit -m "fix(checkin): correct matrix logic, fix guest save, and make moon stages dynamic"

# 3. Push and watch the hosted macOS-26 battery
git push origin fix/morning-checkin-matrix-and-bugs
gh workflow run phase-1-integrated-app.yml --ref fix/morning-checkin-matrix-and-bugs
gh run list --workflow phase-1-integrated-app.yml --limit 3
gh run watch <run-id> --exit-status
```

If any step fails, inspect logs immediately:
```powershell
gh run view <run-id> --log-failed
```

---

## 6. Definition of Done
- [ ] Check-in saves successfully in guest mode and authenticated mode.
- [ ] Skipping any question does not trigger an error alert or broken flow.
- [ ] NO branch presents exactly 2 questions total.
- [ ] YES branch presents exactly 4 questions total.
- [ ] Moon stage indicator shows 2 moons for the NO path and 4 moons for the YES path.
- [ ] All unit tests pass and hosted GitHub Actions CI run is **GREEN**.
