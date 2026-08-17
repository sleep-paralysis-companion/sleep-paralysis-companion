import { catalogManifest } from "../_shared/audio_catalog.ts";

const headers = {
  "Access-Control-Allow-Origin": "*",
  "Cache-Control": "public, max-age=300, must-revalidate",
  "Content-Type": "application/json; charset=utf-8",
};

Deno.serve((request) => {
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
    return new Response(JSON.stringify({ error: "method_not_allowed" }), {
      status: 405,
      headers,
    });
  }

  return new Response(JSON.stringify(catalogManifest), {
    status: 200,
    headers,
  });
});
