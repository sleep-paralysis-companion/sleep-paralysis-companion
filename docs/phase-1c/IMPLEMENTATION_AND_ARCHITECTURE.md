# Phase 1C Implementation and Architecture

## Scope

The implemented first-use flow is exactly:

`Welcome → product boundary/privacy summary → atomic guest profile → Home`

There is no questionnaire, preference step, sign-in requirement, paywall, price, permission
request, or network upload in this path. Alarm scheduling, audio, check-ins, commerce, and real
authentication remain later-phase work.

## Composition

`AppCompositionRoot` creates one `AppModel` with:

- the compiled environment and privacy-safe logger;
- `AccessPolicy`;
- `LocalOnboardingProfileStore`;
- system date and identifier providers.

`LocalOnboardingProfileStore` is an actor. It lazily opens the protected GRDB database away from
the main actor and translates database errors into content-free onboarding errors. The app model
never receives a database, Supabase client, provider credential, or raw backend error.

## Onboarding data boundary

`OnboardingProfile` accepts only:

1. `localProfileID`;
2. `profileCreatedAt`;
3. `productNoticeVersion`;
4. `productNoticeSeenAt`;
5. `onboardingCompletedAt`.

The GRDB row also has Phase 1B integrity columns. During guest creation those are assigned
internally to `guestLocal`, no account user, and `localOnly`; they are not collected onboarding
inputs. Onboarding creates no settings row, sync operation, account binding, alarm, check-in,
permission record, or analytics event.

`LocalDatabase.createGuestProfileIfAbsent` is actor-serialized and uses one GRDB transaction.
The single-profile unique index is the durable invariant. A repeat call returns the existing
profile. A fault before/during the write leaves no profile, and cancellation cannot expose a
partially committed row.

## State ownership

`AppModel` is the main-actor state owner. It exposes finite launch, tab, route, sheet, processing,
feedback, and account-access values. Async load/create/notice work is cancellable and checks task
cancellation before publishing UI state.

Database failures leave the user on a recoverable screen or on the notice with a retry. UI copy
is local and content-free; raw errors are neither displayed nor logged.

## Navigation and restoration

The app uses `NavigationStack` with typed `AppRoute` values, typed `AppTab` selection, and typed
`AppSheet` presentation. A versioned `RouteRestorationEnvelope` contains a profile ID, tab, path,
and optional sheet. It is stored through `SceneStorage`.

Restoration is accepted only when its schema version and local profile ID match. Malformed,
unsupported-future, or stale-profile data falls back to Home with an empty path. Deep links use
the local `spc` scheme resolver and reject unknown schemes/destinations.

Auth-state changes update an explicit account-access state without deleting or replacing the
local profile. Authentication remains reachable only from the user-selected Sync route.

## Home shell

Home, History, and Settings are persistent high-level destinations:

- Home exposes Alarm plus honest Grounding and Prepare availability cards;
- History states that the feature is unavailable and links to data/privacy;
- Settings exposes optional Sync, permission education, data/privacy, and help/legal.

Alarm status is free and ungated. It says that no alarm is scheduled. Grounding, audio,
preparation, and history do not simulate later-phase behavior.

## Access and permission seams

`AccessPolicyPresenter` maps the existing access policy to presentation state. Its trial
eligibility is `nil` because no authoritative commerce adapter exists. Utilities including Alarm,
privacy, legal, help, export/deletion paths, restoration, and access status remain allowed.

`ContextualPermissionStateProviding` has finite not-requested, denied, unsupported, and available
states. The Phase 1C implementation returns `notRequested` and has no request API. Education and
recovery presentation can be connected contextually in a later phase.
