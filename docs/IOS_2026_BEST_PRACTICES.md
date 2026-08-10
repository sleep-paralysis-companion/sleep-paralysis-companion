# iOS 2026 Engineering and App Store Best Practices

**Status:** Mandatory Phase 1 engineering and release standard  
**Applies to:** Sleep Paralysis Companion Phase 1 iPhone application
**Verified against official Apple documentation:** 20 July 2026  
**Primary platform:** Native Swift and SwiftUI  
**Backend:** Supabase  
**Public web/support hosting:** Vercel

## Purpose

This document defines the minimum platform, privacy, quality, accessibility, and App Store standards every agent must follow. It is project-specific and must be read with the [Phase 1 execution plan](./PHASE_1_EXECUTION_PLAN.md) and [Swift/SwiftUI engineering standard](./SWIFT_SWIFTUI_BEST_PRACTICES.md).

**Must** identifies a release-blocking requirement. **Should** identifies the default unless an approved architecture decision explains and validates an exception.

## 1. The 2026 platform baseline

### 1.1 Build SDK and deployment target are separate decisions

As of 28 April 2026, iOS and iPadOS apps uploaded to App Store Connect must be built with the iOS and iPadOS 26 SDK or later. This is a **build SDK rule**; it does not automatically set the app's minimum supported iOS version.

Apple distinguishes:

- **SDK:** The platform APIs made available by the selected Xcode toolchain.
- **Deployment target:** The earliest operating-system version on which the built app is allowed to run.

Official sources:

