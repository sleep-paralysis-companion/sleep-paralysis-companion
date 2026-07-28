# Test and hosted-CI evidence

**Repaired local implementation commit:** `029626fe8df6e0d54a28f96fe5ac8ff8646f1d75` on `codex/phase-1b-persona-audio-delta` (parent/start: `791ea4208d41ebe0971561bbe925a9e4f080cb34`).

## Local commands and terminal results

| Command | Result |
|---|---|
| `git diff --check` | Passed (no whitespace errors). |
| `python -c "import yaml ... yaml.safe_load(codemagic.yaml)"` | Passed: `codemagic.yaml: valid YAML`. |
| Static secret-pattern scan across iOS/Supabase/docs/scripts | No credential-shaped value found; textual policy references were reviewed as non-secret documentation/runtime identifiers. |
| Personal-audio prohibited-field scan across iOS sources, migrations, and tests | Passed: no filename/path/bytes/transcript/waveform/embedding/remote-reference fields were introduced for personal audio. |
| pgTAP assertion count check | `phase_1b_persona_audio_delta_test.sql` declares and contains 30 assertions. |
| `docker version` | Not runnable against a usable daemon: local Docker access/daemon unavailable. |
| `wsl -l -q` | Not runnable: WSL service access denied. |
| Swift/Xcode/Supabase CLI discovery | `swift`, `swiftc`, `xcodebuild`, and `supabase` are unavailable on this Windows host. |

`PersonaAudioFoundationTests` now covers routing counts, incomplete completion rejection, distinct draft/profile IDs, idempotent completion, queue creation, production outbound persona conversion, Settings revision change, tombstone queueing, wrong-account access, enum raw values/rejection, bounds/default behavior, and local schema upgrade coverage. `DataRightsFoundationTests` covers redacted `persona.json` inclusion and exclusions.

The pgTAP suite covers actual Storage bucket/object/policy absence, owner RPC, existing-row cross-user read denial, direct-DML denial, forged persona/receipt rollback, replay mismatch, trusted update, audio mutation denial, tombstone/retry, stale resurrection prevention, and anonymous denial.

## Not run / not claimed

No local Swift tests, migration application, pgTAP run, Docker/Supabase isolated backend, Xcode simulator, live Supabase operation, physical-device test, deployment, or hosted CI was run. The stated host limitations above prevented the local runtime tests. Codemagic is configured for this branch but is **pending explicit push consent**; no push was made.
