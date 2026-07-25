# Swift and SwiftUI Engineering Best Practices — 2026

**Status:** Required Phase 1 engineering standard  
**Last reviewed:** 20 July 2026  
**Applies to:** SP native iOS application, app extensions, shared Swift packages, and test targets

## Purpose

This document defines how agents and developers must write, review, and test Swift and SwiftUI code for SP. It supplements the [Phase 1 execution plan](./PHASE_1_EXECUTION_PLAN.md) and the [iOS 2026 best-practices guide](./IOS_2026_BEST_PRACTICES.md).

The words **MUST**, **MUST NOT**, **SHOULD**, and **SHOULD NOT** describe project requirements. When project code needs to depart from a rule, the pull request must explain why and how the alternative remains safe, testable, and maintainable.

## 1. Toolchain and language baseline

- Use the latest stable Xcode and Swift toolchain accepted by App Store Connect. Pin the exact Xcode and Swift versions in automation and project documentation.
- Build project-owned targets in Swift 6 language mode with complete data-race checking.
- For the primarily UI-facing app target, use the stable toolchain's approachable-concurrency settings and default actor isolation to `MainActor`, where supported and validated.
- Treat compiler concurrency diagnostics as design feedback. Do not silence them with `@unchecked Sendable`, `nonisolated(unsafe)`, `@preconcurrency`, detached tasks, or dispatch queues unless the boundary has been reviewed and documented.
- Project-owned code must build without warnings. New warnings fail the build check.
- Preview or beta Xcode/Swift features must not become production requirements without an approved architecture decision. WWDC material can describe upcoming features that are not in the stable production toolchain.
- Prefer platform and standard-library APIs over custom infrastructure when they satisfy the requirement.

