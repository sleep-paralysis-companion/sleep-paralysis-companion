export type RuntimeValues = {
  supabaseURL: string;
  anonKey: string;
  serviceRoleKey: string;
  now: () => Date;
  fetch: typeof fetch;
};

type DeleteRequest = {
  request_id?: unknown;
};

type AuthUser = {
  id?: unknown;
};

type AccessClaims = {
  sub?: unknown;
  iat?: unknown;
};

type AuditRow = {
  request_id?: string;
  outcome?: string;
};

const JSON_HEADERS = {
  "Content-Type": "application/json",
};

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

  const claims = decodeClaims(authorization.slice("Bearer ".length));
  if (
    !claims ||
    typeof claims.sub !== "string" ||
    !isUUID(claims.sub) ||
    typeof claims.iat !== "number" ||
    Math.abs(runtime.now().getTime() / 1000 - claims.iat) > 5 * 60
  ) {
    return response(401, { error: "recent_reauthentication_required" });
  }

  const existing = await runtime.fetch(
    `${runtime.supabaseURL}/rest/v1/account_deletion_audit?request_id=eq.${body.request_id}&select=request_id,outcome`,
    {
      headers: {
        apikey: runtime.serviceRoleKey,
        Authorization: `Bearer ${runtime.serviceRoleKey}`,
      },
    },
  );
  if (!existing.ok) {
    return response(503, { error: "retry_later" });
  }
  const existingRows = await existing.json() as AuditRow[];
  if (
    existingRows.some((row) =>
      row.request_id === body.request_id && row.outcome === "completed"
    )
  ) {
    return response(200, { status: "completed", request_id: body.request_id });
  }

  const retrying = existingRows.some((row) =>
    row.request_id === body.request_id && row.outcome === "failed_recoverable"
  );
  let userID = claims.sub;
  if (!retrying) {
    const userResponse = await runtime.fetch(`${runtime.supabaseURL}/auth/v1/user`, {
      headers: {
        apikey: runtime.anonKey,
        Authorization: authorization,
      },
    });
    if (!userResponse.ok) {
      return response(401, { error: "authentication_required" });
    }
    const user = await userResponse.json() as AuthUser;
    if (typeof user.id !== "string" || user.id !== claims.sub) {
      return response(401, { error: "authentication_required" });
    }
    userID = user.id;

    const checkpoint = await runtime.fetch(
      `${runtime.supabaseURL}/rest/v1/account_deletion_audit`,
      {
        method: "POST",
        headers: {
          ...JSON_HEADERS,
          Prefer: "resolution=ignore-duplicates,return=minimal",
          apikey: runtime.serviceRoleKey,
          Authorization: `Bearer ${runtime.serviceRoleKey}`,
        },
        body: JSON.stringify({
          request_id: body.request_id,
          completed_at: runtime.now().toISOString(),
          outcome: "failed_recoverable",
          purge_after: new Date(runtime.now().getTime() + 30 * 86_400_000).toISOString(),
        }),
      },
    );
    if (!checkpoint.ok) {
      return response(503, { error: "retry_later" });
    }
  }

  const deletion = await runtime.fetch(
    `${runtime.supabaseURL}/auth/v1/admin/users/${userID}`,
    {
      method: "DELETE",
      headers: {
        apikey: runtime.serviceRoleKey,
        Authorization: `Bearer ${runtime.serviceRoleKey}`,
      },
    },
  );
  if (!deletion.ok && deletion.status !== 404) {
    return response(503, { error: "retry_later" });
  }

  const completedAt = runtime.now();
  const audit = await runtime.fetch(
    `${runtime.supabaseURL}/rest/v1/account_deletion_audit?request_id=eq.${body.request_id}`,
    {
      method: "PATCH",
      headers: {
        ...JSON_HEADERS,
        Prefer: "return=minimal",
        apikey: runtime.serviceRoleKey,
        Authorization: `Bearer ${runtime.serviceRoleKey}`,
      },
      body: JSON.stringify({
        completed_at: completedAt.toISOString(),
        outcome: "completed",
        purge_after: new Date(completedAt.getTime() + 30 * 86_400_000).toISOString(),
      }),
    },
  );
  if (!audit.ok) {
    return response(503, { error: "retry_later" });
  }
  return response(200, { status: "completed", request_id: body.request_id });
}

function decodeClaims(token: string): AccessClaims | null {
  const payload = token.split(".")[1];
  if (!payload) {
    return null;
  }
  try {
    const base64 = payload.replaceAll("-", "+").replaceAll("_", "/");
    const normalized = base64.padEnd(Math.ceil(base64.length / 4) * 4, "=");
    return JSON.parse(atob(normalized)) as AccessClaims;
  } catch {
    return null;
  }
}

function isUUID(value: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value);
}

function response(status: number, body: Record<string, string>): Response {
  return new Response(JSON.stringify(body), { status, headers: JSON_HEADERS });
}
