# Audio blocker resolution

Date: 2026-08-16
Scope: curated audio library, catalog delivery, system-sound candidates, and
runtime configuration.

Status note: the product and rights decisions recorded as open in this
historical staging report were resolved on 2026-08-17. See
`docs/AUDIO_PRODUCTION_APPROVAL_2026-08-17.md` for the current decision record.
The device and hosted-CI evidence items remain open by design.

## Resolved technical blockers

### Delivery artifacts

The derived staging generator was run after disk space was cleared. It created
12 candidate delivery files under
`Audio Assets/Derived Staging/2026-08-16/`:

- three full AAC-LC M4A catalog deliveries;
- three 30-second AAC-LC M4A previews;
- five mono 48 kHz 16-bit PCM CAF alarm candidates; and
- one mono 48 kHz 16-bit PCM CAF notification candidate.

All generated files decoded successfully, preserved their expected durations,
passed the media-property checks, passed the non-silence check, and received
SHA-256 hashes. The original source hashes were unchanged after generation.
The full catalog delivery total is 138.98 MiB and the preview total is
1.759 MiB.

This is technical delivery evidence only. It is not rights, content,
mastering, physical-device, or production approval.

### System-sound approval firewall

The candidate `SPCWakeUpGentleLoop.caf` and `SPCNotification.caf` files remain
available for later validation but are excluded from the iOS app target until
product, rights, and physical-device approvals are recorded. The runtime keeps
the local-only preflight and falls back to unavailable/system-default behavior
instead of silently treating a candidate as approved.

### Catalog runtime wiring

The app now has explicit public configuration keys for:

- catalog manifest URL;
- authorized-audio URL endpoint; and
- allowed catalog hosts.

When these values are absent, the library remains honestly unavailable. When a
valid configuration is supplied, the app constructs the existing verified
manifest, cache, checksum, and download service through the app composition
root instead of permanently using the unavailable stub.

No endpoint, host, or secret was invented in this change.

## Intentionally unresolved approval blockers

These cannot be fixed from filenames or local technical inspection:

1. Choose and approve one morning-alarm candidate as the bundled default.
2. Approve Notification 7 as the bundled notification candidate, including its
   final resource name and behavior.
3. Approve which remaining alarm candidates may be offered as downloadable
   choices.
4. Provide rights, provenance, creator/performer, territory, offline-cache,
   modification, transcript, silent-equivalent, accessibility, mastering, and
   review records for every shipping asset.
5. Approve the AAC-LC M4A mastering settings and final deliveries.
6. Provide the real manifest and authorization endpoint hosts, or authorize the
   separately scoped backend/storage implementation.

## Evidence blockers

No Windows run can close these:

- simulator build/test evidence;
- hosted macOS Xcode build evidence;
- locked-device and terminated-app behavior;
- restart, Silent mode, Focus, interruption, Bluetooth/headphone, and route
  behavior;
- alarm during catalog playback;
- notification delivery;
- missing/corrupt asset handling on device; and
- offline scheduling and alarm playback.

These remain explicitly unclaimed rather than being inferred from static
source or generated-file checks.

## Worktree and storage status

- The large `Audio Assets/` directory remains ignored and unstaged.
- Original masters were not renamed, overwritten, moved, deleted, or added to
  Git.
- Unrelated dirty worktree changes were preserved.
- Generated files remain in ignored staging and are not automatically part of
  the app target.

## Current truthful status

The audio feature is technically prepared for approval and endpoint
configuration. It is not yet production-ready because the content/rights
decisions, live catalog host, hosted/device evidence, and final system-audio
approvals are still open.
