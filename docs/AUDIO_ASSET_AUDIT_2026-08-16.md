# Sleep Paralysis Companion audio asset audit

Audit date: 2026-08-16
Scope: `Audio Assets/` (18 files), `ios/Resources/Provided audio/` (2 files),
`assets/audio/incoming/README.md`,
`docs/phase-0/AUDIO_AND_OFFLINE_CONTRACT.md`, and current audio/alarm source
references.
Mutation boundary: read-only. No supplied audio file was opened for writing,
renamed, transcoded, moved, deleted, or otherwise modified. The two files
created by this audit are this report and the machine-readable manifest.

## Executive result

- 20 supplied/bundled files were inventoried: 18 in `Audio Assets/` and 2 in
  `ios/Resources/Provided audio/`.
- The files form 11 technical asset groups: five morning-alarm candidates,
  one notification candidate, three named catalog candidates, and two
  unassigned provided-resource files.
- All 20 files have distinct SHA-256 hashes. There are no exact byte
  duplicates.
- Nine groups contain likely alternate encodings or container variants,
  identified by matching asset-like names and near-identical durations. The
  hash differences mean these are not exact duplicates; decoded content
  identity still needs content-owner confirmation.
- Actual media properties were read with `ffprobe` 8.0.1. Every `.mp3.mpeg`
  file is an MP3, not MPEG video; the file named
  `Quick Unwind 240bit PCM, 48kHz.mp3.wav` is a WAV; and every supplied WAV
  reports 16-bit PCM despite the `240bit` filename text.
- No AAC-LC M4A delivery was supplied. The long-session MP3s are 320 kbps and
  remain source candidates for the required AAC-LC M4A transcode; no
  transcode was performed.
- No supplied file is approved for production integration. The intake README
  requires rights, provenance, transcript, accessibility, and approval data
  in addition to technical metadata.
- No default morning alarm is selected by this audit. The five candidates are
  presented below for product approval.

## Reconciliation with the controlling contract and source

The intake README says originals must remain unrenamed and unmodified,
candidate presence is not approval, and each file needs a manifest record with
rights, distribution, offline-caching, mastering, transcript, and contact
evidence. It also warns that large or licensed binaries must not be committed
until storage and redistribution rights are approved.

The audio contract requires bundled minimum content plus optional downloadable
catalog content, immutable IDs and hashes, exact technical metadata, rights
and approval records, protected verified downloads, no network dependency for
the useful offline path, and physical-device evidence for locked/system audio
behavior. The current contract text still describes candidate assets as not yet
received/hashed/rights-reviewed/approved; this audit supplies technical
inventory evidence but does not close the remaining governance gates.

Current source inspection found:

- `ios/Sources/SleepSchedule/WakeAlarmService.swift:10-20` looks only for the
  bundled resource `SPCWakeUpGentleLoop.caf`; no file with that exact name is
  present in the inspected locations.
- `ios/Sources/SleepSchedule/WakeAlarmService.swift:33-43` returns
  `.audioAssetUnavailable` when that local resource is absent, so the current
  implementation does not silently fall back to a remote alarm asset.
- `ios/Sources/Domain/IntegratedPhase1Models.swift:124-137` contains two
  placeholder catalog entries with `bundledResourceName: nil`; the supplied
  files are not mapped into that catalog by the current source.
- `ios/Resources/Provided audio/` is ignored by `.gitignore`, while the new
  `Audio Assets/` directory is currently untracked. The 18 intake files total
  approximately 1.38 GiB, so accidental staging is a material repository
  risk.

## Unique asset groups and recommended delivery classification

The classifications below are technical delivery recommendations, not
approval decisions. “Alternate encoding candidate” means the files are paired
by filename stem/role and duration; it does not certify that the audio content
is identical.

