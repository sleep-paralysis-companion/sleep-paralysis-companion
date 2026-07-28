import { handleDeleteAccount } from "./handler.ts";

const supabaseURL = Deno.env.get("SUPABASE_URL");
const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

if (!supabaseURL || !anonKey || !serviceRoleKey) {
  throw new Error("Required server-only environment is unavailable.");
}

Deno.serve((request) =>
  handleDeleteAccount(request, {
    supabaseURL,
    anonKey,
    serviceRoleKey,
    now: () => new Date(),
    fetch,
  })
);
