# Audio Catalog and Offline Contract

**Contract ID:** `AUDIO-P1-001`  
**Status:** Delivery/lifecycle contract complete; candidate assets reported
available but not yet received, hashed, rights-reviewed, or approved
**Updated:** 28 July 2026

## 1. Boundary

Phase 1 audio is playback of preapproved publisher-controlled grounding or
preparation content. It does not include:

- microphone access;
- personal, partner, ambient, overnight, or background recording;
- upload/import from Photos, Files, contacts, social media, or messaging;
- speech recognition, classification, transcription of a person's voice, or
  AI generation;
- streaming as a dependency for the manual grounding path;
- unlicensed YouTube/audio references from the PRD;
- claims that a sound detects, prevents, treats, protects, induces recovery, or
  produces a guaranteed sleep outcome; or
- a listening-history or wellness-outcome record.

The app must ship without `NSMicrophoneUsageDescription`, recording code paths,
and audio-input configuration.

## 2. Catalog classes

### Minimum bundle

These are catalog slots, not approved shipping assets. The user has authorized
clearly labeled placeholders for current documentation and the disposable
physical-feasibility spike. That spike may use only owned synthetic local
audio and neutral placeholder instructions. A placeholder cannot support a
content, benefit, rights, provenance, or production-offline claim.

On 28 July 2026 Satyam Shree reported that candidate audio assets are
available. The files have not yet entered the repository intake, so this report
does not close any content, rights, provenance, mastering, accessibility, or
device-evidence requirement. Originals must be delivered through
`assets/audio/incoming/` with the accompanying manifest described there.

| Slot ID | Required role | Delivery | Maximum target | Status |
|---|---|---|---|---|
| `AUD-SLOT-001` | Silent visual/text grounding sequence | App UI/resources | Short, low-cognitive-load sequence | Role approved by Satyam Shree 25 July 2026; final content pending |
| `AUD-SLOT-002` | Short spoken grounding instructions with synchronized transcript | Bundled local audio | Target ≤3 minutes and compressed size approved by iOS lead | Role approved; script, voice, rights, mastering pending |
| `AUD-SLOT-003` | Nonverbal low-complexity grounding sound with textual/silent equivalent | Bundled local audio | Target ≤5 minutes | Role approved; composition, rights, mastering pending |

The bundle must be sufficient for a useful offline manual path. Downloaded
content may enrich preparation but cannot be the only useful grounding option.

### Optional downloadable catalog

Downloadable items may include longer preparation, ambient, or alternate-locale
content only after:

- Content/Claims approves title, description, script/transcript, and intended
  context;
- rights owner approves distribution, offline caching, territory, duration,
  modification/mastering, and App Store use;
- Accessibility approves the equivalent;
- Privacy confirms no hidden tracking in URLs/files;
- Security verifies origin/integrity/revocation design; and
- Product assigns premium access; only the alarm and utility routes are free.

No remote manifest item becomes visible merely because a backend row exists.
The app accepts only a signed/versioned catalog schema and approved state.

## 3. Asset record

Each shipping item has an immutable ID `AUD-ASSET-NNN` and:

| Field | Required purpose |
|---|---|
| `asset_id`, `content_version`, `manifest_version` | Stable identity and update |
| `status` | `draft`, `approved`, `revoked`, or `retired` |
| `title`, `short_description`, `locale`, `content_type` | User display and accessibility |
| `script_id`, `transcript_id`, `claims_approval_id` | Trace exact reviewed meaning |
| `source_creator`, `rights_owner`, `license_id` | Provenance |
| `territories`, `license_start`, `license_end`, `offline_cache_allowed` | Enforce rights |
| `delivery` | `bundled` or `downloadable` |
| `premium_class` | `premium` or retired |
| `duration_ms`, `byte_size`, `mime_type`, `codec`, `sample_rate`, `channels` | Playback/storage truth |
| `integrated_loudness`, `true_peak` | Mastering/safe consistency review |
| `sha256` | Byte integrity |
| `minimum_app_version`, `minimum_catalog_schema` | Compatibility |
| `download_path_id` | Server-side path reference; never a permanent public URL |
| `approved_by`, `approved_at`, `review_due_at` | Content/rights governance |
| `silent_equivalent` | Equivalent instructions or explicit “no spoken meaning” |

