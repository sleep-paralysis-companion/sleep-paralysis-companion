import { createClient } from "npm:@supabase/supabase-js@2.95.0";
import { handleDeleteAccount, type VerifiedAccessClaims } from "./handler.ts";

const supabaseURL = Deno.env.get("SUPABASE_URL");
const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const requestBindingSecret = Deno.env.get("ACCOUNT_DELETION_BINDING_SECRET");

if (!supabaseURL || !anonKey || !serviceRoleKey || !requestBindingSecret) {
  throw new Error("Required server-only environment is unavailable.");
}

const authClient = createClient(supabaseURL, anonKey, {
  auth: {
    autoRefreshToken: false,
    detectSessionInUrl: false,
    persistSession: false,
  },
});

Deno.serve((request) =>
  handleDeleteAccount(request, {
    supabaseURL,
    serviceRoleKey,
    requestBindingSecret,
    now: () => new Date(),
    fetch,
    verifyAccessToken: async (token) => {
      const { data, error } = await authClient.auth.getClaims(token);
      if (error || !data?.claims) {
        return null;
      }
      return verifiedClaims(data.claims as Record<string, unknown>);
    },
  })
);

function verifiedClaims(
  claims: Record<string, unknown>,
): VerifiedAccessClaims | null {
  const metadata = claims.app_metadata;
  const methods = claims.amr;
  if (
    typeof claims.sub !== "string" ||
    typeof claims.iat !== "number" ||
    typeof claims.exp !== "number" ||
    typeof metadata !== "object" ||
    metadata === null ||
    !Array.isArray(methods)
  ) {
    return null;
  }
  const provider = (metadata as Record<string, unknown>).provider;
  if (typeof provider !== "string") {
    return null;
  }

  const authenticationMethods = methods.flatMap((method) => {
    if (typeof method !== "object" || method === null) {
      return [];
    }
    const record = method as Record<string, unknown>;
    return typeof record.method === "string" &&
        typeof record.timestamp === "number"
      ? [{ method: record.method, timestamp: record.timestamp }]
      : [];
  });
  return {
    sub: claims.sub,
    iat: claims.iat,
    exp: claims.exp,
    provider,
    authenticationMethods,
  };
}