| Group | Category | Supplied variants | Duration | Recommended classification | Approval state |
|---|---|---|---:|---|---|
| `MORNING-FELT-DAWN` | Morning Alarm | `Felt_Dawn...mp3.caf` + `Felt_Dawn...mp3.mpeg` | 30.041 s | CAF is a local system-alarm candidate; MP3 is a source/compressed copy, not an alarm-fire dependency | Do not choose without product/content/rights/device approval |
| `MORNING-STILLNESS` | Morning Alarm | `Morning_Stillness...mp3.caf` + `Morning_Stillness...mp3.mpeg` | 30.041 s | CAF is a local system-alarm candidate; MP3 is a source/compressed copy | Do not choose without approval |
| `MORNING-ECHOES` | Morning Alarm | `Morning_Echoes...mp3.caf` + `Morning_Echoes...mp3.mpeg` | 60.029 s | CAF is a local system-alarm candidate; MP3 is a source/compressed copy | Do not choose without approval |
| `MORNING-STONE-ECHOES` | Morning Alarm | `Stone_Echoes...mp3.caf` + `Stone_Echoes...mp3.mpeg` | 60.029 s | CAF is a local system-alarm candidate; MP3 is a source/compressed copy | Do not choose without approval |
| `MORNING-MEADOW-RADIANCE` | Morning Alarm | `Morning Meadow Radiance.wav` + `Morning-Meadow-Radiance.caf` | 180.000 s | WAV is a protected PCM-master candidate; CAF is a local system-alarm candidate. No default selected | Do not choose without approval |
| `NOTIFICATION-7` | Notification | `7.mp3.caf` + `7.mp3.mpeg` | 2.000 s | CAF is the bundled notification candidate; MP3 is a source/compressed copy | Requires notification and physical-device approval |
| `QUICK-UNWIND` | Quick Unwind | WAV + 320 kbps MP3 | 393.160 s | Preserve WAV as protected source candidate; transcode MP3 to AAC-LC M4A for compressed catalog delivery, with streaming preview and optional verified full download | Rights/mastering/transcode approval pending |
| `SECOND-SLEEP` | Second Sleep | WAV + 320 kbps MP3 | 360.049 s | Preserve WAV as protected source candidate; transcode MP3 to AAC-LC M4A for compressed catalog delivery, with streaming preview and optional verified full download | Rights/mastering/transcode approval pending |
| `SLOW-UNWIND` | Slow Unwind | WAV + 320 kbps MP3 | 5170.643 s | Preserve WAV as protected source candidate; transcode MP3 to AAC-LC M4A for compressed catalog delivery, with streaming preview and optional verified full download | Rights/mastering/transcode approval pending |
| `PROVIDED-MOONLIT-FOREST` | Unassigned provided resource | 320 kbps MP3 | 5185.225 s | Hold as unclassified compressed source until Product maps it to a category/slot and rights are proven | Not eligible for delivery classification |
| `PROVIDED-SHORT-AUDIO` | Unassigned provided resource | 320 kbps MP3 | 482.116 s | Hold as unclassified compressed source until Product maps it to a category/slot and rights are proven | Not eligible for delivery classification |

For morning-alarm groups, the eventual product decision should choose one
tested local candidate for the bundled default. Any other selected morning
choice must be fully downloaded, integrity-checked, and locally available
before scheduling; none of the current MP3 files should be used as a network
or remote-at-fire dependency.

## Human-readable file inventory

`Duration` is the `ffprobe` format duration in seconds. `Size` is exact bytes
with an approximate binary MiB value. `Bit depth` is `n/a` for MP3 because
`ffprobe` does not report a PCM sample depth for a lossy codec. The full
machine-readable records, including all hashes and boolean format flags, are in
[`AUDIO_ASSET_MANIFEST_2026-08-16.json`](./AUDIO_ASSET_MANIFEST_2026-08-16.json).

### Morning Alarm

