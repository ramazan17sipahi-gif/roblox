import { createClient, type SupabaseClient } from "@supabase/supabase-js";

/**
 * Browser Supabase client for admin UI reads.
 * Uses placeholders during build so Next.js prerender doesn't crash
 * when Vercel env vars are not yet set.
 */
let client: SupabaseClient | null = null;

export function getSupabaseBrowser(): SupabaseClient {
  if (client) return client;

  const url =
    process.env.NEXT_PUBLIC_SUPABASE_URL || "https://placeholder.supabase.co";
  const key = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || "placeholder-anon-key";

  client = createClient(url, key);
  return client;
}
