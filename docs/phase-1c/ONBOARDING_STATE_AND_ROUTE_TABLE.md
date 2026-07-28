# Onboarding State and Route Table

> **SUPERSEDED FOR PRODUCT ACCEPTANCE - 29 July 2026.** This is the route table for the obsolete guest-only flow. The authenticated Q1-Q3/persona, recommended-setup, personal-audio, schedule, and Home journey is controlled by [Persona and Personal Audio Product Realignment](../phase-0/PERSONA_AND_PERSONAL_AUDIO_REALIGNMENT.md) and requires a replacement route table in a later implementation stage.

## Launch truth table

| Local state | Notice state | Valid restoration | Launch result |
|---|---|---|---|
| Database opening/read pending | Any | Any | Loading |
| Database unavailable | Unknown | Ignored | Recoverable local-data error and retry |
| No profile | None | Ignored | Welcome |
| Profile with no completion timestamp | Any | Ignored | Initial boundary/privacy summary |
| Completed profile | Superseded | Ignored | Updated boundary/privacy summary |
| Completed profile | Current | Malformed, future, or wrong profile | Home tab, empty path |
| Completed profile | Current | Matching version/profile | Restored typed tab, path, and sheet |

## Visible onboarding transitions

| Current state | Action/interruption | Persisted effect | Next valid state |
|---|---|---|---|
| Welcome | Continue | None | Initial boundary/privacy summary |
| Welcome | Terminate/relaunch | None | Welcome |
| Initial summary | Back/cancel/terminate | None | Welcome on clean relaunch |
| Initial summary | Repeated Continue taps | One serialized create attempt | Home or recoverable summary |
| Initial summary | Database failure | No partial row | Same summary with announced retry |
| Initial summary | Commit succeeds, task then cancels | One complete profile | Home on relaunch |
| Updated summary | Alarm/privacy/help | No notice acknowledgement | Selected utility; summary remains pending |
| Updated summary | Continue | Current version and seen time update | Home |
| Home | Relaunch offline | No network dependency | Home |

The guest profile is created only by Continue on the initial summary. Welcome never writes.

## Route allowlist

| Route | From Home | From notice | Behavior in Phase 1C |
|---|---:|---:|---|
| Alarm | Yes | Yes | Free, ungated status; no schedule or permission request |
| Grounding | Yes | No | Honest unavailable state; no audio |
| Prepare | Yes | No | Honest unavailable state |
| Permission education | Settings | No | Explains future contextual request; requests nothing |
| Sync/account | Settings | No | Explains optional value; starts no auth or upload |
| Data/privacy | Settings, History | Yes | Bundled local content |
| Help/legal | Settings | Yes | Bundled approved boundary content |

Unknown deep links and decoded unknown route values do not enter the stack. A signed-in wrong
account or reauthentication-required state cannot remove guest data and is explained only within
the explicit Sync route.
