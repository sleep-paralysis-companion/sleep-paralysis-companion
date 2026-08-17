import { createClient } from "npm:@supabase/supabase-js@2.101.0";
import { AUDIO_CATALOG_BUCKET } from "../_shared/audio_catalog.ts";
import { handleAudioAuthorization } from "./handler.ts";

const supabaseURL = Deno.env.get("SUPABASE_URL");
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
if (!supabaseURL || !serviceRoleKey) {
  throw new Error("Required server-only Supabase environment is unavailable.");
}

const client = createClient(supabaseURL, serviceRoleKey, {
  auth: {
    autoRefreshToken: false,
    detectSessionInUrl: false,
    persistSession: false,
  },
});

Deno.serve((request) =>
  handleAudioAuthorization(request, {
    createSignedURL: async (path, expiresInSeconds) => {
      const { data, error } = await client.storage
        .from(AUDIO_CATALOG_BUCKET)
        .createSignedUrl(path, expiresInSeconds);
      return {
        data: data?.signedUrl ? { signedUrl: data.signedUrl } : null,
        error: error ? new Error(error.message) : null,
      };
    },
  })
);
