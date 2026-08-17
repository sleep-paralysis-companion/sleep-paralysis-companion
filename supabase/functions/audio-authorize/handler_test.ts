import { assertEquals } from "jsr:@std/assert@1.0.14";
import {
  type AudioAuthorizationRuntime,
  handleAudioAuthorization,
} from "./handler.ts";

Deno.test("authorizes a preview only for an approved downloadable asset", async () => {
  const calls: Array<{ path: string; expiresInSeconds: number }> = [];
  const result = await handleAudioAuthorization(
    new Request(
      "https://project.example/functions/v1/audio-authorize?asset_id=quick-unwind&content_version=1&purpose=preview",
      { method: "GET" },
    ),
    fakeRuntime(calls),
  );

  assertEquals(result.status, 200);
  assertEquals(calls, [{
    path: "previews/quick-unwind/v1/preview.m4a",
    expiresInSeconds: 900,
  }]);
  assertEquals(await result.json(), {
    url: "https://project.example/signed/preview.m4a",
    expires_in_seconds: "900",
  });
});

Deno.test("uses the longer expiry only for a full downloadable delivery", async () => {
  const calls: Array<{ path: string; expiresInSeconds: number }> = [];
  const result = await handleAudioAuthorization(
    new Request(
      "https://project.example/functions/v1/audio-authorize?asset_id=slow-unwind&content_version=1&purpose=full_download",
      { method: "GET" },
    ),
    fakeRuntime(calls),
  );

  assertEquals(result.status, 200);
  assertEquals(calls, [{
    path: "catalog/slow-unwind/v1/full.m4a",
    expiresInSeconds: 3600,
  }]);
});

Deno.test("does not authorize bundled system sounds through Storage", async () => {
  const calls: Array<{ path: string; expiresInSeconds: number }> = [];
  const result = await handleAudioAuthorization(
    new Request(
      "https://project.example/functions/v1/audio-authorize?asset_id=felt-dawn&content_version=1&purpose=full_download",
      { method: "GET" },
    ),
    fakeRuntime(calls),
  );

  assertEquals(result.status, 404);
  assertEquals(calls, []);
});

Deno.test("rejects malformed requests before signing", async () => {
  const calls: Array<{ path: string; expiresInSeconds: number }> = [];
  const result = await handleAudioAuthorization(
    new Request("https://project.example/functions/v1/audio-authorize", {
      method: "POST",
    }),
    fakeRuntime(calls),
  );

  assertEquals(result.status, 405);
  assertEquals(calls, []);
});

function fakeRuntime(
  calls: Array<{ path: string; expiresInSeconds: number }>,
): AudioAuthorizationRuntime {
  return {
    createSignedURL: (path, expiresInSeconds) => {
      calls.push({ path, expiresInSeconds });
      return {
        data: { signedUrl: "https://project.example/signed/preview.m4a" },
        error: null,
      };
    },
  };
}