An asset ID/version is immutable once released. New bytes require a new version
and hash. A title-only edit still requires catalog versioning.

## 4. Rights and provenance file

For each item, retain outside the client:

- signed license/assignment or proof of in-house ownership;
- creator/performer releases;
- music/composition/master rights as applicable;
- permitted territories, platforms, offline caching, modification, term, and
  revocation conditions;
- original source and production chain;
- approved script/transcript and translations;
- mastering/quality report;
- claims/accessibility approvals; and
- the asset hash delivered in each app/catalog version.

“Royalty free,” a purchase receipt, Creative Commons label, meeting approval, or
a YouTube URL is not by itself sufficient rights evidence. Legal/rights owner
must record the actual license fit.

## 5. Download and installation protocol

1. Fetch the versioned catalog over TLS.
2. Validate schema, catalog version, approval state, app compatibility, rights
   window/territory rule, entitlement, and declared size before offering
   download.
3. Request a short-lived authorized download URL. Do not log it.
4. Check available storage against file size plus safe installation margin.
5. Download to a protected temporary file.
6. Support explicit cancellation and bounded retry; partial bytes never appear
   in the playable cache.
7. Validate HTTP status, content length where available, maximum size, MIME,
   decoder support, and SHA-256.
8. Move into a versioned protected cache atomically.
9. Commit the cache index only after the move succeeds.
10. Revalidate hash before first playback and after restore/migration anomaly.
11. Remove temp bytes on success, cancellation, failure, and next-launch
    recovery.
12. Record only operational result/category; do not create listening history.

Redirects to unapproved hosts, cleartext HTTP, embedded credentials, permanent
signed URLs, mismatched type/size/hash, decompression bombs, unsupported codec,
expired/revoked rights, and path traversal are hard failures.

## 6. Cache policy

| Rule ID | Rule |
|---|---|
| `AUD-CACHE-001` | Bundled minimum content is not part of the evictable cache. |
| `AUD-CACHE-002` | Display exact downloaded size and a user Remove action. |
| `AUD-CACHE-003` | Eviction may remove only optional downloaded assets and never the currently playing asset. |
| `AUD-CACHE-004` | Use least-recently-accessed eviction only for storage pressure; “accessed” remains device-local and is not analytics. |
| `AUD-CACHE-005` | Do not redownload automatically on cellular unless Product explicitly approves the setting and copy. Default is user initiation. |
| `AUD-CACHE-006` | A catalog revocation prevents new starts and schedules safe removal after current playback; a security-critical revocation may stop playback with approved neutral copy. |
| `AUD-CACHE-007` | Entitlement expiry prevents new premium starts but does not silently delete bytes until normal cleanup; bytes are not directly user-accessible. |
| `AUD-CACHE-008` | Account sign-out does not control audio entitlement; RevenueCat maps Apple purchase state to the app entitlement. |
| `AUD-CACHE-009` | Delete local app data removes all optional cached bytes and index/temp files. |
| `AUD-CACHE-010` | Backup inclusion/exclusion and iOS file-protection class are selected and verified against locked playback; no assumption is accepted without physical evidence. |

## 7. Playback state machine

```text
idle
├─ prepare → ready → playing ↔ paused
│                    ├→ interrupted → paused or approved resume
│                    ├→ route_changed → paused/reconfigured
│                    ├→ background/locked → continue or pause per proven mode
│                    └→ ended → complete
├─ unavailable → silent visual fallback
└─ failed_integrity/decoder/session → silent visual fallback + recovery
```

Rules:

- ordinary app launch never autoplays;
- playback begins only after the manual action or an explicit item selection;
- system volume and mute state are not overridden deceptively;
- do not promise mixing, background, locked, Bluetooth, AirPlay, headphone,
  call, Siri, or alarm interaction until tested;