| Original filename | Actual format / codec | Duration | Size | Bitrate | Sample rate / channels / depth | SHA-256 |
|---|---|---:|---:|---:|---|---|
| `Felt_Dawn_2026-08-12T071602.mp3.caf` | CAF / `pcm_s16be` | 30.040833 s | 2,884,050 B (2.75 MiB) | 768,000 bps | 48,000 Hz / mono / 16-bit | `278b2fcf4f067c7999e7a8656fd634172c1a8ef98ff667301eac087f29072cf3` |
| `Felt_Dawn_2026-08-12T071602.mp3.mpeg` | MP3 / `mp3` | 30.040792 s | 737,664 B (0.70 MiB) | 192,000 bps | 44,100 Hz / stereo / n/a | `cbab850f24ed5117db36a11f5cd0bafaf4a0e92389763d2452c73bf68ba76ac0` |
| `Morning Meadow Radiance.wav` | WAV / `pcm_s16le` | 180.000000 s | 34,560,044 B (32.96 MiB) | 1,536,000 bps | 48,000 Hz / stereo / 16-bit | `1493b79a89e859768c8793689c779a7e0e51ef70307d3aa275db91cc0dc3b3ac` |
| `Morning_Echoes_2026-08-12T075336.mp3.caf` | CAF / `pcm_s16be` | 60.029396 s | 5,762,952 B (5.50 MiB) | 768,000 bps | 48,000 Hz / mono / 16-bit | `a84794e309b1fcf43f0b51d7877d9f4baa61f4aaf0e0f8730bfa2f0099277957` |
| `Morning_Echoes_2026-08-12T075336.mp3.mpeg` | MP3 / `mp3` | 60.029375 s | 1,457,390 B (1.39 MiB) | 192,000 bps | 44,100 Hz / stereo / n/a | `255c0de370a8c965379befb4fc87b585491e670784d087eb6f6372eb4c6e96ea` |
| `Morning_Stillness_2026-08-12T074317.mp3.caf` | CAF / `pcm_s16be` | 30.040833 s | 2,884,050 B (2.75 MiB) | 768,000 bps | 48,000 Hz / mono / 16-bit | `3045fcc5b34bc95a2b6bb3f2613899f7e4a832fce6c23ad8187644e432457e7e` |
| `Morning_Stillness_2026-08-12T074317.mp3.mpeg` | MP3 / `mp3` | 30.040792 s | 737,664 B (0.70 MiB) | 192,000 bps | 44,100 Hz / stereo / n/a | `a9bb104471397e9c4821d614da94d8b7d1bcc836732f32de4aa350a98d288f3d` |
| `Morning-Meadow-Radiance.caf` | CAF / `pcm_s16be` | 180.000000 s | 17,280,130 B (16.48 MiB) | 768,000 bps | 48,000 Hz / mono / 16-bit | `6b9d4af7e4c6b163af6dfa246e5e88c205081fea42d2a3236c85600ef12b298e` |
| `Stone_Echoes_2026-08-12T075204.mp3.caf` | CAF / `pcm_s16be` | 60.029396 s | 5,762,952 B (5.50 MiB) | 768,000 bps | 48,000 Hz / mono / 16-bit | `0cacc4baa2ab3795499fb3466bafb6d35384b6f8ddbdd4832676a1bd4273374a` |
| `Stone_Echoes_2026-08-12T075204.mp3.mpeg` | MP3 / `mp3` | 60.029375 s | 1,457,390 B (1.39 MiB) | 192,000 bps | 44,100 Hz / stereo / n/a | `70227a2f981addabc30d149d5f0fe8e188afcb0e1d11dcf36f864a00c0a473d6` |

### Notification

| Original filename | Actual format / codec | Duration | Size | Bitrate | Sample rate / channels / depth | SHA-256 |
|---|---|---:|---:|---:|---|---|
| `7.mp3.caf` | CAF / `pcm_s16be` | 2.000000 s | 192,130 B (0.18 MiB) | 768,000 bps | 48,000 Hz / mono / 16-bit | `8027d0a7a86921c65b695197107e02a11947e9b4a50825d634e4e159469fab8e` |
| `7.mp3.mpeg` | MP3 / `mp3` | 2.000000 s | 49,581 B (0.05 MiB) | 192,000 bps | 48,000 Hz / stereo / n/a | `71eaf27f59c446160e94660df345979ef7d4ac9edfea24a47648bb4244437d11` |

### Quick Unwind