References: [Swift 6 migration guide](https://www.swift.org/migration/), [Swift 6 data-race safety](https://www.swift.org/migration/documentation/swift-6-concurrency-migration-guide/dataracesafety/), [Swift 6.2 release](https://www.swift.org/blog/swift-6.2-released/), [What's new in Swift — WWDC26](https://developer.apple.com/videos/play/wwdc2026/262/)

## 2. Swift API design

Follow Swift's official principle that clarity at the point of use is more important than brevity.

- Names must describe intent and domain meaning. Do not use vague names such as `Manager`, `Helper`, `Util`, `Data`, `Info`, or `handle()` without a more specific role.
- Types and protocols use `UpperCamelCase`; functions, properties, variables, and enum cases use `lowerCamelCase`.
- Function names should read naturally at the call site.
- Prefer positive Boolean names such as `isEnabled`, `hasCachedAudio`, and `canRestorePurchase`.
- When a choice has more than two meaningful states, use an enum instead of multiple Booleans.
- Avoid Boolean parameters whose meaning is unclear at the call site. Prefer a labeled enum or separate operation.
- Put parameters with default values after required parameters.
- Use `let` by default. Introduce `var` only when mutation is required.
- Keep declarations at the narrowest practical access level. Default to `private` or module-internal visibility.
- Public or cross-feature APIs must have DocC-compatible documentation describing behavior, errors, cancellation, isolation, privacy implications, and non-obvious complexity.
- Computed properties that are not constant-time must document their complexity or become methods.
- Do not expose storage or transport implementation details through domain APIs.

Reference: [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/)

## 3. Value types, reference types, and ownership

### Prefer value semantics

Use structs and enums for:

- Domain values and immutable snapshots.
- Supabase request/response data-transfer objects.
- Database row representations.
- Navigation routes.
- Settings values.
- Events and commands.
- Errors.
- Test fixtures.

Value types reduce unintended shared mutation and are usually naturally `Sendable` when their members are `Sendable`. A copied struct is not automatically a deep copy if it contains reference-typed properties; review nested ownership rather than assuming independence.

### Use classes deliberately

Use a class only when the model requires:

- Stable reference identity.
- Shared mutable lifetime.
- Framework-mandated reference semantics.
- An observable UI model whose identity must survive view recomputation.

Classes should normally be `final`. Do not use inheritance as a reuse mechanism unless substitutability is a genuine domain requirement.

Use `weak` references to break confirmed retain cycles, not as a reflex. Task lifetime and cancellation should be explicit rather than hidden behind repeated `[weak self]` usage.

### Use actors for isolated mutable state

Use an actor when mutable state must be safely accessed by independent tasks, such as a synchronization coordinator, cache, or database boundary.

Actor methods can be reentrant at every `await`. After an `await`, recheck assumptions before mutating state or committing a result.

Reference: [Structures and Classes](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/classesandstructures/)

## 4. Protocols, generics, and abstractions

- Create protocols at a real boundary: persistence, networking, clock, identifiers, purchases, audio, notifications, or another dependency with multiple implementations or a required test double.
- Do not create one protocol for every concrete type.
- Protocol names should describe a capability or role.
- Prefer generics and opaque `some Protocol` results when the concrete type is fixed at compile time.
- Use `any Protocol` when heterogeneous runtime storage or replacement is genuinely needed, accepting the indirection and reduced static information.
- Keep protocols small and cohesive. Do not build broad “god protocols.”
- Prefer protocol composition over class inheritance.
- Use associated types when operations have a meaningful type relationship.
- Do not add generic parameters merely to avoid writing clear concrete code.
- Type erasure such as `AnyView` or custom `Any…` wrappers is a boundary tool, not a default design pattern.

References: [Protocols](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/protocols/), [Generics](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/generics/)

## 5. Error handling

- Represent recoverable failures with domain-specific `Error` enums or appropriately scoped error types.
- Prefer `async throws` for asynchronous operations. Use `Result` when a result must be stored, passed through a callback boundary, or composed as a value.
- Never use `try!`, forced casts, or forced unwraps for network, storage, authentication, audio, notification, purchase, or user-input paths.
- Use `try?` only when loss of the failure reason is intentional and harmless.
- Do not use an empty `catch`. Handle, transform, rethrow, or log the error with private data redacted.
- Preserve underlying errors for diagnosis while mapping them to safe, understandable UI states at the feature boundary.
- Treat `CancellationError` as cancellation, not as a generic failure. Do not display a failure alert merely because a view task was cancelled.
- Use `assert` and `precondition` only for programmer errors and impossible internal states, never for ordinary runtime failures.
- Exhaustively handle project-owned enums. Use `@unknown default` for non-frozen system enums where required.
- User-facing copy must not expose raw backend messages, database details, stack traces, file paths, tokens, or internal identifiers.

Reference: [Error Handling](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/errorhandling/)

## 6. Architecture and dependency direction

Use this dependency direction:

```text
SwiftUI View
    ↓
Feature model / use case
    ↓
Repository or service protocol
    ↓
Local and remote implementation
    ↓
SQLite / filesystem / Supabase / Apple framework
```

Rules:

- Views must not execute Supabase queries, database statements, file I/O, purchase validation, or raw network calls.
- Domain models must not be Supabase DTOs or database row types.
- Convert between remote DTOs, local records, and domain models at their boundaries.
- A feature model coordinates presentation state and user intent; it must not become a container for unrelated app services.
- Keep business rules in pure functions or domain services where they can be tested without SwiftUI.
- Construct production dependencies in one composition root near the `App` entry point.
- Prefer initializer injection for feature-specific requirements.
- Use SwiftUI's environment for truly hierarchy-wide dependencies or system context, not to hide every dependency.
- Avoid mutable global state and service locators.
- Dependencies involving current date/time, calendars, time zones, identifiers, network transport, storage, and notification scheduling must be replaceable in tests.

## 7. Swift concurrency

### Isolation

- UI state and UI-facing observable models must be main-actor isolated.
- `async` means a function can suspend; it does not necessarily mean that it runs on a background thread.
- Keep high-latency I/O asynchronous.
- Move measured CPU-intensive work away from the main actor using supported Swift concurrency mechanisms.
- Do not introduce concurrency merely because an API can be concurrent. Start with clear serialized behavior and add parallel work only for independent operations.
- Use actors to protect shared mutable state.
- Cross-actor values must be `Sendable`.
- Prefer immutable value types for data crossing isolation boundaries.
- A mutable reference type must not be declared `Sendable` unless its synchronization model proves the conformance.
- `@unchecked Sendable` requires a code comment documenting the invariant and focused concurrency tests.
- Do not use `MainActor.run` or `DispatchQueue.main.async` as a routine way to patch incorrect isolation. Express isolation statically.

### Structured task lifetime

- Prefer child tasks created with `async let` or task groups when work has a parent operation.
- Use `async let` for a small, fixed set of independent child operations.
- Use throwing task groups for dynamic parallel work that can fail.
- Prefer SwiftUI `.task` and `.task(id:)` for work tied to view lifetime. SwiftUI cancels these tasks when the view disappears and restarts an identified task when its ID changes.
- An unstructured `Task {}` must have a clear owner. Retain and cancel its handle when its work should not outlive that owner.
- Avoid `Task.detached`. It drops inherited actor context and structured lifetime. Use it only for deliberately independent work with reviewed `Sendable` inputs and explicit ownership.
- Never block an async context with semaphores, synchronous network calls, long sleeps, or busy waiting.

### Cancellation

Swift cancellation is cooperative.

- Check cancellation before expensive work and during long loops.
- Use `try Task.checkCancellation()` when cancellation should throw.
- Stop adding task-group children after cancellation.
- Propagate cancellation through service and repository APIs.
- If bridging a callback API, cancel the underlying operation when the Swift task is cancelled.
- Never swallow cancellation and commit stale results afterward.
- UI must return to a consistent state when work is cancelled.

References: [Swift Concurrency](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/), [Task](https://developer.apple.com/documentation/swift/task/), [Explore concurrency in SwiftUI](https://developer.apple.com/videos/play/wwdc2025/266/), [Embracing Swift concurrency](https://developer.apple.com/videos/play/wwdc2025/268/)

## 8. SwiftUI state ownership and Observation

Use one source of truth for each piece of mutable state, located in the least common ancestor that owns it.

| Tool | Use |
|---|---|
| Plain `let` property | Immutable input a view only reads |
| `@State` | Transient state or an observable model owned by that view's lifetime |
| `@Binding` | Borrowed read/write access to state owned by an ancestor |
| `@Bindable` | Bindings to properties of an injected `@Observable` model |
| `@Environment` | System context or deliberately shared hierarchical dependency/model |

Rules:

- Declare view-owned `@State` as `private`.
- Do not use `@State` as persistent storage. Its lifetime follows the view.
- For the supported deployment target, prefer Observation's `@Observable` model over adding new `ObservableObject`/`@Published` code.
- UI-facing observable models should normally be `@MainActor` and `final`.
- Use `@ObservationIgnored` for implementation properties that must not participate in observation.
- Do not mirror the same mutable value in `@State`, an observable model, and persistence.
- Derive values from canonical state instead of storing redundant flags.
- A view receiving a model it does not own should not recreate it.
- Use `@Bindable` only where a child genuinely needs to edit observable properties.
- Use environment injection sparingly. A missing type-based environment value can cause a runtime failure, so production roots, previews, and tests must all provide required values.
- Do not place credentials, large data graphs, or feature-local temporary values in the environment.

References: [Managing model data](https://developer.apple.com/documentation/swiftui/managing-model-data-in-your-app), [Managing user-interface state](https://developer.apple.com/documentation/swiftui/managing-user-interface-state), [Migrating to Observation](https://developer.apple.com/documentation/swiftui/migrating-from-the-observable-object-protocol-to-the-observable-macro), [Environment values](https://developer.apple.com/documentation/swiftui/environment-values)

## 9. Navigation and presentation

- Use `NavigationStack`.
- Model feature routes with a typed `Hashable` enum or another explicit route type.
- Use one canonical navigation path for a flow.
- Avoid navigation built from unrelated Boolean flags.
- Model mutually exclusive sheets, covers, and alerts with identifiable enum state where practical.
- Validate deep links before turning them into routes. Reject unknown identifiers and unauthorized destinations.
- Navigation-state restoration must not restore a route that is no longer authorized or valid.
- Dismissal must leave feature state consistent.
- Do not place side effects inside a destination builder.
- Test direct entry, back navigation, dismissal, deep links, authentication changes, and restoration.

References: [Understanding the navigation stack](https://developer.apple.com/documentation/swiftui/understanding-the-navigation-stack), [Bringing robust navigation structure to your SwiftUI app](https://developer.apple.com/documentation/swiftui/bringing-robust-navigation-structure-to-your-swiftui-app)

## 10. View composition, identity, and side effects

- A view's `body` is a description, not an imperative lifecycle callback.
- Keep `body` deterministic and free of networking, persistence, file access, logging loops, object construction with side effects, or business-state mutation.
- Split views by meaningful UI responsibility, reuse, dependency boundary, or performance boundary—not by arbitrary line count.
- Pass child views only the smallest data and actions they need.
- Prefer standard controls and styles over recreating controls from gestures and shapes.
- Extract repeated semantic styling into focused `ViewModifier`s or styles.
- Keep view identity stable.
- `ForEach` must use a stable unique identifier from the data.
- Do not use array indices as IDs for insertable, removable, or reorderable content.
- Do not use `.self` when values can repeat or mutate.
- Do not generate `UUID()` inside `body`, `ForEach`, or `.id`.
- Do not apply `.id` merely to force a refresh; fix the state dependency.
- Remember that switching conditional view types can change identity and reset state.
- Avoid `AnyView` in ordinary branches and lists.
- `onAppear` can run more than once. Work started there must be idempotent or moved to `.task`.
- Use `.task(id:)` when work is a function of a stable input and should restart when that input changes.
- A user action should update immediate UI state before starting lengthy asynchronous work.

References: [Demystify SwiftUI](https://developer.apple.com/videos/play/wwdc2021/10022/), [Reducing view-modifier maintenance](https://developer.apple.com/documentation/swiftui/reducing-view-modifier-maintenance)

## 11. Performance

Measure before optimizing.

- Profile real workflows using Instruments' SwiftUI template.
- Investigate long view-body updates, frequent updates, hitches, hangs, memory growth, and energy use.
- Keep view-body computation small and synchronous.
- Move expensive parsing, sorting, image processing, database work, and audio preparation out of `body`.
- Narrow observation dependencies. A view should read only the properties that determine its output.
- Pass small immutable display values to leaf views instead of an entire mutable app model.
- Use stable list identity.
- Use lazy containers for large scrollable collections where appropriate.
- Resize, cache, and decode images according to display needs.
- Avoid repeatedly constructing expensive objects during view recomputation.
- Do not add caching without an invalidation and memory policy.
- Do not use concurrency to hide an unmeasured architectural problem.
- Verify improvements with a before/after trace rather than visual impression.

References: [Understanding and improving SwiftUI performance](https://developer.apple.com/documentation/xcode/understanding-and-improving-swiftui-performance), [Optimize SwiftUI performance with Instruments](https://developer.apple.com/videos/play/wwdc2025/306/), [Demystify SwiftUI performance](https://developer.apple.com/videos/play/wwdc2023/10160/)

## 12. Accessibility

Accessibility is part of feature completion.

- Prefer native `Button`, `Toggle`, `Picker`, `TextField`, `Slider`, `ProgressView`, `Label`, lists, and navigation components because they provide semantic behavior automatically.
- When custom visuals are necessary, preserve equivalent accessibility labels, values, traits, states, and actions.
- Every interactive control must have an understandable accessible name.
- Do not repeat the control type inside its label when the system already announces it.
- Mark decorative images as hidden from accessibility.
- Combine or contain child elements when it improves VoiceOver navigation, without hiding required actions.
- Do not use color, shape, sound, or motion as the only way to communicate state.
- Use semantic text styles and support every Dynamic Type accessibility size.
- Avoid fixed-height text containers that clip enlarged or translated content.
- Respect Reduce Motion and other accessibility environment preferences.
- Provide an alternative to gesture-only interaction.
- Ensure focus and announcement behavior makes sense after navigation, errors, purchases, and asynchronous state changes.
- Accessibility identifiers are for automation; they do not replace user-facing accessibility labels.
- Test using VoiceOver, Voice Control, Switch Control, large text, increased contrast, Reduce Motion, and the Accessibility Inspector.
- Run manual and automated accessibility audits on every core flow.

References: [SwiftUI accessibility fundamentals](https://developer.apple.com/documentation/swiftui/accessibility-fundamentals), [Catch up on accessibility in SwiftUI](https://developer.apple.com/videos/play/wwdc2024/10073/), [Performing accessibility audits](https://developer.apple.com/documentation/accessibility/performing-accessibility-audits-for-your-app)

## 13. Localization and internationalization

- Put all user-facing text in String Catalogs.
- Use localizable SwiftUI strings or `String(localized:)` outside view declarations.
- Add translator comments when meaning, tone, placeholders, or wellness context could be ambiguous.
- Never build sentences by concatenating translated fragments.
- Use catalog plural variants instead of manual singular/plural logic.
- Use `FormatStyle` and locale-aware APIs for dates, times, durations, measurements, numbers, and lists.
- Store stable codes or enum cases, not localized display strings.
- Preserve user-entered text without translation.
- Allow layouts to expand for longer translations and accessibility sizes.
- Support right-to-left layout using semantic alignment and system mirroring.
- Do not embed assumptions about 12-hour time, Gregorian formatting, week starts, decimal separators, or a fixed time zone.
- Inject calendars, locale, clock, and time zone where business logic depends on them.
- Test pseudolocalization, long strings, right-to-left layout, and every supported locale.
- Alarm and sleep-schedule persistence must preserve the distinction between an absolute instant and a user-intended local wall-clock schedule.

References: [Localization](https://developer.apple.com/documentation/xcode/localization), [String Catalogs](https://developer.apple.com/documentation/xcode/localizing-and-varying-text-with-a-string-catalog), [Preparing text for translation](https://developer.apple.com/documentation/xcode/preparing-your-apps-text-for-translation)

## 14. Previews

Every reusable screen or component should have meaningful `#Preview` coverage.

Preview at least:

- Normal content.
- Loading.
- Empty.
- Error.
- Offline.
- Permission denied.
- Premium locked/unlocked where relevant.
- Light and dark appearance.
- Large accessibility text.
- Long localized copy.
- Right-to-left layout where applicable.

Additional rules:

- Previews must not contact Supabase, request permissions, schedule alarms, make purchases, or write production storage.
- Use deterministic fixtures and injected preview dependencies.
- Pass views only the data they need.
- Use `@Previewable` for local preview bindings where supported.
- Use reusable preview modifiers when setup is expensive.
- A working preview does not replace simulator and real-device testing.

Reference: [Previewing your app's interface in Xcode](https://developer.apple.com/documentation/xcode/previewing-your-apps-interface-in-xcode)

## 15. Testing and dependency injection

Use a test pyramid:

1. Many fast unit tests.
2. Focused integration tests.
3. Fewer end-to-end UI tests.

### Unit and integration tests

- Use Swift Testing for new domain, service, repository, and feature-model tests.
- Use parameterized tests for onboarding truth tables, schedule calculations, sync conflicts, and permission matrices.
- Test success, failure, cancellation, retry, empty, offline, and stale-result behavior.
- Test actor-isolated code from concurrent callers where relevant.
- Tests must not depend on wall-clock time, random UUIDs, production credentials, or external network availability.
- Inject clocks, calendars, time zones, identifiers, storage, transport, and platform adapters.
- Use in-memory or temporary stores for persistence tests.
- Test every database migration from each supported prior schema.
- Do not introduce a protocol solely to mock trivial pure code.

### UI tests

- Continue to use XCTest/XCUIAutomation for UI automation.
- Cover the critical bedtime, manual episode, grounding, morning check-in, purchase restoration, deletion, and permission-denied paths.
- Use launch arguments or a dedicated test composition root to create deterministic app states.
- Do not add production-only branches that weaken behavior merely to make UI tests easier.
- Include accessibility audits in representative UI tests.
- Treat flaky tests as defects.

References: [Swift Testing](https://developer.apple.com/documentation/testing), [Testing in Xcode](https://developer.apple.com/documentation/xcode/testing)

## 16. Persistence and synchronization boundaries

For Phase 1's SQLite/Supabase architecture:

- UI state, local persistence, remote persistence, and synchronization state are separate concerns.
- Views must not operate directly on database rows or Supabase DTOs.
- Repositories expose domain values or snapshots.
- Local storage access must have one reviewed serialization strategy. Use an actor boundary when the database library and access pattern require isolation.
- Do not claim `Sendable` for database handles or records merely to satisfy the compiler.
- Multi-step writes that must remain consistent belong in a transaction.
- Synchronization operations must be idempotent and have a documented conflict policy.
- Every record must have a stable identity and ownership scope.
- Scope user data by authenticated user at both application and database-policy levels.
- Treat migrations as production code: version them, test them, and avoid destructive fallback recreation.
- Persist dates in an unambiguous representation. Render using the intended locale and time zone.
- Keep localized strings out of the schema.
- `UserDefaults`/`@AppStorage` is for small preferences, not credentials, audio files, histories, or authoritative business data.
- SwiftUI `@State` is not a persistence layer.
- Synchronization failure must not corrupt or silently discard a valid local record.
- Deletion must cover local rows, cached files, queued work, remote records, and private storage objects according to the project's retention policy.

References: [SwiftUI persistent storage](https://developer.apple.com/documentation/swiftui/persistent-storage), [Managing user-interface state](https://developer.apple.com/documentation/swiftui/managing-user-interface-state)

## 17. Security-sensitive Swift coding

- Store tokens, credentials, and small cryptographic secrets in Keychain Services.
- Never store secrets in source control, bundled configuration, `UserDefaults`, analytics, crash metadata, or logs.
- A Supabase publishable/anonymous client key may be present in the app when intended by Supabase, but a service-role key must never ship in the client.
- Use CryptoKit rather than custom cryptography or legacy/insecure algorithms.
- Use appropriate iOS file-protection classes for private local files.
- File protection must be selected against real behavior. Grounding audio may need controlled access while the device is locked, so choosing `.complete` blindly could break the core flow. Document and test the selected protection class on a locked physical device.
- Use `Logger` privacy controls. Treat sleep/episode data, contact details, identifiers, and account information as private.
- Do not log tokens, signed URLs, audio paths, questionnaire answers, or raw backend payloads.
- Validate and constrain untrusted data from deep links, Supabase, local files, notifications, and decoded JSON.
- Enforce reasonable sizes before allocating, decoding, downloading, uploading, or persisting data.
- Do not disable TLS trust evaluation or accept arbitrary certificates.
- Prefer memory-safe APIs. Isolate and review any pointer, C, or unsafe operation.
- Consider strict-memory-safety checking for security-critical low-level modules.
- Forced unwraps and casts are forbidden on security-sensitive or externally supplied data paths.
- Authentication-state changes must clear or re-scope user-specific cached state.
- Logout and account deletion must remove the appropriate Keychain items and private local data.
- Do not expose internal errors or authorization-policy details to users.

References: [Keychain Services](https://developer.apple.com/documentation/security/keychain-services), [Storing keys in the Keychain](https://developer.apple.com/documentation/security/storing-keys-in-the-keychain), [CryptoKit](https://developer.apple.com/documentation/cryptokit/), [File protection](https://developer.apple.com/documentation/foundation/fileprotectiontype/complete), [OSLog privacy](https://developer.apple.com/documentation/os/oslogprivacy), [Strict memory safety](https://docs.swift.org/compiler/documentation/diagnostics/strict-memory-safety/)

## 18. Prohibited anti-patterns

| Avoid | Required direction |
|---|---|
| Networking or persistence in `View.body` | Repository/service invoked by an owned feature model |
| A global mutable singleton | Composition-root dependency injection |
| Duplicate state across view, model, and database | One source of truth plus derived values |
| New `ObservableObject`/`@Published` code for the supported target | Observation with `@Observable` |
| One `AppViewModel` owning the entire application | Focused feature models and services |
| Boolean navigation and modal-state soup | Typed routes and identifiable presentation state |
| `AnyView` throughout normal layout | Concrete view composition |
| `UUID()` generated during rendering | Stable model identity |
| Array index as mutable list identity | Stable record ID |
| `Task.detached` as a background-work shortcut | Structured child task or reviewed actor/service |
| `DispatchQueue.main.async` to silence isolation errors | Correct `MainActor` isolation |
| `@unchecked Sendable` without proof | Value semantics, actor isolation, or reviewed synchronization |
| Empty `catch`, broad `try?`, or `try!` | Explicit error and cancellation handling |
| Synchronous disk/network work on the main actor | Asynchronous boundary and measured offloading |
| Environment as a hidden service locator | Initializer injection; environment only for hierarchy-wide values |
| User-facing text assembled by concatenation | Localized complete messages and plural rules |
| Secrets in `UserDefaults` | Keychain |
| Custom cryptography | CryptoKit |
| Logging raw user data | Structured private/redacted logs |
| Custom controls without semantics | Native controls/styles or complete accessibility behavior |
| Fixed text frames | Adaptive layout and Dynamic Type |
| Optimization by intuition | Instruments evidence |
| Preview/test using production services | Deterministic injected fixtures |

## 19. Pull-request review checklist

### Swift and API design

- [ ] Names are clear at the call site and follow Swift conventions.
- [ ] Mutation is limited; `let` and narrow access control are used by default.
- [ ] Value and reference semantics match the required ownership.
- [ ] Classes are `final` unless reviewed inheritance is required.
- [ ] Protocols describe real boundaries and are not speculative abstractions.
- [ ] Errors and cancellation are handled explicitly.
- [ ] No unsafe force unwrap, force cast, `try!`, or swallowed meaningful failure was added.
- [ ] Public/cross-feature behavior has useful documentation.

### Concurrency

- [ ] Swift 6 complete data-race checking passes without new warnings.
- [ ] UI-facing mutable state has correct main-actor isolation.
- [ ] Cross-actor values are genuinely `Sendable`.
- [ ] Shared mutable state has an explicit actor or reviewed synchronization owner.
- [ ] Structured tasks are used where parent/child lifetime exists.
- [ ] Unstructured task handles have an owner and cancellation policy.
- [ ] No unjustified `Task.detached`, `@unchecked Sendable`, or dispatch-queue workaround was added.
- [ ] Cancellation cannot commit stale results or appear as a user-visible failure.
- [ ] Actor state is revalidated after suspension points.

### SwiftUI

- [ ] Each mutable value has one source of truth.
- [ ] Property wrappers match ownership: `@State`, `@Binding`, `@Bindable`, or `@Environment`.
- [ ] Persistent data is not stored only in SwiftUI state.
- [ ] `body` is free of side effects and expensive work.
- [ ] Views receive only the data and actions they need.
- [ ] List and navigation identity is stable.
- [ ] No generated render-time IDs or index identity is used for mutable collections.
- [ ] Navigation and presentations use typed, consistent state.
- [ ] `.task`/`.task(id:)` lifetime and restart behavior is correct.
- [ ] Required environment values are supplied in app, previews, and tests.

### Persistence and security

- [ ] Domain, local-record, and remote-DTO models remain separated.
- [ ] Writes requiring consistency use transactions.
- [ ] Synchronization operations are idempotent and user-scoped.
- [ ] Migration coverage was added for schema changes.
- [ ] Secrets use Keychain and are absent from source, defaults, analytics, and logs.
- [ ] Sensitive files use a documented, tested file-protection class.
- [ ] Logs redact private values.
- [ ] External input, payload sizes, URLs, and decoded data are validated.
- [ ] Logout/deletion behavior covers local, remote, cached, and Keychain data as applicable.

### Quality

- [ ] Unit tests cover business logic, failure, cancellation, and edge cases.
- [ ] Integration tests cover changed persistence or remote boundaries.
- [ ] Critical-flow UI tests were added or updated where behavior changed.
- [ ] Previews cover relevant normal, loading, empty, error, offline, and permission states.
- [ ] Dynamic Type, VoiceOver, contrast, motion, and accessible actions were verified.
- [ ] User-facing strings are localized as complete messages.
- [ ] Locale, time-zone, 12/24-hour, plural, and right-to-left behavior was considered.
- [ ] Performance-sensitive changes were measured with Instruments.
- [ ] The stable toolchain builds without warnings.

## Official reference index

- [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/)
- [The Swift Programming Language](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/)
- [Swift Concurrency](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/)
- [Swift 6 migration guide](https://www.swift.org/migration/)
- [SwiftUI documentation](https://developer.apple.com/documentation/swiftui)
- [Observation](https://developer.apple.com/documentation/observation)
- [SwiftUI accessibility](https://developer.apple.com/documentation/swiftui/accessibility-fundamentals)
- [Xcode localization](https://developer.apple.com/documentation/xcode/localization)
- [Swift Testing](https://developer.apple.com/documentation/testing)
- [Xcode testing](https://developer.apple.com/documentation/xcode/testing)
- [SwiftUI performance analysis](https://developer.apple.com/documentation/swiftui/performance-analysis)
- [Keychain Services](https://developer.apple.com/documentation/security/keychain-services)
- [CryptoKit](https://developer.apple.com/documentation/cryptokit/)