- headphone removal follows the approved pause rule;
- call/Siri/system interruption never produces overlapping duplicate audio;
- any automatic resume rule requires explicit UX approval and device evidence;
- repeated manual activation resolves to the one current session;
- Stop is always reachable and clears now-playing state as appropriate;
- visual/silent instructions remain available when audio fails; and
- the app does not log completion as improvement or episode outcome.

## 8. Offline truth table

| Situation | Bundled visual/audio | Downloaded item | Network item not cached | Required UI |
|---|---|---|---|---|
| Online, entitled | Available | Available if verified | Offer download | Exact local/download state |
| Offline, entitled from trustworthy cached state | Available | Available if verified | Unavailable | “Not downloaded”; offer bundled/silent |
| Offline, commercial authority unknown | Utility-free behavior plus bundle only if commercial policy grants it; see access contract | Do not start premium item without authority | Unavailable | Explain that access could not be verified; never delete bytes |
| Asset hash/type invalid | Other bundle available | Quarantine/remove invalid version | N/A | Neutral error and silent/bundled alternative |
| Storage full during download | Available | Existing verified assets unchanged | Download fails | Required space/retry/remove options |
| Catalog unavailable | Available | Previously verified items follow cached rights/entitlement policy | Cannot discover new items | Library identifies cached state |
| Rights/security revocation | Nonrevoked bundle available | Block affected new playback; remove by policy | N/A | Content unavailable; no clinical/safety implication |
| App update/migration interrupted | Bundle available | Validate/rebuild cache index | N/A | No corrupt item becomes ready |

“Works offline” may only be used as the feature-specific statement in
`CLM-017`, never as an unqualified app-wide guarantee.

## 9. System interaction test protocol

Physical tests must cover every supported device/OS with:

- ring/silent modes and several volume levels;
- Focus enabled/disabled;
- screen unlocked/locked, Always-On display if applicable, and device restart;
- app foreground/background/suspended/terminated/not previously launched after
  reboot;
- AlarmKit alert occurring before/during/after grounding playback;
- incoming call, Siri, another audio app, route change, wired/Bluetooth
  headphone connect/disconnect, and AirPlay if exposed;
- network online/offline/poor, backend unavailable, and download interruption;
- storage pressure, corrupt/truncated/wrong-type file, catalog update/revocation;
- Dynamic Type, VoiceOver, Reduce Motion, and silent visual equivalent;
- trial, subscription, lifetime, known-expiration reminder, immediate cutoff,
  expired/refunded/revoked, and authority-unknown states; and
- locale/RTL script and supported audio locales.

Record start latency, interruption result, duplicate/overlap, lock behavior,
actual route, control availability, privacy of system surfaces, and recovery.

## 10. Content approval checklist

Each script/transcript must:

- use the approved claims matrix;
- avoid asserting wakefulness, safety, diagnosis, episode completion, clinical
  recovery, prevention, treatment, protection, or guaranteed calm;
- be optional and noncoercive;
- avoid breath-hold or physical instructions without Safety review;
- avoid startling sounds, abrupt level changes, or hidden high frequencies;
- use plain language and short instructions;
- have a readable silent equivalent with equivalent choices;
- be reviewed in every localization, not translated without contextual review;
  and
- identify how a person exits or chooses another modality.

## 11. Current-phase and shipping gates

Gate 0 may use `AUD-SLOT-001`–`003` and owned synthetic spike audio to approve
the delivery architecture, offline mechanics, file protection, audio session,
interruption, accessibility, and system-surface behavior. Gate 0 still requires
the catalog roles, bundle/download boundary, claims rules, and evidence
protocol to be approved; placeholders do not waive those decisions.

Before real content is integrated into a release candidate:

- concrete items replace `AUD-SLOT-001`–`003`;
- every asset record and rights file is complete;
- scripts, transcripts, titles, descriptions, and translations are approved;
- bundle size, optional downloads, and commercial class are approved;
- privacy/security reviews approve download hosts and manifest;
- app file-protection/background-audio configuration has physical evidence;
  and
- the full system interaction matrix passes with the actual shipping assets on
  the chosen target.
