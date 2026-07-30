import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.0';
import { errorResponse, jsonResponse } from '../_shared/mod.ts';
import {
  buildRobloxAuthorizationUrl,
  generatePkcePair,
  getRobloxRedirectUri,
} from '../_shared/roblox_oauth.ts';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
      },
    });
  }

  const authHeader = req.headers.get('Authorization');
  if (!authHeader) return errorResponse(401, 'UNAUTHORIZED', 'Missing authorization header');

  const supabaseUser = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
    global: { headers: { Authorization: authHeader } },
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { data: { user }, error: authError } = await supabaseUser.auth.getUser();
  if (authError || !user) return errorResponse(401, 'UNAUTHORIZED', 'Invalid token');

  const svc = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  let body: Record<string, unknown>;
  try { body = await req.json(); } catch { return errorResponse(400, 'INVALID_BODY', 'Invalid JSON'); }

  const platformCode = body.platformCode as string;
  const redirectUri = getRobloxRedirectUri(body.redirectUri as string | undefined);

  if (platformCode !== 'roblox') {
    return errorResponse(400, 'UNSUPPORTED_PLATFORM', 'Only Roblox OAuth linking is supported');
  }

  try {
    const { data: existingActive } = await svc
      .from('linked_accounts')
      .select('id, status_code, display_name')
      .eq('user_id', user.id)
      .eq('platform_code', platformCode)
      .maybeSingle();

    if (existingActive?.status_code === 'active') {
      return errorResponse(409, 'CONFLICT', 'Roblox account already linked');
    }

    let linkedAccountId: string;
    if (existingActive) {
      await svc.from('linked_accounts').update({ status_code: 'pending' }).eq('id', existingActive.id);
      linkedAccountId = existingActive.id;
    } else {
      const { data: created, error: createErr } = await svc
        .from('linked_accounts')
        .insert({
          user_id: user.id,
          platform_code: platformCode,
          status_code: 'pending',
        })
        .select('id')
        .single();

      if (createErr || !created) return errorResponse(500, 'INTERNAL_ERROR', 'Failed to init link');
      linkedAccountId = created.id;
    }

    await svc
      .from('oauth_link_sessions')
      .delete()
      .eq('user_id', user.id)
      .eq('platform_code', platformCode);

    const state = crypto.randomUUID();
    const { codeVerifier, codeChallenge } = await generatePkcePair();
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000).toISOString();

    const { error: sessionErr } = await svc.from('oauth_link_sessions').insert({
      user_id: user.id,
      platform_code: platformCode,
      linked_account_id: linkedAccountId,
      state,
      code_verifier: codeVerifier,
      redirect_uri: redirectUri,
      expires_at: expiresAt,
    });

    if (sessionErr) return errorResponse(500, 'INTERNAL_ERROR', 'Failed to create OAuth session');

    await svc.from('linked_account_audit').insert({
      linked_account_id: linkedAccountId,
      event_type: 'link_initiated',
      metadata: { platformCode, redirectUri },
    });

    const authorizationUrl = buildRobloxAuthorizationUrl({
      state,
      codeChallenge,
      redirectUri,
    });

    return jsonResponse({
      linkedAccountId,
      platformCode,
      status: 'pending',
      nextStep: 'authorization',
      authorizationUrl,
      state,
      redirectUri,
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Roblox OAuth init failed';
    if (message.includes('ROBLOX_OAUTH_CLIENT_ID')) {
      return errorResponse(503, 'OAUTH_NOT_CONFIGURED', message);
    }
    return errorResponse(500, 'INTERNAL_ERROR', message);
  }
});
