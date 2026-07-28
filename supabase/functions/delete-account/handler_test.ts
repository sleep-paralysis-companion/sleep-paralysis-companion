import { assertEquals, assertNotEquals } from "jsr:@std/assert@1.0.14";
import {
  handleDeleteAccount,
  type RuntimeValues,
  type VerifiedAccessClaims,
} from "./handler.ts";

const NOW = new Date("2026-07-28T00:00:00.000Z");
const REQUEST_ID = "11111111-1111-4111-8111-111111111111";
const USER_ID = "22222222-2222-4222-8222-222222222222";
const OTHER_USER_ID = "33333333-3333-4333-8333-333333333333";
const BINDING_SECRET = "synthetic-account-deletion-binding-secret";

Deno.test("rejects missing authorization before any network request", async () => {
  const runtime = fakeRuntime([]);
  const result = await handleDeleteAccount(
    new Request("http://local/delete-account", {
      method: "POST",
      body: JSON.stringify({ request_id: REQUEST_ID }),
    }),
    runtime,
  );
  assertEquals(result.status, 401);
});

Deno.test("rejects malformed request identifiers", async () => {
  const runtime = fakeRuntime([]);
  const result = await handleDeleteAccount(
    requestWithAccess({ request_id: "not-a-uuid" }),
    runtime,
  );
  assertEquals(result.status, 400);
});

Deno.test("rejects forged caller claims when the verifier rejects the token", async () => {
  const runtime = fakeRuntime([], [], () => Promise.resolve(null));
  const result = await handleDeleteAccount(
    requestWithAccess({ request_id: REQUEST_ID }),
    runtime,
  );
  assertEquals(result.status, 401);
});

Deno.test("rejects expired verified access", async () => {
  const runtime = fakeRuntime(
    [],
    [],
    () =>
      Promise.resolve(
        verifiedClaims({ exp: Math.floor(NOW.getTime() / 1000) - 1 }),
      ),
  );
  const result = await handleDeleteAccount(
    requestWithAccess({ request_id: REQUEST_ID }),
    runtime,
  );
  assertEquals(result.status, 401);
});

Deno.test("requires a recent Apple or Google OAuth authentication method", async () => {
  const oldTimestamp = Math.floor(NOW.getTime() / 1000) - 301;
  const oldRuntime = fakeRuntime(
    [],
    [],
    () =>
      Promise.resolve(verifiedClaims({
        authenticationMethods: [{ method: "oauth", timestamp: oldTimestamp }],
      })),
  );
  const oldResult = await handleDeleteAccount(
    requestWithAccess({ request_id: REQUEST_ID }),
    oldRuntime,
  );
  assertEquals(oldResult.status, 401);

  const unsupportedRuntime = fakeRuntime(
    [],
    [],
    () => Promise.resolve(verifiedClaims({ provider: "email" })),
  );
  const unsupportedResult = await handleDeleteAccount(
    requestWithAccess({ request_id: REQUEST_ID }),
    unsupportedRuntime,
  );
  assertEquals(unsupportedResult.status, 401);
});

Deno.test("wrong user cannot take over an existing deletion request", async () => {
  const originalBinding = await requestBinding(REQUEST_ID, USER_ID);
  const runtime = fakeRuntime(
    [
      new Response(
        JSON.stringify([{
          request_id: REQUEST_ID,
          request_binding: originalBinding,
          outcome: "failed_recoverable",
        }]),
        { status: 200 },
      ),
    ],
    [],
    () => Promise.resolve(verifiedClaims({ sub: OTHER_USER_ID })),
  );
  const result = await handleDeleteAccount(
    requestWithAccess({ request_id: REQUEST_ID }),
    runtime,
  );
  assertEquals(result.status, 409);
});

Deno.test("completed request replays only for the bound user", async () => {
  const binding = await requestBinding(REQUEST_ID, USER_ID);
  const runtime = fakeRuntime([
    new Response(
      JSON.stringify([{
        request_id: REQUEST_ID,
        request_binding: binding,
        outcome: "completed",
      }]),
      { status: 200 },
    ),
  ]);
  const result = await handleDeleteAccount(
    requestWithAccess({ request_id: REQUEST_ID }),
    runtime,
  );
  assertEquals(result.status, 200);
  assertEquals(await result.json(), {
    status: "completed",
    request_id: REQUEST_ID,
  });
});

Deno.test("deletes verified user and records a content-free bound audit", async () => {
  const calls: Request[] = [];
  const binding = await requestBinding(REQUEST_ID, USER_ID);
  const responses = [
    new Response("[]", { status: 200 }),
    new Response(null, { status: 201 }),
    new Response(null, { status: 204 }),
    new Response(
      JSON.stringify([{
        request_id: REQUEST_ID,
        request_binding: binding,
        outcome: "completed",
      }]),
      { status: 200 },
    ),
  ];
  const runtime = fakeRuntime(responses, calls);
  const result = await handleDeleteAccount(
    requestWithAccess({ request_id: REQUEST_ID }),
    runtime,
  );
  assertEquals(result.status, 200);
  assertEquals(calls.length, 4);
  assertEquals(calls[2].method, "DELETE");

  const checkpointBody = await calls[1].json();
  assertEquals(checkpointBody, {
    request_id: REQUEST_ID,
    request_binding: binding,
    completed_at: NOW.toISOString(),
    outcome: "failed_recoverable",
    purge_after: "2026-08-27T00:00:00.000Z",
  });
  assertEquals(JSON.stringify(checkpointBody).includes(USER_ID), false);

  const completionBody = await calls[3].json();
  assertEquals(completionBody, {
    completed_at: NOW.toISOString(),
    outcome: "completed",
    purge_after: "2026-08-27T00:00:00.000Z",
  });
});

