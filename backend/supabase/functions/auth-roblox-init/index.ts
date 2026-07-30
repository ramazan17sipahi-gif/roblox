import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.0';
import { errorResponse, jsonResponse } from '../_shared/mod.ts';
import {
  buildRobloxAuthorizationUrl,
  generatePkcePair,
  getRobloxRedirectUri,
} from '../_shared/roblox_oauth.ts';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return errorResponse(405, 'METHOD_NOT_ALLOWED', 'POST required');
  }

  const svc = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  let body: Record<string, unknown> = {};
  try {
    body = await req.json();
  } catch {
    body = {};
  }

  const redirectUri = getRobloxRedirectUri(body.redirectUri as string | undefined);

  try {
    // Drop expired login sessions (best-effort cleanup).
    await svc
      .from('oauth_login_sessions')
      .delete()
      .lt('expires_at', new Date().toISOString());

    const state = crypto.randomUUID();
    const { codeVerifier, codeChallenge } = await generatePkcePair();
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000).toISOString();

    const { error: sessionErr } = await svc.from('oauth_login_sessions').insert({
      platform_code: 'roblox',
      state,
      code_verifier: codeVerifier,
      redirect_uri: redirectUri,
      expires_at: expiresAt,
    });

    if (sessionErr) {
      return errorResponse(500, 'INTERNAL_ERROR', 'Failed to create login OAuth session');
    }

    const authorizationUrl = buildRobloxAuthorizationUrl({
      state,
      codeChallenge,
      redirectUri,
    });

    return jsonResponse({
      authorizationUrl,
      state,
      redirectUri,
      nextStep: 'authorization',
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Roblox login init failed';
    if (message.includes('ROBLOX_OAUTH_CLIENT_ID')) {
      return errorResponse(503, 'OAUTH_NOT_CONFIGURED', message);
    }
    return errorResponse(500, 'INTERNAL_ERROR', message);
  }
});
