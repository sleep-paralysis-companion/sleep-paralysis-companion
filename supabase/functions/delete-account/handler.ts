export type VerifiedAccessClaims = {
  sub: string;
  iat: number;
  exp: number;
  provider: string;
  authenticationMethods: Array<{
    method: string;
    timestamp: number;
  }>;
};

export type RuntimeValues = {
  supabaseURL: string;
  serviceRoleKey: string;
  requestBindingSecret: string;
  now: () => Date;
  fetch: typeof fetch;
  verifyAccessToken: (token: string) => Promise<VerifiedAccessClaims | null>;
};

type DeleteRequest = {
  request_id?: unknown;
  retry_token?: unknown;
};

type AuditRow = {
  request_id?: string;
  request_binding?: string;
  outcome?: string;
};

type RetryAuthorization = {
  requestID: string;
  userID: string;
};

const JSON_HEADERS = {
  "Content-Type": "application/json",
};

const RECENT_REAUTHENTICATION_SECONDS = 5 * 60;

export async function handleDeleteAccount(
  request: Request,
  runtime: RuntimeValues,
): Promise<Response> {
  if (request.method !== "POST") {
    return response(405, { error: "method_not_allowed" });
  }

  const authorization = request.headers.get("Authorization");
  if (!authorization?.startsWith("Bearer ")) {
    return response(401, { error: "authentication_required" });
  }

  let body: DeleteRequest;
  try {
    body = await request.json() as DeleteRequest;
  } catch {
    return response(400, { error: "invalid_request" });
  }

  if (typeof body.request_id !== "string" || !isUUID(body.request_id)) {
    return response(400, { error: "invalid_request" });
  }
  if (body.retry_token !== undefined && typeof body.retry_token !== "string") {
    return response(400, { error: "invalid_request" });
  }

  const bearerToken = authorization.slice("Bearer ".length);
  let userID: string;
  let retryToken: string;

  if (typeof body.retry_token === "string") {
    const retryAuthorization = await verifyRetryToken(
      body.retry_token,
      body.request_id,
      runtime.requestBindingSecret,
    );
    if (!retryAuthorization) {
      return response(401, { error: "authentication_required" });
    }
    userID = retryAuthorization.userID;
    retryToken = body.retry_token;
  } else {
    const claims = await runtime.verifyAccessToken(bearerToken);
    if (!hasRecentProviderReauthentication(claims, runtime.now())) {
      return response(401, { error: "recent_reauthentication_required" });
    }
    userID = claims.sub;
    retryToken = await makeRetryToken(
      body.request_id,
      userID,
      runtime.requestBindingSecret,
    );
  }

  const requestBinding = await sha256Hex(retryToken);
  const existing = await runtime.fetch(
    `${runtime.supabaseURL}/rest/v1/account_deletion_audit?request_id=eq.${body.request_id}` +
      "&select=request_id,request_binding,outcome",
    serviceRoleRequest(runtime.serviceRoleKey),
  );
  if (!existing.ok) {
    return recoverableResponse(body.request_id, retryToken);
  }

  const existingRows = await existing.json() as AuditRow[];
  if (
    existingRows.some((row) =>
      row.request_id === body.request_id &&
      row.request_binding !== requestBinding
    )
  ) {
    return response(409, { error: "request_identity_mismatch" });
  }
  if (
    existingRows.some((row) =>
      row.request_id === body.request_id &&
      row.request_binding === requestBinding &&
      row.outcome === "completed"
    )
  ) {
    return response(200, { status: "completed", request_id: body.request_id });
  }

  if (existingRows.length === 0) {
    if (typeof body.retry_token === "string") {
      return response(401, { error: "authentication_required" });
    }
    const checkpoint = await runtime.fetch(
      `${runtime.supabaseURL}/rest/v1/account_deletion_audit`,
      {
        method: "POST",
        headers: {
          ...JSON_HEADERS,
          Prefer: "return=minimal",
          ...serviceRoleHeaders(runtime.serviceRoleKey),
        },
        body: JSON.stringify({
          request_id: body.request_id,
          request_binding: requestBinding,
          completed_at: runtime.now().toISOString(),
          outcome: "failed_recoverable",
          purge_after: new Date(runtime.now().getTime() + 30 * 86_400_000)
            .toISOString(),
        }),
      },
    );
    if (!checkpoint.ok) {
      return recoverableResponse(body.request_id, retryToken);
    }
  }

  const deletion = await runtime.fetch(
    `${runtime.supabaseURL}/auth/v1/admin/users/${userID}`,
    {
      method: "DELETE",
      headers: serviceRoleHeaders(runtime.serviceRoleKey),
    },
  );
  if (!deletion.ok && deletion.status !== 404) {
    return recoverableResponse(body.request_id, retryToken);
  }

  const completedAt = runtime.now();
  const audit = await runtime.fetch(
    `${runtime.supabaseURL}/rest/v1/account_deletion_audit` +
      `?request_id=eq.${body.request_id}&request_binding=eq.${requestBinding}`,
    {
      method: "PATCH",
      headers: {
        ...JSON_HEADERS,
        Prefer: "return=representation",
        ...serviceRoleHeaders(runtime.serviceRoleKey),
      },
      body: JSON.stringify({
        completed_at: completedAt.toISOString(),
        outcome: "completed",
        purge_after: new Date(completedAt.getTime() + 30 * 86_400_000)
          .toISOString(),
      }),
    },
  );
  if (!audit.ok) {
    return recoverableResponse(body.request_id, retryToken);
  }
  const completedRows = await audit.json() as AuditRow[];
  if (
    !completedRows.some((row) =>
      row.request_id === body.request_id &&
      row.request_binding === requestBinding &&
      row.outcome === "completed"
    )
  ) {
    return recoverableResponse(body.request_id, retryToken);
  }

  return response(200, { status: "completed", request_id: body.request_id });
}

