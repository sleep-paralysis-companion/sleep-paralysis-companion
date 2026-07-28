import { assertEquals } from "jsr:@std/assert@1.0.14";
import { handleDeleteAccount, type RuntimeValues } from "./handler.ts";

const NOW = new Date("2026-07-28T00:00:00.000Z");
const REQUEST_ID = "11111111-1111-4111-8111-111111111111";
const USER_ID = "22222222-2222-4222-8222-222222222222";

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
    requestWithToken({ request_id: "not-a-uuid" }),
    runtime,
  );
  assertEquals(result.status, 400);
});

Deno.test("requires a recently issued provider session", async () => {
  const header = base64URL(JSON.stringify({ alg: "HS256", typ: "JWT" }));
  const payload = base64URL(JSON.stringify({
    sub: USER_ID,
    iat: Math.floor(NOW.getTime() / 1000) - 301,
  }));
  const runtime = fakeRuntime([]);
  const result = await handleDeleteAccount(
    new Request("http://local/delete-account", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${header}.${payload}.synthetic-signature`,
      },
      body: JSON.stringify({ request_id: REQUEST_ID }),
    }),
    runtime,
  );
  assertEquals(result.status, 401);
});

Deno.test("returns an idempotent completion for an existing request", async () => {
  const runtime = fakeRuntime([
    new Response(
      JSON.stringify([{ request_id: REQUEST_ID, outcome: "completed" }]),
      { status: 200 },
    ),
  ]);
  const result = await handleDeleteAccount(
    requestWithToken({ request_id: REQUEST_ID }),
    runtime,
  );
  assertEquals(result.status, 200);
  assertEquals(await result.json(), {
    status: "completed",
    request_id: REQUEST_ID,
  });
});

Deno.test("deletes the authenticated user and records a content-free audit", async () => {
  const calls: Request[] = [];
  const responses = [
    new Response("[]", { status: 200 }),
    new Response(JSON.stringify({ id: USER_ID }), { status: 200 }),
    new Response(null, { status: 201 }),
    new Response(null, { status: 204 }),
    new Response(null, { status: 204 }),
  ];
  const runtime = fakeRuntime(responses, calls);
  const result = await handleDeleteAccount(
    requestWithToken({ request_id: REQUEST_ID }),
    runtime,
  );
  assertEquals(result.status, 200);
  assertEquals(calls.length, 5);
  assertEquals(calls[3].method, "DELETE");
  const auditBody = await calls[4].json();
  assertEquals(auditBody, {
    completed_at: NOW.toISOString(),
    outcome: "completed",
    purge_after: "2026-08-27T00:00:00.000Z",
  });
});

Deno.test("resumes after Auth deletion without requiring the deleted user row", async () => {
  const calls: Request[] = [];
  const runtime = fakeRuntime([
    new Response(
      JSON.stringify([{
        request_id: REQUEST_ID,
        outcome: "failed_recoverable",
      }]),
      { status: 200 },
    ),
    new Response(null, { status: 404 }),
    new Response(null, { status: 204 }),
  ], calls);
  const result = await handleDeleteAccount(
    requestWithToken({ request_id: REQUEST_ID }),
    runtime,
  );
  assertEquals(result.status, 200);
  assertEquals(calls.length, 3);
  assertEquals(calls[1].method, "DELETE");
  assertEquals(calls[2].method, "PATCH");
});

function requestWithToken(body: Record<string, string>): Request {
  const header = base64URL(JSON.stringify({ alg: "HS256", typ: "JWT" }));
  const payload = base64URL(JSON.stringify({
    sub: USER_ID,
    iat: Math.floor(NOW.getTime() / 1000),
  }));
  return new Request("http://local/delete-account", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${header}.${payload}.synthetic-signature`,
    },
    body: JSON.stringify(body),
  });
}

function base64URL(value: string): string {
  return btoa(value)
    .replaceAll("+", "-")
    .replaceAll("/", "_")
    .replaceAll("=", "");
}

function fakeRuntime(
  responses: Response[],
  calls: Request[] = [],
): RuntimeValues {
  return {
    supabaseURL: "http://127.0.0.1:54321",
    anonKey: "synthetic-anon-key",
    serviceRoleKey: "synthetic-service-role-key",
    now: () => NOW,
    fetch: async (input, init) => {
      calls.push(new Request(input, init));
      const response = responses.shift();
      if (!response) {
        throw new Error("Unexpected fetch");
      }
      return response;
    },
  };
}
