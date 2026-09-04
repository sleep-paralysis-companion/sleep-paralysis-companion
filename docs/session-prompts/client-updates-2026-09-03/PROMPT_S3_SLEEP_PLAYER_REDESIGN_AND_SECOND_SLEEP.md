# Session Prompt: S3 — Sleep Player Redesign & Second Sleep Decoupling

> **Session ID:** `S3-SLEEP-PLAYER-REDESIGN`  
> **Target Branch:** `feat/sleep-player-redesign-and-second-sleep`  
> **Input Authority:** Meeting notes from Sep 3, 2026 (Shraddha Rakshe & Satyam Shree).

---

## 1. Operating Contract

You are working on the Sleep Paralysis Companion iOS repository (`C:\Users\satya\Documents\paralux`).
This session is exclusively focused on **redesigning the Sleep Player (for the bedtime calm-down routine), separating it completely from "Second Sleep" (the post-episode recovery screen), implementing the vertically scrollable audio list with Quick & Slow Unwind, and auto-starting the Sleep Player upon saving an alarm schedule**.

### Repository Context & Guidelines
- **Workstation:** Windows host. All compilation, linting, and tests run on hosted GitHub Actions (`macos-26`).
- **Language / Concurrency:** Swift 6, `SWIFT_STRICT_CONCURRENCY = complete`, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`.
- **Precedence:** Depends on Session S1 and S2. Rebase on top of S2 before executing.

---

## 2. Conceptual Architecture: Sleep Player vs. Second Sleep

| Attribute | Sleep Player (Bedtime Routine) | Second Sleep (Post-Episode Recovery) |
|---|---|---|
| **Intended User Context** | Winding down and preparing for peaceful sleep at night. | Waking up disoriented/frightened after a sleep paralysis episode. |
| **Entry Points** | "Calm Your Mind" button; Auto-start after saving an alarm schedule. | "I just had an episode" button; Lock screen widget / ManualEpisodeIntent. |
| **Hero Graphic** | **None** (Hero vector removed for a clean, streamlined UI). | Minimalist, dark, low-stimulation layout. |
| **Audio Tracks** | Vertically scrollable list: "Quick Unwind" (15m) & "Slow Unwind" (1h 15m) + future tracks. | Calming voice/grounding audio ("Second Sleep" / comfort audio). |
| **UI Controls** | Direct audio list at top; Play/pause; Audio fade-away timer; Grounding quick access; Download buttons. | **Single, large Call-to-Action (CTA)** button for minimal cognitive load. |
| **Visual Artwork** | Consistent calming ambient background across tracks (no unique per-track PNG artwork needed). | High-contrast, single-action dark surface. |

---

## 3. Detailed Implementation Requirements

### Requirement 1: Streamline Sleep Player & Remove Hero Vector
- **Client Decision:**
  > *"Remove the hero vector from the Sleep Player and add direct access to audio files at the top of the interface. Streamline the player to be cleaner."*
- **Action:**
  1. Remove the large `Image("SleepSessionMoon")` hero illustration from the bedtime Sleep Player.
  2. Move the audio selection to the top of the screen for immediate, frictionless access.

### Requirement 2: Vertically Scrollable Audio Track Container
- **Client Decision:**
  > *"The sleep player audio section will be structured as a vertically scrollable container to support future additions of downloadable audio tracks. This structure will allow users to manage, download, and switch between various audio tracks within the same interface, addressing the need for a dedicated download button next to the tracks."*
  > *"The sleep player will feature two specific audios (quick unwind and slow unwind) within a consistent UI, removing the requirement for unique PNG artwork for each audio."*
- **Action:**
  1. Build a vertically scrollable track list supporting:
     - **Track 1: "Quick Unwind"** (15 minutes) — Default short bedtime calm-down.
     - **Track 2: "Slow Unwind"** (1 hour 15 minutes) — Extended deep relaxation sleep aid.
     - Future downloadable audio tracks from the catalog.
  2. Each track row must contain:
     - Play/pause state indicator.
     - Track title and duration ("15 min", "1 hr 15 min").
     - A dedicated **Download / Offline state button** next to each track (indicating whether the asset is local or downloadable, using existing `CatalogAudioService` / `CatalogAudioBoundaries`).
  3. Keep the visual artwork and background imagery **consistent across all tracks** (e.g. ambient gradient with subtle purple/indigo glow). Do not require unique per-track PNG artwork.

### Requirement 3: Retain Key Sleep Player Features
- **Client Decision:**
  > *"The sleep player will retain the grounding feature and the audio fade-away timer functionality."*
- **Action:**
  1. **Audio Fade-Away Timer:** Provide standard timer options (e.g. 15m, 30m, 45m, 60m, or end of track) that gently fades out the volume before stopping.
  2. **Grounding Quick-Access:** Provide a clear, calming button that lets the user immediately access grounding support if they feel distress.

### Requirement 4: Auto-Start Sleep Player After Saving Alarm
- **Client Decision:**
  > *"After a user creates a new schedule and saves the alarm, the application should automatically initiate the sleep player rather than requiring the user to start it manually. The background audio must default to the quick or slow unwind tracks, rather than navigating to the 'second sleep' flow."*
- **Action:**
  1. In [`ios/Sources/Features/Shell/AppRootView.swift`](file:///c:/Users/satya/Documents/paralux/ios/Sources/Features/Shell/AppRootView.swift#L178-L182) or `AppModel.saveScheduleUI`:
     - When saving an alarm schedule, trigger `model.startUnwindSession()`.
     - Automatically begin playback of the default unwind track (Quick Unwind or Slow Unwind based on user preferences).
     - Present the new Sleep Player (not Second Sleep).
  2. Ensure the "Calm Your Mind" action on HomeView navigates directly to this Sleep Player.

### Requirement 5: Second Sleep UI & iOS Platform Constraint
- **Client Decision:**
  > *"The 'second sleep' screen will retain a single, large Call-to-Action (CTA) button to ensure ease of use for users waking up from sleep paralysis episodes."*
  > *"The iOS application will proceed with the technical constraint requiring users to unlock their phones via FaceID to perform actions beyond basic play/pause."*
- **Action:**
  1. Keep the Second Sleep recovery screen focused on a single prominent CTA button (`home.manualEpisode` / Grounding).
  2. Maintain existing standard Face ID unlock semantics for locked-device transitions.

---

## 4. Files You Own vs. Do Not Touch

### Files You Own
- [`ios/Sources/Features/Sleep/SleepSessionView.swift`](file:///c:/Users/satya/Documents/paralux/ios/Sources/Features/Sleep/SleepSessionView.swift)
- [`ios/Sources/Features/Audio/AudioPlayerView.swift`](file:///c:/Users/satya/Documents/paralux/ios/Sources/Features/Audio/AudioPlayerView.swift) (or refactored `SleepPlayerView.swift`)
- [`ios/Sources/App/AppModel.swift`](file:///c:/Users/satya/Documents/paralux/ios/Sources/App/AppModel.swift) (`startUnwindSession`, `startSleepSession`, audio playback hooks)
- [`ios/Sources/Features/Home/HomeView.swift`](file:///c:/Users/satya/Documents/paralux/ios/Sources/Features/Home/HomeView.swift) ("Calm Your Mind" routing)
- [`ios/Tests/Unit/AudioPlayerTests.swift`](file:///c:/Users/satya/Documents/paralux/ios/Tests/Unit/AudioPlayerTests.swift)

### Do Not Touch
- `ios/Sources/Features/CheckIn/*` (Settled in S1)
- `ios/Sources/Features/Schedule/AlarmRingingView.swift` (Settled in S2)
- `ios/Sources/Authentication/*`
- `ios/Sources/LocalPersistence/LocalSchema.swift`

---

## 5. Verification & Testing Plan

### Automated Unit Tests
Create or update tests in `ios/Tests/Unit/` (e.g., `SleepPlayerTests.swift`):
1. **Auto-Start on Save Test:**
   - Verify that saving a schedule starts the unwind session with the default audio track (Quick Unwind or Slow Unwind).
2. **Audio Track Switch Test:**
   - Verify switching between Quick Unwind (15m) and Slow Unwind (1h 15m) updates playback and metadata properly.
3. **Fade-Away Timer Test:**
   - Verify timer fires and invokes audio fade-out gracefully.
4. **Second Sleep CTA Test:**
   - Verify Second Sleep presents single large CTA and correctly invokes manual grounding.

### Hosted CI Verification
Run verification via GitHub Actions:
```powershell
# 1. Create and checkout the branch
git checkout -b feat/sleep-player-redesign-and-second-sleep

# 2. Commit your changes
git add ios/Sources/ ios/Tests/
git commit -m "feat(player): redesign sleep player with scrollable unwind tracks and auto-start"

# 3. Push and watch the hosted macOS-26 battery
git push origin feat/sleep-player-redesign-and-second-sleep
gh workflow run phase-1-integrated-app.yml --ref feat/sleep-player-redesign-and-second-sleep
gh run list --workflow phase-1-integrated-app.yml --limit 3
gh run watch <run-id> --exit-status
```

---

## 6. Definition of Done
- [ ] Hero vector is removed from the bedtime Sleep Player.
- [ ] Direct access to audio tracks is at the top of the interface in a vertically scrollable list.
- [ ] Dedicated download/status buttons are visible next to audio tracks.
- [ ] Quick Unwind (15 min) and Slow Unwind (1 hr 15 min) are selectable with consistent ambient background imagery.
- [ ] Grounding quick action and audio fade-away timer work properly.
- [ ] Saving an alarm schedule automatically initiates the Sleep Player with default unwind audio.
- [ ] Second Sleep maintains a single, large CTA button for post-episode recovery.
- [ ] All unit tests pass and GitHub Actions `phase-1-integrated-app.yml` run is **GREEN**.
