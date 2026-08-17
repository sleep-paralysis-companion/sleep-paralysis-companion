export const AUDIO_CATALOG_BUCKET = "audio-catalog";
export const AUDIO_CATALOG_SIGNED_URL_TTL_SECONDS = 900;
export const AUDIO_CATALOG_DOWNLOAD_TTL_SECONDS = 3600;

export type AudioCatalogPurpose = "preview" | "full_download";

export type AudioCatalogAsset = {
  id: string;
  content_version: number;
  manifest_version: number;
  category:
    | "morning_alarm"
    | "notification"
    | "quick_unwind"
    | "second_sleep"
    | "slow_unwind";
  title: string;
  short_description: string;
  locale_identifier: string;
  delivery: "bundled" | "downloadable";
  status: "approved" | "revoked" | "retired";
  duration_milliseconds: number;
  byte_count: number;
  mime_type: string;
  codec: string;
  sample_rate_hz: number;
  channels: number;
  sha256: string;
  preview_path_id: string | null;
  download_path_id: string | null;
  offline_cache_allowed: boolean;
  bundled_resource_name: string | null;
  minimum_app_version: string | null;
  minimum_catalog_schema: number;
  provenance_reference: string;
  rights_reference: string;
  approval_reference: string;
};

export type AudioCatalogManifest = {
  manifest_version: number;
  minimum_app_version: string;
  assets: AudioCatalogAsset[];
};

const provenanceReference = "audio-owner-supplied-2026-08-17";
const rightsReference =
  "owner-authorized-app-store-worldwide-offline-transcode-2026-08-17";
const approvalReference = "audio-product-approval-2026-08-17";

function bundledAsset(
  id: string,
  category: AudioCatalogAsset["category"],
  title: string,
  shortDescription: string,
  durationMilliseconds: number,
  byteCount: number,
  sha256: string,
  bundledResourceName: string,
): AudioCatalogAsset {
  return {
    id,
    content_version: 1,
    manifest_version: 1,
    category,
    title,
    short_description: shortDescription,
    locale_identifier: "en",
    delivery: "bundled",
    status: "approved",
    duration_milliseconds: durationMilliseconds,
    byte_count: byteCount,
    mime_type: "audio/x-caf",
    codec: "pcm_s16le",
    sample_rate_hz: 48000,
    channels: 1,
    sha256,
    preview_path_id: null,
    download_path_id: null,
    offline_cache_allowed: false,
    bundled_resource_name: bundledResourceName,
    minimum_app_version: "1.0.0",
    minimum_catalog_schema: 1,
    provenance_reference: provenanceReference,
    rights_reference: rightsReference,
    approval_reference: approvalReference,
  };
}

function downloadableAsset(
  id: string,
  category: AudioCatalogAsset["category"],
  title: string,
  shortDescription: string,
  durationMilliseconds: number,
  byteCount: number,
  sha256: string,
  previewPathId: string,
  downloadPathId: string,
): AudioCatalogAsset {
  return {
    id,
    content_version: 1,
    manifest_version: 1,
    category,
    title,
    short_description: shortDescription,
    locale_identifier: "en",
    delivery: "downloadable",
    status: "approved",
    duration_milliseconds: durationMilliseconds,
    byte_count: byteCount,
    mime_type: "audio/mp4",
    codec: "aac-lc",
    sample_rate_hz: 44100,
    channels: 2,
    sha256,
    preview_path_id: previewPathId,
    download_path_id: downloadPathId,
    offline_cache_allowed: true,
    bundled_resource_name: null,
    minimum_app_version: "1.0.0",
    minimum_catalog_schema: 1,
    provenance_reference: provenanceReference,
    rights_reference: rightsReference,
    approval_reference: approvalReference,
  };
}

function downloadableAlarmAsset(
  id: string,
  title: string,
  shortDescription: string,
  durationMilliseconds: number,
  byteCount: number,
  sha256: string,
  previewPathId: string,
  downloadPathId: string,
): AudioCatalogAsset {
  return {
    id,
    content_version: 1,
    manifest_version: 1,
    category: "morning_alarm",
    title,
    short_description: shortDescription,
    locale_identifier: "en",
    delivery: "downloadable",
    status: "approved",
    duration_milliseconds: durationMilliseconds,
    byte_count: byteCount,
    mime_type: "audio/x-caf",
    codec: "pcm_s16le",
    sample_rate_hz: 48000,
    channels: 1,
    sha256,
    preview_path_id: previewPathId,
    download_path_id: downloadPathId,
    offline_cache_allowed: true,
    bundled_resource_name: null,
    minimum_app_version: "1.0.0",
    minimum_catalog_schema: 1,
    provenance_reference: provenanceReference,
    rights_reference: rightsReference,
    approval_reference: approvalReference,
  };
}

