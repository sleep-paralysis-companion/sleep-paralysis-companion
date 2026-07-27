# Phase 1A Architecture and Dependency Boundaries

## Boundary map

`App` is the only composition root. It creates configuration, logging, access
policy, and UI state. `Features` renders state and emits typed intent.
`Domain` owns routes and access rules. `Core` owns small cross-cutting value
types. `DataInterfaces` declares only the concrete external-resource seam used
by configuration. `PlatformInterfaces` owns the Apple logging adapter.
`DesignSystem` owns semantic visual/accessibility values. `Configuration`
resolves injected public values and rejects unsafe combinations.

Dependencies point toward `Core` and `Domain`. A SwiftUI view must not import or
directly invoke persistence, Supabase, StoreKit, RevenueCat, AlarmKit,
AVFoundation, filesystem, or networking APIs. There is no service locator,
generic repository, manager/helper layer, runtime SDK, or mutable global state.

## State and concurrency

- `AppModel` is `@MainActor` and observable.
- The UI-facing app target uses MainActor-by-default. Immutable, `Sendable`
  Core, Domain, Configuration, DataInterfaces, and PlatformInterfaces
  declarations explicitly opt out with safe `nonisolated` type isolation.
- Navigation is `[AppRoute]`, not string or view-instance routing.
- App activation work is cancellable, inherits the main actor, checks
  cancellation, and never uses detached tasks or semaphore bridging.
- Value semantics are the default. No actor exists because Phase 1A has no
  genuinely shared mutable non-UI state.

## Phase boundary

The shell contains no onboarding, alarm, grounding, audio, check-in, history,
account, paywall, purchase, persistence, synchronization, or production
feature screen. Later phases must extend the inward contracts rather than let
views call infrastructure directly.