| Original filename | Actual format / codec | Duration | Size | Bitrate | Sample rate / channels / depth | SHA-256 |
|---|---|---:|---:|---:|---|---|
| `Quick Unwind 240bit PCM, 48kHz.mp3.wav` | WAV / `pcm_s16le` | 393.160292 s | 75,486,854 B (71.99 MiB) | 1,536,000 bps | 48,000 Hz / stereo / 16-bit | `587da384262bb86c4ea6429b5856615c12207f1d67836c9d73db435d01556f9f` |
| `Quick Unwind.mp3.mpeg` | MP3 / `mp3` | 393.160272 s | 15,728,995 B (15.00 MiB) | 320,000 bps | 44,100 Hz / stereo / n/a | `5d9d3468cd5a0957a38f3f072490195f4eeeae0dfe798c5c37d0d22cca86a1f9` |

### Second Sleep

| Original filename | Actual format / codec | Duration | Size | Bitrate | Sample rate / channels / depth | SHA-256 |
|---|---|---:|---:|---:|---|---|
| `SP Episode Test 1 240bit 48kHz .wav` | WAV / `pcm_s16le` | 360.048625 s | 69,129,414 B (65.93 MiB) | 1,536,000 bps | 48,000 Hz / stereo / 16-bit | `8b62e7837b5f0f98118bc82ec6ae3b11c57c47a38751306893e3de9b5549ff2a` |
| `SP Episode Test 1.mp3.mpeg` | MP3 / `mp3` | 360.048617 s | 14,405,109 B (13.74 MiB) | 320,000 bps | 44,100 Hz / stereo / n/a | `790cebaf26c5c12e38cf3a0e1a2cea661b872f676cd1fff998130e8758780a9a` |

### Slow Unwind

| Original filename | Actual format / codec | Duration | Size | Bitrate | Sample rate / channels / depth | SHA-256 |
|---|---|---:|---:|---:|---:|---|
| `Slow Unwind 240bit PCM, 48kHz(1).wav` | WAV / `pcm_s16le` | 5170.642729 s | 992,763,482 B (946.77 MiB) | 1,536,000 bps | 48,000 Hz / stereo / 16-bit | `8a4c6a4436cf5a5dc2d3b4e43b6d3cf63ec933f6f18454556a756d465d2d6f04` |
| `Slow Unwind.mp3 (1).mpeg` | MP3 / `mp3` | 5170.642721 s | 206,828,293 B (197.25 MiB) | 320,000 bps | 44,100 Hz / stereo / n/a | `f2a37a5aa09c6771c226997f05b057b7610ac1be8059ae85d742dc9c7561501d` |

### `ios/Resources/Provided audio` (category not supplied)

These files are inspected because they were explicitly requested, but their
filenames do not establish whether they are Morning Alarm, Notification,
Quick Unwind, Second Sleep, Slow Unwind, or personal audio. They are not
assigned to a delivery class.

| Original filename | Actual format / codec | Duration | Size | Bitrate | Sample rate / channels / depth | SHA-256 |
|---|---|---:|---:|---:|---|---|
| `Moonlit Forest Journey SP (2).mp3.mpeg` | MP3 / `mp3` | 5185.224853 s | 207,411,346 B (197.80 MiB) | 320,000 bps | 44,100 Hz / stereo / n/a | `31c632c01144cd909e989f52e987b987fa706e8b48de1b404169f12c896633f7` |
| `Short Audio.mp3.mpeg` | MP3 / `mp3` | 482.115918 s | 19,286,872 B (18.39 MiB) | 320,000 bps | 44,100 Hz / stereo / n/a | `7e28e5e72097bda9609a6d4e3be0ee513a7d6e2e685bc65e67b2c283de947d74` |

## Duplicate and alternate-encoding analysis

Exact byte duplicate test: none. All 20 SHA-256 values are unique.

Likely alternate-encoding groups:

- `Felt_Dawn...`: 30.040833-second mono 48 kHz 16-bit CAF and
  30.040792-second stereo 44.1 kHz MP3.
- `Morning_Stillness...`: same container/profile pattern and duration as the
  Felt Dawn pair, but distinct hashes; it is a separate candidate, not an
  exact duplicate.
- `Morning_Echoes...` and `Stone_Echoes...`: each has a CAF/MP3 pair with
  matching duration/profile; the two names have distinct hashes and should be
  treated as separate candidates.