Deno.test("recoverable deletion retry remains bound and reuses the request", async () => {
  const binding = await requestBinding(REQUEST_ID, USER_ID);
  const runtime = fakeRuntime([
    new Response(
      JSON.stringify([{
        request_id: REQUEST_ID,
        request_binding: binding,
        outcome: "failed_recoverable",
      }]),
      { status: 200 },
    ),
    new Response(null, { status: 503 }),
  ]);
  const result = await handleDeleteAccount(
    requestWithAccess({ request_id: REQUEST_ID }),
    runtime,
  );
  assertEquals(result.status, 503);
  const body = await result.json();
  assertEquals(body.request_id, REQUEST_ID);
  assertNotEquals(body.retry_token, undefined);
});

Deno.test("post-Auth-deletion retry uses signed request proof, not decoded JWT claims", async () => {
  const binding = await requestBinding(REQUEST_ID, USER_ID);
  const firstRuntime = fakeRuntime([
    new Response("[]", { status: 200 }),
    new Response(null, { status: 201 }),
    new Response(null, { status: 204 }),
    new Response(null, { status: 503 }),
  ]);
  const first = await handleDeleteAccount(
    requestWithAccess({ request_id: REQUEST_ID }),
    firstRuntime,
  );
  assertEquals(first.status, 503);
  const firstBody = await first.json();
  const retryToken = firstBody.retry_token as string;

  let verifierCalls = 0;
  const retryRuntime = fakeRuntime(
    [
      new Response(
        JSON.stringify([{
          request_id: REQUEST_ID,
          request_binding: binding,
          outcome: "failed_recoverable",
        }]),
        { status: 200 },
      ),
      new Response(null, { status: 404 }),
      new Response(
        JSON.stringify([{
          request_id: REQUEST_ID,
          request_binding: binding,
          outcome: "completed",
        }]),
        { status: 200 },
      ),
    ],
    [],
    () => {
      verifierCalls += 1;
      return Promise.resolve(null);
    },
  );
  const retry = await handleDeleteAccount(
    requestWithAccess({
      request_id: REQUEST_ID,
      retry_token: retryToken,
    }),
    retryRuntime,
  );
  assertEquals(retry.status, 200);
  assertEquals(verifierCalls, 0);
});

Deno.test("forged retry proof is rejected without privileged calls", async () => {
  const runtime = fakeRuntime([]);
  const result = await handleDeleteAccount(
    requestWithAccess({
      request_id: REQUEST_ID,
      retry_token: `${REQUEST_ID}.${USER_ID}.${"0".repeat(64)}`,
    }),
    runtime,
  );
  assertEquals(result.status, 401);
});

function requestWithAccess(body: Record<string, string>): Request {
  return new Request("http://local/delete-account", {
    method: "POST",
    headers: {
      Authorization: "Bearer verified-by-injected-boundary",
    },
    body: JSON.stringify(body),
  });
}

function verifiedClaims(
  overrides: Partial<VerifiedAccessClaims> = {},
): VerifiedAccessClaims {
  const nowSeconds = Math.floor(NOW.getTime() / 1000);
  return {
    sub: USER_ID,
    iat: nowSeconds,
    exp: nowSeconds + 3_600,
    provider: "apple",
    authenticationMethods: [{ method: "oauth", timestamp: nowSeconds }],
    ...overrides,
  };
}

function fakeRuntime(
  responses: Response[],
  calls: Request[] = [],
  verifyAccessToken: RuntimeValues["verifyAccessToken"] = () =>
    Promise.resolve(verifiedClaims()),
): RuntimeValues {
  return {
    supabaseURL: "http://127.0.0.1:54321",
    serviceRoleKey: "synthetic-service-role-key",
    requestBindingSecret: BINDING_SECRET,
    now: () => NOW,
    verifyAccessToken,
    fetch: (input, init) => {
      calls.push(new Request(input, init));
      const response = responses.shift();
      if (!response) {
        throw new Error("Unexpected fetch");
      }
      return Promise.resolve(response);
    },
  };
}

async function requestBinding(
  requestID: string,
  userID: string,
): Promise<string> {
  const payload = `${requestID}.${userID}`;
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(BINDING_SECRET),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = new Uint8Array(
    await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(payload)),
  );
  const retryToken = `${payload}.${bytesHex(signature)}`;
  const digest = new Uint8Array(
    await crypto.subtle.digest(
      "SHA-256",
      new TextEncoder().encode(retryToken),
    ),
  );
  return bytesHex(digest);
}

function bytesHex(bytes: Uint8Array): string {
  return Array.from(bytes)
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}
