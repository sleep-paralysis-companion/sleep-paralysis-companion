# Audio production approval

Date: 2026-08-17
Scope: the curated audio library, bundled system sounds, remote catalog
deliveries, and the first Supabase delivery contract.

This record supersedes the earlier staging-only approval labels for the
assets listed below. The derived staging files remain the evidence source for
the byte counts, hashes, decode checks, duration checks, and source-unchanged
checks.

## Product decisions

- `Felt Dawn` is the bundled default morning alarm because its verified CAF is
  the smallest alarm delivery at 2,884,207 bytes.
- `Audio Assets/Notification Sound/7.mp3.caf` is the approved notification
  source. Its user-facing name is `Notification`, and the bundled resource is
  `SPCNotification.caf`.
- `Morning Stillness`, `Morning Echoes`, `Stone Echoes`, and
  `Morning Meadow Radiance` are remote catalog choices. They are not bundled;
  each has a verified full CAF delivery and 30-second AAC-LC M4A preview.
- `Quick Unwind`, `Second Sleep`, and `Slow Unwind` are remote catalog
  choices with verified full M4A and preview deliveries.

## Rights and content declaration

The product owner confirms that the supplied assets are owned or controlled
for Sleep Paralysis Companion use. This approval covers App Store
distribution, worldwide availability, offline caching, transcoding into the
approved delivery formats, streaming previews, and downloadable full
deliveries. The manifest uses `Sleep Paralysis Companion` as the rights-owner
label and the dated references `audio-owner-supplied-2026-08-17` and
`owner-authorized-app-store-worldwide-offline-transcode-2026-08-17`.

Transcripts, silent-equivalent metadata, accessibility review, mastering
review, and subjective listening review are treated as product QA records;
they are not invented from file metadata. They must be completed before a
public release if the relevant experience requires them.

## Delivery boundary

- The app bundle contains only `SPCWakeUpGentleLoop.caf` and
  `SPCNotification.caf`.
- The four non-default alarms and the three long-form sessions are private
  catalog objects in the `audio-catalog` bucket. Alarm full deliveries remain
  48 kHz mono CAF so they can pass the local AlarmKit preflight; their
  streamable previews are AAC-LC M4A.
- The app receives only the public manifest and short-lived signed URLs. A
  service-role key is never placed in iOS configuration, the manifest, or the
  repository.
- The raw `Audio Assets/` directory and derived staging binaries remain
  ignored and outside Git. The upload script verifies each delivery hash
  before sending it to Supabase.

## Evidence still intentionally pending

GitHub Actions can validate the repository, migrations, Edge Functions, and
the macOS Xcode build. TestFlight is still required for physical-device
proof of lock state, terminated-app behavior, restart, Silent mode, Focus,
interruptions, Bluetooth/headphones, alarm playback, notification delivery,
corrupt/missing assets, and offline scheduling. No device result is claimed
by this approval record.
