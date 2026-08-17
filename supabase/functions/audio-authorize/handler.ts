import {
  AUDIO_CATALOG_DOWNLOAD_TTL_SECONDS,
  AUDIO_CATALOG_SIGNED_URL_TTL_SECONDS,
  type AudioCatalogPurpose,
  catalogAsset,
} from "../_shared/audio_catalog.ts";

export type SignedURLResult = {
  signedUrl: string;
};

export type AudioAuthorizationRuntime = {
  createSignedURL: (
    path: string,
    expiresInSeconds: number,
  ) => Promise<{ data: SignedURLResult | null; error: Error | null }>;
};

const headers = {
  "Access-Control-Allow-Origin": "*",
  "Content-Type": "application/json; charset=utf-8",
};

export async function handleAudioAuthorization(
  request: Request,
  runtime: AudioAuthorizationRuntime,
): Promise<Response> {
  if (request.method === "OPTIONS") {
    return new Response(null, {
      status: 204,
      headers: {
        ...headers,
        "Access-Control-Allow-Headers": "content-type",
        "Access-Control-Allow-Methods": "GET, OPTIONS",
      },
    });
  }

  if (request.method !== "GET") {
    return response(405, { error: "method_not_allowed" });
  }

  const url = new URL(request.url);
  const assetID = url.searchParams.get("asset_id");
  const contentVersion = Number(url.searchParams.get("content_version"));
  const purpose = url.searchParams.get("purpose") as AudioCatalogPurpose | null;
  if (
    !assetID ||
    !Number.isInteger(contentVersion) ||
    contentVersion < 1 ||
    !purpose ||
    !["preview", "full_download"].includes(purpose)
  ) {
    return response(400, { error: "invalid_request" });
  }

  const asset = catalogAsset(assetID);
  if (
    !asset ||
    asset.status !== "approved" ||
    asset.delivery !== "downloadable" ||
    asset.content_version !== contentVersion
  ) {
    return response(404, { error: "asset_unavailable" });
  }

  const path = purpose === "preview"
    ? asset.preview_path_id
    : asset.download_path_id;
  if (!path) {
    return response(404, { error: "asset_unavailable" });
  }

  const expiresInSeconds = purpose === "preview"
    ? AUDIO_CATALOG_SIGNED_URL_TTL_SECONDS
    : AUDIO_CATALOG_DOWNLOAD_TTL_SECONDS;
  const signed = await runtime.createSignedURL(path, expiresInSeconds);
  if (signed.error || !signed.data?.signedUrl) {
    return response(502, { error: "authorization_unavailable" });
  }

  return response(200, {
    url: signed.data.signedUrl,
    expires_in_seconds: String(expiresInSeconds),
  });
}

function response(status: number, body: Record<string, string>): Response {
  return new Response(JSON.stringify(body), { status, headers });
}