export const catalogManifest: AudioCatalogManifest = {
  manifest_version: 1,
  minimum_app_version: "1.0.0",
  assets: [
    bundledAsset(
      "felt-dawn",
      "morning_alarm",
      "Felt Dawn",
      "The compact bundled default wake-up sound.",
      30041,
      2884207,
      "202b416ac3066ef272baa856d30d817e7686412b0fef5b78f5531c252f40d42c",
      "SPCWakeUpGentleLoop.caf",
    ),
    downloadableAlarmAsset(
      "morning-stillness",
      "Morning Stillness",
      "A downloadable gentle wake-up choice.",
      30041,
      2884215,
      "33b713bbcd5d51e9304f6a2e88df33ebc2e311d7cb13c6deb565fd4590661c5a",
      "previews/morning-stillness/v1/preview.m4a",
      "system-sounds/morning-stillness/v1/full.caf",
    ),
    downloadableAlarmAsset(
      "morning-echoes",
      "Morning Echoes",
      "A longer downloadable wake-up choice with a spacious tone.",
      60029,
      5763114,
      "ce9435424db0fedf933f0a805e894392261cd42c90c0aab44590285e4ab78086",
      "previews/morning-echoes/v1/preview.m4a",
      "system-sounds/morning-echoes/v1/full.caf",
    ),
    downloadableAlarmAsset(
      "stone-echoes",
      "Stone Echoes",
      "A downloadable wake-up choice with a grounded, resonant character.",
      60029,
      5763112,
      "9cbd727954f47f4e584f61346d2779aac9580ac84ecdade7681b61b4d8055423",
      "previews/stone-echoes/v1/preview.m4a",
      "system-sounds/stone-echoes/v1/full.caf",
    ),
    downloadableAlarmAsset(
      "morning-meadow-radiance",
      "Morning Meadow Radiance",
      "The extended downloadable wake-up choice.",
      180000,
      17280301,
      "f2d9ddc563d8e49001aac68ae0b94ae3f9fc64e863d4046ba5714bb22464e6a6",
      "previews/morning-meadow-radiance/v1/preview.m4a",
      "system-sounds/morning-meadow-radiance/v1/full.caf",
    ),
    bundledAsset(
      "notification",
      "notification",
      "Notification",
      "The bundled short notification sound.",
      2000,
      192292,
      "6359c2edc965029a953c2050230be47381e977c6d3b3d7ce4761dbc332256ed8",
      "SPCNotification.caf",
    ),
    downloadableAsset(
      "quick-unwind",
      "quick_unwind",
      "Quick Unwind",
      "A short guided reset for settling the body and attention.",
      393160,
      9655675,
      "3c2e9fcad44eae60fad8aed98c36352db42a0be828b8ad8f807952e2044f27fd",
      "previews/quick-unwind/v1/preview.m4a",
      "catalog/quick-unwind/v1/full.m4a",
    ),
    downloadableAsset(
      "second-sleep",
      "second_sleep",
      "Second Sleep",
      "A compact session for returning to rest after waking.",
      360048,
      8564581,
      "55afb320f05df055a95d150d9254a9cb807ed587bcf21ec242dd87ea2c9b4798",
      "previews/second-sleep/v1/preview.m4a",
      "catalog/second-sleep/v1/full.m4a",
    ),
    downloadableAsset(
      "slow-unwind",
      "slow_unwind",
      "Slow Unwind",
      "The long-form catalog session for a slower transition into rest.",
      5170642,
      127511150,
      "0b037f01263d923e59775f665aca32583b796e4241abce5b3b6a6fd08ba5df45",
      "previews/slow-unwind/v1/preview.m4a",
      "catalog/slow-unwind/v1/full.m4a",
    ),
  ],
};

export function catalogAsset(assetID: string): AudioCatalogAsset | null {
  return catalogManifest.assets.find((asset) => asset.id === assetID) ?? null;
}