- `Morning Meadow Radiance`: 180-second stereo WAV and 180-second mono CAF;
  same title-like stem and duration, but different channel layout and hashes.
- `7`: 2-second CAF/MP3 pair.
- `Quick Unwind`, `SP Episode Test 1`, and `Slow Unwind`: each has a WAV/MP3
  pair with matching duration; these are the long-session source/encoding
  variants.

The names and durations are sufficient to flag variants for review, not to
prove audio equivalence. No content-level duplicate claim should be made until
the source owner confirms the production chain or a dedicated perceptual audio
comparison is approved.

## Decisions requiring explicit product or cross-functional approval

1. Select the bundled default morning alarm from the five candidates:
   Felt Dawn (30 s), Morning Stillness (30 s), Morning Echoes (60 s), Stone
   Echoes (60 s), and Morning Meadow Radiance (180 s). This audit intentionally
   does not select one.
2. Decide which remaining morning candidates are exposed as choices and confirm
   that each is fully downloaded, hash/type/decoder verified, and locally
   available before a schedule can use it.
3. Approve the `7.mp3.caf` notification candidate, its exact bundle/resource
   name, and notification behavior on physical devices.
4. Map or reject the two provided-resource files. Their category, title,
   locale, slot, and production status are not established by the checkout.
5. Confirm whether the WAV files are authoritative masters. The filenames say
   `240bit`, but the media headers report 16-bit PCM; this discrepancy requires
   source-owner clarification and must not be “fixed” by changing originals.
6. Approve AAC-LC M4A transcode settings and mastering results for Quick Unwind,
   Second Sleep, and Slow Unwind. Keep the WAV/MP3 source files unchanged and
   outside Git; create versioned deliveries only after approval.
7. Supply creator, performer, producer, rights owner, license/assignment,
   territory, App Store, offline-cache, mastering/modification, term,
   third-party-work, contact, script/transcript, silent-equivalent, claims,
   accessibility, and review-due evidence for every proposed shipping asset.
8. Approve loudness/true-peak targets, safe transitions, and the physical-device
   test matrix for AlarmKit, notifications, lock state, silent/Focus modes,
   restart, interruptions, and route changes. Simulator or static evidence is
   not physical-device proof.
9. Resolve storage governance for the untracked 18-file `Audio Assets/`
   directory before any Git operation. No binary master should be staged or
   committed without an approved protected storage path and redistribution
   rights.
10. Reconcile the eventual shipping asset with the current source expectation
    `SPCWakeUpGentleLoop.caf` and the placeholder catalog entries; no code or
    Audio Library UI change was made in this audit.

## Commands and evidence

The audit ran these read-only checks from the repository checkout:

- `Get-ChildItem -Recurse -File -Force` over both requested directories for
  complete file enumeration.
- `ffprobe.exe -v error -show_entries ... -of json -- <file>` for each of the
  20 files. The probe executable reports FFmpeg `8.0.1`.
- `Get-FileHash -Algorithm SHA256 -LiteralPath <file>` for every file.
- `git status --short --untracked-files=all` and `git check-ignore` to inspect
  repository exposure without staging or changing anything.
- Constrained PowerShell `Select-String` inspection of the requested README,
  audio contract, relevant source, and project resource configuration.

Aggregate size of all 20 variants is 1,674,806,362 bytes (approximately
1,597.22 MiB). Aggregate duration counts alternate encodings separately and is
18,239.325 seconds. The 18 intake files alone are approximately 1.38 GiB.

## Changed files and blockers

Changed by this audit:

- `docs/AUDIO_ASSET_AUDIT_2026-08-16.md` (this report)
- `docs/AUDIO_ASSET_MANIFEST_2026-08-16.json` (machine-readable manifest)

No original audio file, source file, project configuration, or existing dirty
worktree file was modified. The pre-existing dirty worktree was preserved.

Blocking items are the missing rights/provenance/approval records, missing
AAC-LC M4A deliveries, no approved default alarm, no exact
`SPCWakeUpGentleLoop.caf`, no physical-device proof, unresolved `240bit` vs
16-bit master provenance, unassigned provided-resource files, and the unsafe
untracked storage position of the large intake binaries.
