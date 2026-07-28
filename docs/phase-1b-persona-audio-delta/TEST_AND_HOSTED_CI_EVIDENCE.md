# Test and hosted-CI evidence

**Implementation repair commit:** `029626fedf5381ef687d5c3d9a8d407d11b0a009` on `codex/phase-1b-persona-audio-delta` (verified with `git rev-parse`; parent/start: `791ea4208d41ebe0971561bbe925a9e4f080cb34`).

**Evidence correction commit / final local HEAD:** Recorded after Git creates the correction commit; neither SHA may be manually reconstructed.

## Local commands and terminal results

| Command | Result |
|---|---|
| `git diff --check` | Passed (no whitespace errors). |
| `python -c "import yaml ... yaml.safe_load(codemagic.yaml)"` | Passed: `codemagic.yaml: valid YAML`. |
| Static secret-pattern scan of `HEAD` and all reachable Git history | No credential-shaped value found. |
| Personal-audio prohibited-field scan across iOS sources, migrations, and tests | Passed: no filename/path/bytes/transcript/waveform/embedding/remote-reference fields were introduced for personal audio. |
| pgTAP assertion count check | `phase_1b_persona_audio_delta_test.sql` declares and contains 54 assertions; static count only, not execution evidence. |
| `docker version` | Not runnable against a usable daemon: local Docker access/daemon unavailable. |
| `wsl -l -q` | Not runnable: WSL service access denied. |
| Swift/Xcode/Supabase CLI discovery | `swift`, `swiftc`, `xcodebuild`, and `supabase` are unavailable on this Windows host. |

Swift source tests assert routing counts, every incomplete completion shape, distinct draft/profile IDs, idempotent completion, queue creation, provider conversion, Settings revision change, tombstone queueing, missing/wrong-account access, enum raw values/rejection, pre-transaction write-fault preservation, metadata bounds/formats/defaults/cascade, and structured `persona.json` inclusion/exclusion. `PersonaExport.CodingKeys` is statically inspected for the six approved snake-case keys.

The pgTAP source suite asserts actual Storage bucket/object/policy absence, owner RPC, existing-row cross-user read denial, direct-DML denial, forged/malformed/replayed payload rejection with absent receipts, trusted update, audio mutation denial, tombstone/retry, stale resurrection prevention, execution privileges, legacy compatibility, and account-deletion cascade. None of these assertions has run locally or hosted yet.

## Not run / not claimed

No local Swift tests, migration application, pgTAP run, Docker/Supabase isolated backend, Xcode simulator, live Supabase operation, physical-device test, deployment, or hosted CI was run. The stated host limitations above prevented the local runtime tests. Codemagic is configured for this branch but is **pending explicit push consent**; no push was made.