function hasRecentProviderReauthentication(
  claims: VerifiedAccessClaims | null,
  now: Date,
): claims is VerifiedAccessClaims {
  if (
    !claims ||
    !isUUID(claims.sub) ||
    !["apple", "google"].includes(claims.provider)
  ) {
    return false;
  }
  const nowSeconds = now.getTime() / 1000;
  if (
    !Number.isFinite(claims.iat) ||
    !Number.isFinite(claims.exp) ||
    claims.iat > nowSeconds ||
    claims.exp <= nowSeconds
  ) {
    return false;
  }
  return claims.authenticationMethods.some((method) =>
    method.method === "oauth" &&
    Number.isFinite(method.timestamp) &&
    method.timestamp <= nowSeconds &&
    nowSeconds - method.timestamp <= RECENT_REAUTHENTICATION_SECONDS
  );
}

async function makeRetryToken(
  requestID: string,
  userID: string,
  secret: string,
): Promise<string> {
  const payload = `${requestID}.${userID}`;
  const signature = await hmacHex(payload, secret);
  return `${payload}.${signature}`;
}

async function verifyRetryToken(
  token: string,
  expectedRequestID: string,
  secret: string,
): Promise<RetryAuthorization | null> {
  const pieces = token.split(".");
  if (pieces.length !== 3) {
    return null;
  }
  const [requestID, userID, signature] = pieces;
  if (
    requestID !== expectedRequestID ||
    !isUUID(requestID) ||
    !isUUID(userID) ||
    !/^[0-9a-f]{64}$/.test(signature)
  ) {
    return null;
  }
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["verify"],
  );
  const valid = await crypto.subtle.verify(
    "HMAC",
    key,
    hexBuffer(signature),
    new TextEncoder().encode(`${requestID}.${userID}`),
  );
  return valid ? { requestID, userID } : null;
}

async function hmacHex(value: string, secret: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(value),
  );
  return bytesHex(new Uint8Array(signature));
}

async function sha256Hex(value: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(value),
  );
  return bytesHex(new Uint8Array(digest));
}

function bytesHex(bytes: Uint8Array): string {
  return Array.from(bytes)
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

function hexBuffer(value: string): ArrayBuffer {
  const buffer = new ArrayBuffer(value.length / 2);
  const bytes = new Uint8Array(buffer);
  for (let index = 0; index < bytes.length; index += 1) {
    bytes[index] = Number.parseInt(value.slice(index * 2, index * 2 + 2), 16);
  }
  return buffer;
}

function serviceRoleHeaders(serviceRoleKey: string): Record<string, string> {
  return {
    apikey: serviceRoleKey,
    Authorization: `Bearer ${serviceRoleKey}`,
  };
}

function serviceRoleRequest(serviceRoleKey: string): RequestInit {
  return { headers: serviceRoleHeaders(serviceRoleKey) };
}

function recoverableResponse(requestID: string, retryToken: string): Response {
  return response(503, {
    error: "retry_later",
    request_id: requestID,
    retry_token: retryToken,
  });
}

function isUUID(value: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
    .test(value);
}

function response(status: number, body: Record<string, string>): Response {
  return new Response(JSON.stringify(body), { status, headers: JSON_HEADERS });
}