- [Submitting apps to the App Store](https://developer.apple.com/app-store/submitting/)
- [Upcoming SDK minimum requirements](https://developer.apple.com/news/?id=ueeok6yw)
- [Xcode support and compatibility](https://developer.apple.com/support/xcode)

Rules:

- Release builds must use a stable Xcode version currently accepted by App Store Connect.
- Pin the exact Xcode, Swift, SDK, Swift language mode, and deployment target in automation and release records.
- Do not make a beta Xcode or beta OS a production dependency without an approved decision and App Store eligibility proof.
- Recheck Apple's upload requirements before every submission; this document is a dated baseline, not a permanent substitute for current requirements.

### 1.2 Minimum supported iOS version for SP

AlarmKit is available on iOS/iPadOS 26 and later. If one uniform, system-level alarm experience is a non-negotiable Phase 1 promise, **iOS 26 is the recommended minimum deployment target**.

If the product supports an earlier iOS version:

- Availability-gate every AlarmKit reference.
- Design, implement, and test an explicit earlier-OS fallback.
- Do not describe an ordinary `UserNotifications` reminder as equivalent to an AlarmKit alarm. AlarmKit can break through Focus and silent mode; ordinary notifications cannot promise the same behavior.
- Explain the difference in onboarding, help content, and App Review notes.
- Keep separate acceptance tests for each behavior path.

The final minimum target must be locked after the physical-device feasibility gate, not selected from Figma assumptions.

Official sources: [AlarmKit](https://developer.apple.com/documentation/AlarmKit), [Wake up to the AlarmKit API](https://developer.apple.com/videos/play/wwdc2025/230/)

## 2. Product and App Review posture

SP Phase 1 is a wellness and grounding product. It must not claim to diagnose, detect, predict, prevent, treat, cure, or medically reduce sleep paralysis.

Apple applies additional scrutiny to medical apps that could provide inaccurate information or be used for diagnosis or treatment. Metadata, screenshots, onboarding, extensions, notifications, paywalls, and support pages must all match the binary and the approved wellness positioning.

Phase 1 must not ship:

- A paralysis risk score or disguised equivalent.
- Automatic episode detection.
- Continuous overnight microphone monitoring.
- Unsupported health predictions.
- Claims that the app reduces, prevents, or treats episodes.
- A “Guardian Mode,” “SOS,” or emergency-response promise.
- Screenshots or descriptions showing functionality absent from the reviewed build.

Permitted positioning includes sleep preparation, user-selected calming audio, manually invoked grounding, optional morning reflection, and descriptive user-entered history.

Official source: [App Review Guidelines, including Safety and Accurate Metadata](https://developer.apple.com/app-store/review/guidelines/)

### 2.1 Review-readiness rules from the start

Apple expects a final, stable app with complete review access. Throughout development:

- Keep backend services and review URLs live for submitted builds.
- Maintain a deterministic demo/reviewer path for account-gated features.
- Keep support and privacy-policy URLs functional without authentication.
- Put beta builds through TestFlight; do not submit a demonstrator or incomplete build as production.
- Do not hide functionality from review behind undocumented gestures, flags, geofences, or credentials.
- Make metadata and screenshots describe exactly what the build does.

Official sources: [Preparing for App Review](https://developer.apple.com/app-store/review/), [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)

## 3. Application lifecycle and architecture

### 3.1 SwiftUI lifecycle

Use the SwiftUI `App` lifecycle and scene-based organization. Initialize only what is needed to render the initial interface; defer noncritical work.

The app must not assume that it continues running while offscreen. Persist important state before suspension and reconstruct it deterministically at launch.

Official sources: [SwiftUI App organization](https://developer.apple.com/documentation/swiftui/app-organization), [SwiftUI App](https://developer.apple.com/documentation/SwiftUI/App), [SwiftUI apps overview](https://developer.apple.com/documentation/technologyoverviews/swiftui)

### 3.2 Architectural boundaries

Separate:

- Presentation and navigation.
- Domain rules and approved personalization logic.
- Local persistence.
- Supabase synchronization and authentication.
- Audio playback.
- AlarmKit, UserNotifications, App Intents, and WidgetKit adapters.
- StoreKit entitlement handling.
- Privacy, export, and deletion operations.
- Privacy-safe diagnostics.

SwiftUI views must not call Supabase, StoreKit, AlarmKit, AVFoundation, or persistence APIs directly. Platform/backend behavior belongs behind focused interfaces so domain rules can be tested without a live device service, network, or App Store account.

Apple does not require a named presentation pattern. Prefer explicit ownership, single sources of truth, dependency injection, and testability over ceremonial layers.

Official sources: [Managing model data in your app](https://developer.apple.com/documentation/SwiftUI/Managing-model-data-in-your-app), [SwiftUI model data](https://developer.apple.com/documentation/swiftui/model-data)

### 3.3 Local-first core flow

SQLite/GRDB is the immediate data source for core Phase 1 screens. Supabase availability must not be required for:

- Previously configured sleep preparation.
- Locally available audio playback.
- Manual grounding entry.
- Episode/check-in creation.
- Local history review.

Every synchronizable record needs a stable client-generated identifier, ownership, creation/modification metadata, sync state, an idempotent upload contract, a deterministic conflict rule, and defined deletion propagation.

Failed synchronization must preserve local user data and retry safely. The UI may show local/synchronizing/failed state where useful, but a network problem must not block the support flow.

### 3.4 Background execution

Background execution is system-controlled and is not an exact scheduler. Use the platform mechanism that matches the job:

| Need | Correct mechanism |
|---|---|
| User-visible alarm on iOS 26+ | AlarmKit |
| Ordinary reminder | UserNotifications |
| Deferrable refresh/maintenance | Background Tasks |
| Eligible long transfer | Background `URLSession` |
| Active user-selected audio playback | AVAudioSession plus the Audio background mode |

Rules:

- Background tasks must support expiration and cancellation.
- Jobs must be idempotent and resumable.
- Enable a background mode only when its approved feature genuinely uses it.
- Do not substitute background refresh or push for an alarm.
- Do not keep the process alive using silent audio, busy work, or continuous microphone access.
- Force quit, suspension, network loss, and termination must not corrupt state.

Official sources: [Choosing background strategies](https://developer.apple.com/documentation/BackgroundTasks/choosing-background-strategies-for-your-app), [Using background tasks](https://developer.apple.com/documentation/uikit/using-background-tasks-to-update-your-app), [Extending background execution](https://developer.apple.com/documentation/uikit/extending-your-app-s-background-execution-time)

## 4. Privacy and security

Treat profile answers, episode records, check-ins, identifiers, account data, and usage history as sensitive wellness information. Minimize them even when a jurisdiction does not classify them as medical data.

### 4.1 Data minimization and transparency

Before adding a field, event, permission, SDK, or transfer, document:

- The approved user-facing purpose.
- Whether it remains on the device or leaves it.
- Local and Supabase storage locations.
- Identity linkage.
- Retention, export, and deletion behavior.
- App Store privacy category.
- Analytics prohibition or approved aggregation.

Do not use wellness/episode data for advertising, tracking, data brokerage, or behavioral targeting. Do not collect information because it might be useful later.

Official sources: [User privacy and data use](https://developer.apple.com/app-store/user-privacy-and-data-use/), [App Review Guidelines section 5.1](https://developer.apple.com/app-store/review/guidelines/), [Privacy Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/privacy)

### 4.2 Supabase security

The iOS binary may contain a Supabase project URL and publishable/anonymous client key when used as designed. It must never contain:

- Supabase service-role keys or database passwords.
- Apple private keys or App Store Connect API keys.
- Signing certificates.
- Vercel tokens.
- Server webhook or entitlement-validation secrets.

Every user-owned table must use Row Level Security with tested least-privilege policies. Private files must use private buckets and authorization; client-supplied ownership, administrative status, or entitlement state is never trusted as server authority.

Development, staging, and production must use separate resources. Production data must not be copied into development tooling or AI prompts.

### 4.3 On-device secrets and files

Store access/refresh tokens and small credentials in Keychain Services, not `UserDefaults`, source, logs, or ordinary database columns.

Official sources: [Keychain Services](https://developer.apple.com/documentation/security/keychain-services), [Storing keys in Keychain](https://developer.apple.com/documentation/security/storing-keys-in-the-keychain)

Choose file protection intentionally:

- Prefer complete protection for private data not needed while locked.
- If approved grounding audio must be available while locked, use the least permissive protection class that passes the verified behavior.
- Test after reboot both before and after first unlock.
- Do not weaken the entire store because one asset needs different availability.
- Treat regenerable downloads as cache or exclude them from backup as appropriate.

Official sources: [File protection types](https://developer.apple.com/documentation/foundation/fileprotectiontype), [Optimizing app data for iCloud Backup](https://developer.apple.com/documentation/foundation/optimizing-your-app-s-data-for-icloud-backup)

### 4.4 Network security

Keep App Transport Security enabled and use HTTPS. Do not add broad arbitrary-load exceptions. Fix or replace a noncompliant endpoint instead of weakening transport security for the app.

Official source: [NSAppTransportSecurity](https://developer.apple.com/documentation/bundleresources/information-property-list/nsapptransportsecurity)

### 4.5 Privacy manifests and required-reason APIs

The app and applicable bundled SDKs must include valid `PrivacyInfo.xcprivacy` manifests. These describe collected data, tracking domains, and required-reason API use.

Before each release:

- Inventory every direct and transitive dependency/binary.
- Verify required SDK privacy manifests and signatures.
- Review SDK data collection and network endpoints.
- Remove unused dependencies.
- Declare only approved reasons for required-reason APIs actually used.
- Generate and inspect Xcode's aggregate Privacy Report from the archive.
- Reconcile the report with App Store privacy answers and the public policy.
- Treat a dependency update as privacy and supply-chain review work.

Official sources: [Privacy manifest files](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files), [Describing data use](https://developer.apple.com/documentation/BundleResources/describing-data-use-in-privacy-manifests), [Required-reason APIs](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api), [Third-party SDK requirements](https://developer.apple.com/support/third-party-SDK-requirements/)

### 4.6 App privacy disclosures

A public privacy-policy URL is required for iOS apps. App Store Connect answers must include the behavior of the app and its third-party partners.

The privacy policy must accurately explain:

- Guest and account behavior.
- On-device versus Supabase storage.
- Wellness and episode/check-in data.
- Purchase and diagnostic data.
- Retention, export, individual deletion, and account deletion.
- Support/contact route.

The policy, privacy manifest, data inventory, Supabase schema, observed traffic, and App Store label must agree.

Official sources: [Manage app privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy), [App privacy details](https://developer.apple.com/app-store/app-privacy-details/)

## 5. Permissions and capabilities

Request a permission only in context, after the user chooses a feature that needs it. Purpose strings must be specific and understandable. Do not request protected resources on first launch for convenience.

Every permission requires tests for not determined, allowed, denied, restricted where applicable, later revoked, app reinstalled, and Settings changed while the app is backgrounded.

### 5.1 AlarmKit authorization

AlarmKit requires per-app authorization and `NSAlarmKitUsageDescription`. A missing purpose description prevents the intended operation.

The app must:

- Explain the user benefit before the system prompt.
- Ask when the user enables the alarm feature.
- Check authorization before scheduling.
- Confirm system scheduling success before showing an active alarm.
- Provide a clear denied state and route to Settings.
- Reconcile authorization changes while running.

Official sources: [AlarmKit usage description](https://developer.apple.com/documentation/BundleResources/Information-Property-List/NSAlarmKitUsageDescription), [AlarmKit authorization](https://developer.apple.com/documentation/alarmkit/alarmmanager/requestauthorization%28%29)

### 5.2 Notification authorization

Morning reminders use UserNotifications and have authorization separate from AlarmKit. Ask in the context of enabling the first relevant reminder. Inspect current settings because users can later change overall and per-alert behavior.

Never represent a notification as guaranteed when authorization, sounds, Focus, or quiet delivery can alter it.

Official source: [Asking permission to use notifications](https://developer.apple.com/documentation/UserNotifications/asking-permission-to-use-notifications)

### 5.3 Microphone and other protected resources

Current Phase 1 does not require a microphone, HealthKit, contacts, location, camera, photos, Bluetooth, or tracking permission. Do not add their usage-description keys “just in case” and do not trigger their prompts.

If an approved scope change later adds personal audio recording, it must first define explicit initiation, visible recording state, local/remote storage, consent, retention, export, deletion, file protection, interruption handling, and a non-recording fallback. It must never become overnight or background monitoring.

Apple requires explicit consent and a clear indication when recording user activity. Official source: [App Review Guidelines section 2.5.14](https://developer.apple.com/app-store/review/guidelines/)

### 5.4 Permission-denial rule

A denied optional permission must yield a stable, truthful, non-coercive fallback. Do not repeatedly prompt, hide unrelated functionality, or use a fake system dialog. Show a Settings link only after the system prompt has been denied and only where permission is necessary.

## 6. AlarmKit, Lock Screen, WidgetKit, and App Intents

### 6.1 AlarmKit

AlarmKit alarms can appear on the Lock Screen, Dynamic Island, StandBy, and paired Apple Watch surfaces and can break through silent mode and Focus. This does not authorize the app to make broader claims than its tested configuration supports.

Rules:

- Give every alarm a stable identifier.
- Persist the user's intended schedule separately from the system alarm object.
- Reconcile app state with the system's alarms and updates.
- Treat schedule, cancel, pause, resume, stop, and snooze operations as fallible.
- Prevent duplicates on launch, synchronization, and repeated taps.
- Keep Lock Screen titles concise and nonsensitive.
- Do not expose episode details, profile answers, or private history on glanceable surfaces.
- Explain AlarmKit setup and behavior in App Review notes.

Official sources: [AlarmKit documentation](https://developer.apple.com/documentation/AlarmKit), [Wake up to AlarmKit](https://developer.apple.com/videos/play/wwdc2025/230/)

### 6.2 Manual episode action

The safest Phase 1 design is a user-initiated App Intent/control/widget/deep link that opens or starts the approved grounding experience. It must never imply automatic detection.

The feasibility report must establish:

- Which surface is available on each supported OS.
- Whether unlock or authentication is required.
- Whether the app launches or an extension can complete useful work.
- What happens offline or after process termination.
- How repeated activation behaves.
- What private information is visible while locked.

Marketing may describe only the behavior that this real-device matrix proves.

### 6.3 App Intents

App Intents are lightweight wrappers around existing domain operations and must remain correct when invoked outside the foreground app or in an extension process.

- Use an opening intent when app UI is required.
- Make operations idempotent.
- Validate parameters and authorization at execution.
- Handle cancellation and unavailable dependencies.
- Avoid hidden network dependence for grounding entry.
- Return understandable failure outcomes.
- Test locked, unlocked, offline, terminated, and repeated invocation.

Official source: [Creating your first App Intent](https://developer.apple.com/documentation/appintents/creating-your-first-app-intent)

### 6.4 Widget and Live Activity privacy

Widget extensions have separate process limits and a system-controlled refresh budget. Prepare minimum shared state in advance and reload only when displayed data changes.

Lock Screen and Live Activity content can be seen by other people. Display neutral wording, redact sensitive content, and open the app for private details.

Use an App Group only for the smallest shared state needed by app and extension. Do not put privileged credentials or an unrestricted user database in the group container.

Official sources: [Keeping a widget up to date](https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date/), [WidgetKit strategy](https://developer.apple.com/documentation/WidgetKit/Developing-a-WidgetKit-strategy), [Configuring App Groups](https://developer.apple.com/documentation/xcode/configuring-app-groups), [Live Activities HIG](https://developer.apple.com/design/human-interface-guidelines/live-activities)

## 7. Audio and background playback

For user-selected sleep or grounding audio, use an audio-session category that matches actual playback behavior.

Requirements:

- Activate AVAudioSession only when playback starts or preparation genuinely needs it.
- Relinquish/deactivate the session when appropriate after playback ends.
- Enable the Audio background mode only for genuine, active user-selected playback.
- Never use silent audio to remain alive.
- Supply accurate Now Playing metadata where the experience is controllable from system surfaces.
- Support applicable Lock Screen/headset play and pause actions.
- Drive UI from actual player state.
- Keep approved audio locally available before promising offline grounding.
- Validate downloaded content before atomically replacing a valid cached asset.
- Provide readable/visual equivalents for essential spoken cues.

Phone calls, Siri, alarms, device lock, and other apps can interrupt audio. Observe interruptions and route changes; resume only when the system indicates it is appropriate and prior user intent supports it. Pause on headphone disconnection to avoid unexpectedly playing private content through speakers.

Do not claim immediate playback from every locked-device state until that exact flow passes the physical-device matrix.

Official sources: [AVAudioSession](https://developer.apple.com/documentation/avfaudio/avaudiosession), [Configuring media playback](https://developer.apple.com/documentation/avfoundation/configuring-your-app-for-media-playback), [Handling audio interruptions](https://developer.apple.com/documentation/avfaudio/handling-audio-interruptions), [Responding to route changes](https://developer.apple.com/documentation/avfaudio/responding-to-audio-route-changes), [Becoming a Now Playable app](https://developer.apple.com/documentation/MediaPlayer/becoming-a-now-playable-app)

## 8. Accounts, authentication, and deletion

Apple says that if significant account-based functionality is not required, users should be able to use the app without login. The local alarm and core grounding path must not require identity solely to collect user data.

If Google, Facebook, or another third-party/social login is offered for the primary account, satisfy Apple's equivalent-login requirement under Guideline 4.8. Sign in with Apple is the usual solution. An app using only its own account system is covered by the guideline's stated exception.

Official sources: [App Review Guidelines sections 4.8 and 5.1.1](https://developer.apple.com/app-store/review/guidelines/), [Implementing Sign in with Apple](https://developer.apple.com/documentation/authenticationservices/implementing_user_authentication_with_sign_in_with_apple)

Any app that supports account creation must let users initiate complete account deletion in the app. Temporary deactivation is not sufficient.

Deletion must:

- Be easy to find in account settings.
- Explain what will be deleted and any legitimately retained data.
- Reauthenticate where appropriate without needless obstruction.
- Delete the Supabase Auth identity and associated deletable database/storage content.
- Remove local credentials and private account data.
- Revoke Sign in with Apple tokens when applicable.
- Explain that deleting an account does not automatically cancel an Apple subscription.
- Allow deletion even if a subscription remains active.
- Confirm completion or show an honest processing state.

Official source: [Offering account deletion in your app](https://developer.apple.com/support/offering-account-deletion-in-your-app/)

## 9. StoreKit and premium access

If Phase 1 unlocks premium digital functionality inside iOS, use Apple In-App Purchase unless a documented guideline exception applies. Do not substitute a Vercel/Polar/Stripe checkout inside the app for digital feature access.

Use StoreKit 2 and verified App Store-signed transactions.

Requirements:

- Start the transaction-update listener early in app launch.
- Derive on-device access from verified current entitlements.
- Never unlock from an unverified client or Supabase row claim.
- Deliver access before finishing a verified transaction.
- Make handling idempotent by transaction/original-transaction identifiers.
- Handle pending, cancelled, failed, deferred, refunded, revoked, expired, grace-period, billing-retry, upgrade, and downgrade states.
- Provide an obvious Restore Purchases action.
- Use `AppStore.sync()` only after an explicit user restore action because it can show authentication UI.
- Provide subscription-management access.
- Never hard-code localized product price or trial terms; display StoreKit product data.
- Keep privacy, account deletion, export, legal information, and purchase restoration outside paywalls.

When the backend enforces entitlements, use App Store Server Notifications V2 or the App Store Server API through trusted Supabase server logic. Verify signed payloads, separate sandbox/production, deduplicate, and never trust a client-written entitlement record.

Official sources: [App Review Guidelines section 3.1.1](https://developer.apple.com/app-store/review/guidelines/), [StoreKit](https://developer.apple.com/storekit/), [In-App Purchase](https://developer.apple.com/documentation/storekit/in-app-purchase), [Transaction updates](https://developer.apple.com/documentation/storekit/transaction/updates), [Current entitlements](https://developer.apple.com/documentation/storekit/transaction/currententitlements), [AppStore sync](https://developer.apple.com/documentation/storekit/appstore/sync%28%29), [App Store Server Notifications](https://developer.apple.com/documentation/appstoreservernotifications/enabling-app-store-server-notifications)

Test first with a StoreKit configuration, then Sandbox and TestFlight. Include interrupted purchase, Ask to Buy, renewal, billing retry, grace period, cancellation, refund, restore, reinstall, and multi-device scenarios.

Official sources: [Testing purchases in Xcode](https://developer.apple.com/documentation/storekit/testing-in-app-purchases-in-xcode), [Testing with Sandbox](https://developer.apple.com/documentation/storekit/testing-in-app-purchases-with-sandbox)

## 10. Human Interface Guidelines and accessibility

### 10.1 Onboarding and permissions

Apple recommends onboarding that is fast, focused, interactive, and optional where possible. Defer nonessential setup; provide useful defaults; request permissions in context; do not lead with a purchase or rating request before the user experiences value.

Official source: [Onboarding HIG](https://developer.apple.com/design/human-interface-guidelines/onboarding)

### 10.2 Calm and recoverable interaction

For this app's night flow:

- Present one clear primary action at a time.
- Minimize reading, branching, precision gestures, and visual motion.
- Avoid alarming red/error styling unless there is a real destructive or safety concern.
- Make destructive actions explicit, confirmed, and recoverable where possible.
- Never trap the user in a modal flow.
- Use system alerts only for important information requiring attention or a choice.

Official source: [Alerts HIG](https://developer.apple.com/design/human-interface-guidelines/alerts)

### 10.3 Accessibility is a completion criterion

Every critical Phase 1 workflow must remain usable with:

- VoiceOver.
- Voice Control.
- Switch Control where applicable.
- All Dynamic Type accessibility sizes.
- Increased Contrast and Differentiate Without Color.
- Reduce Motion.
- Bold Text and Button Shapes.
- Dark appearance.

Requirements:

- Prefer semantic system controls.
- Give custom actions meaningful labels, roles, values, hints, and focus behavior.
- Hide decorative imagery from accessibility traversal.
- Preserve a logical reading order.
- Do not encode alarm, sync, error, or selected state using color alone.
- Let text expand without blocking controls or clipping essential content.
- Respect Reduce Motion; avoid rapid, blinking, zooming, or disorienting cosmic effects.
- Provide visible/text equivalents for essential audio cues.
- Keep controls comfortably sized and separated.
- Test the entire preparation, grounding, check-in, purchase/restore, export, and deletion paths without relying on sight.

Run Accessibility Inspector and automated audits, but also test manually with assistive technologies.

Official sources: [Accessibility HIG](https://developer.apple.com/design/human-interface-guidelines/accessibility), [SwiftUI accessibility fundamentals](https://developer.apple.com/documentation/swiftui/accessibility-fundamentals), [Performing accessibility audits](https://developer.apple.com/documentation/accessibility/performing-accessibility-audits-for-your-app)

## 11. Localization and user-facing content

- Put all user-facing strings in String Catalogs.
- Use complete localizable messages; never concatenate translated sentence fragments.
- Use plural variants and locale-aware formatting.
- Support right-to-left layout and long translations.
- Use the user's locale/calendar for display while storing schedules and instants unambiguously.
- Distinguish an absolute instant from a recurring local wall-clock sleep schedule.
- Test 12/24-hour settings, time-zone changes, daylight-saving transitions, right-to-left layout, and pseudolocalization.
- Keep wellness copy in an approved, reviewable content catalog.

Official sources: [Xcode localization](https://developer.apple.com/documentation/xcode/localization), [String Catalogs](https://developer.apple.com/documentation/xcode/localizing-and-varying-text-with-a-string-catalog), [Preparing text for translation](https://developer.apple.com/documentation/xcode/preparing-your-apps-text-for-translation)

## 12. Performance, reliability, energy, and diagnostics

The main thread must remain responsive and launch work must be minimal.

- Do not perform migrations, disk/file operations, network calls, heavy decoding, image work, or audio processing synchronously on the main actor.
- Paginate or lazily render long history.
- Batch appropriate disk and synchronization work.
- Avoid polling Supabase.
- Avoid needless widget reloads, timers, background wakes, and network requests.
- Profile real workflows on physical devices, including the oldest supported device.
- Use Instruments for SwiftUI updates, hangs, CPU, memory, allocations/leaks, network, disk, audio, and energy.
- Review Xcode Organizer and MetricKit diagnostics for release builds.
- Establish measured regression tests for launch-critical work, schedule calculations, database access, alarm reconciliation, grounding entry, and history rendering.

Official sources: [Improving app responsiveness](https://developer.apple.com/documentation/xcode/improving-app-responsiveness), [Performance and metrics](https://developer.apple.com/documentation/xcode/performance-and-metrics), [Reducing launch time](https://developer.apple.com/documentation/xcode/reducing-your-app-s-launch-time), [Reducing memory use](https://developer.apple.com/documentation/xcode/reducing-your-app-s-memory-use), [MetricKit](https://developer.apple.com/documentation/metrickit)

### 12.1 Privacy-safe observability

Use Apple's unified logging with clear subsystem/categories. Dynamic sensitive values must remain private or be omitted.

Never log:

- Access/refresh tokens or signed URLs.
- Emails, phone numbers, or direct identifiers.
- Onboarding answers, check-in details, or free text.
- Private file paths or raw backend payloads.
- Raw StoreKit signed payloads.

Use signposts for measured operations such as launch-critical work, sync, database migration, alarm reconciliation, and audio start.

Official sources: [Generating log messages](https://developer.apple.com/documentation/os/generating-log-messages-from-your-code), [OSSignposter](https://developer.apple.com/documentation/os/ossignposter), [Acquiring diagnostics](https://developer.apple.com/documentation/xcode/acquiring-crash-reports-and-diagnostic-logs)

Any third-party crash/analytics SDK must pass dependency, privacy-manifest, retention, disclosure, and data-minimization review before adoption.

## 13. Testing strategy

Use many isolated unit tests, focused integration tests, and a smaller set of critical end-to-end UI tests. Swift Testing is suitable for new domain/service tests; XCTest/XCUIAutomation remains appropriate for UI and performance automation.

Required coverage includes:

- Onboarding/personalization truth tables.
- Alarm and recurring schedule calculations across locale/time changes.
- Local database migrations.
- Synchronization conflict, retry, deletion, and idempotency.
- Supabase Row Level Security and Storage isolation.
- Audio state/interruption behavior.
- App Intent and widget behavior.
- StoreKit entitlements if monetization is enabled.
- Export and account deletion.
- Critical UI paths and permission-denied paths.
- Accessibility audits.
- Performance regressions.
- Failure injection for network, storage, backend, and system-service errors.

Official sources: [Testing in Xcode](https://developer.apple.com/documentation/xcode/testing), [Swift Testing](https://developer.apple.com/documentation/Testing), [Organizing tests with test plans](https://developer.apple.com/documentation/xcode/organizing-tests-to-improve-feedback)

### 13.1 Physical-device matrix

At minimum, cover applicable combinations of:

- Earliest and latest supported stable iOS versions.
- Oldest supported and current iPhone hardware classes.
- Dynamic Island and non-Dynamic-Island hardware where supported.
- Small and large displays.
- Locked/unlocked and app foreground/background/terminated.
- Silent mode and multiple Focus modes.
- Low Power Mode and storage pressure.
- Airplane mode, no/poor/restored network, and Supabase outage.
- Fresh install, upgrade, reinstall, and account transition.
- Time zone, daylight-saving, 12/24-hour, and manual clock changes.
- Reboot before and after first unlock.
- Alarm/notification permission allowed, denied, and revoked.
- Speaker, wired, Bluetooth, and AirPlay routes where supported.
- Incoming call, Siri, another app taking audio, and alarm during playback.
- VoiceOver, large text, Reduce Motion, increased contrast, and right-to-left layout.

### 13.2 TestFlight

Use TestFlight for representative internal and external testing. Each build needs focused “What to Test” instructions and traceability to source, migrations, configuration, and known issues.

Apple currently documents up to 100 internal and 10,000 external testers, with builds available for up to 90 days; the first external build may require beta review. Recheck these limits when configuring the program.

Official source: [TestFlight overview](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/)

## 14. App Store submission

Before review, the submitted app must be final, stable, accurately described, reachable, and fully reviewable.

The submission package needs:

- An archive built with an accepted stable Xcode and required SDK.
- Correct bundle ID, version, unique build number, signing, capabilities, and entitlements.
- Accurate name, subtitle, description, category, age rating, screenshots, and preview assets.
- Accurate App Privacy answers.
- Public privacy and support URLs.
- In-app account deletion if accounts can be created.
- Accurate paid-feature disclosure and submitted/reviewable In-App Purchases, if applicable.
- Export-compliance answers.
- A working reviewer account or a full-featured demo mode.
- Live backend and public URLs.
- Complete notes for non-obvious system behavior.

SP review notes must explain:

- Wellness-only positioning.
- That episodes are user-reported and never automatically detected.
- AlarmKit authorization/setup and earlier-OS fallback if applicable.
- The Lock Screen/manual action and any unlock limitations.
- Notification and audio behavior.
- Offline capability and any initial download requirement.
- Premium purchase/restoration path, if present.
- Account and data-deletion path.
- Any feature needing a particular device or state.

No placeholder copy, empty website, unavailable product, dead backend, hidden feature, or development bypass may be present.

Official sources: [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/), [App Review overview](https://developer.apple.com/app-store/review/), [Submitting an app](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-app)

## 15. Release gates

### Platform and build

- [ ] Built with an App Store-supported stable Xcode and iOS 26-or-later SDK.
- [ ] Deployment-target decision and fallback matrix recorded.
- [ ] App and extensions build without unreviewed warnings.
- [ ] Archive validates in Organizer.
- [ ] Version/build identifiers, signing, capabilities, and entitlements are correct.
- [ ] No privileged secret is embedded.

### Functionality and reliability

- [ ] Complete preparation → manual grounding → morning flow passes on physical devices.
- [ ] Alarm/system state reconciles after termination and reboot.
- [ ] Offline core flow passes.
- [ ] Audio interruption and route matrix passes.
- [ ] Synchronization recovers without loss or duplication.
- [ ] No open release-blocking defect remains.

### Privacy and security

- [ ] RLS/Storage-isolation tests pass for every user-owned object.
- [ ] Keychain and file-protection choices are verified.
- [ ] ATS has no unjustified exception.
- [ ] Privacy manifest validates.
- [ ] Required-reason APIs use approved reasons.
- [ ] Third-party SDK manifests/signatures are verified.
- [ ] Xcode Privacy Report matches App Store answers and policy.
- [ ] Logs and diagnostics contain no sensitive user data.
- [ ] Export, record deletion, and account deletion pass end to end.

### Purchases, when applicable

- [ ] Products are available and reviewable.
- [ ] Local StoreKit, Sandbox, and TestFlight matrices pass.
- [ ] Transaction verification/update handling passes.
- [ ] Restore Purchases passes.
- [ ] Server notifications pass in sandbox and production configuration.
- [ ] Refund, expiry, grace period, billing retry, and revocation update access correctly.

### Accessibility and quality

- [ ] Critical workflows pass with VoiceOver.
- [ ] All supported Dynamic Type sizes leave every critical task operable.
- [ ] Reduce Motion behavior is complete.
- [ ] Contrast and color-independent states pass.
- [ ] Automated accessibility audits pass.
- [ ] Launch, responsiveness, memory, disk, network, audio, and energy have been profiled.
- [ ] TestFlight findings and crash/hang reports are resolved or accepted with evidence.

### App Store readiness

- [ ] Metadata/screenshots match the binary.
- [ ] Wellness wording contains no unsupported medical claim.
- [ ] Privacy, terms, support, and deletion URLs are live on Vercel.
- [ ] Production Supabase services are live.
- [ ] Reviewer access works.
- [ ] Review notes explain permissions, alarms, manual action, purchases, offline behavior, and deletion.
- [ ] Final release walkthrough passes on physical devices.

## 16. Maintenance rule

Before every App Store submission, the release owner must recheck:

- [Submitting apps](https://developer.apple.com/app-store/submitting/)
- [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Xcode support](https://developer.apple.com/support/xcode)
- [Third-party SDK requirements](https://developer.apple.com/support/third-party-SDK-requirements/)
- [App Store Connect release notes](https://developer.apple.com/help/app-store-connect/release-notes/)

If current Apple documentation conflicts with this guide, stop the release, record the changed requirement, update the standard, and revalidate affected work before continuing.
