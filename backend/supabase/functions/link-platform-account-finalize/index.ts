import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.0';
import { errorResponse, jsonResponse } from '../_shared/mod.ts';
import {
  encryptSecret,
  exchangeRobloxAuthorizationCode,
  fetchRobloxUserInfo,
  resolveRobloxDisplayName,
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
  const authorizationCode = body.authorizationCode as string;
  const state = body.state as string;

  if (platformCode !== 'roblox') {
    return errorResponse(400, 'UNSUPPORTED_PLATFORM', 'Only Roblox OAuth linking is supported');
  }
  if (!authorizationCode || !state) {
    return errorResponse(400, 'VALIDATION_ERROR', 'platformCode, authorizationCode, and state are required');
  }

  const { data: session, error: sessionErr } = await svc
    .from('oauth_link_sessions')
    .select('*')
    .eq('user_id', user.id)
    .eq('platform_code', platformCode)
    .eq('state', state)
    .maybeSingle();

  if (sessionErr || !session) {
    return errorResponse(404, 'NOT_FOUND', 'OAuth session not found');
  }

  if (new Date(session.expires_at).getTime() < Date.now()) {
    await svc.from('oauth_link_sessions').delete().eq('id', session.id);
    return errorResponse(410, 'SESSION_EXPIRED', 'OAuth session expired. Please try again.');
  }

  try {
    const tokens = await exchangeRobloxAuthorizationCode({
      code: authorizationCode,
      redirectUri: session.redirect_uri,
      codeVerifier: session.code_verifier,
    });

    const userInfo = await fetchRobloxUserInfo(tokens.access_token);
    const displayName = resolveRobloxDisplayName(userInfo);
    const encryptedAccessToken = await encryptSecret(tokens.access_token);
    const encryptedRefreshToken = tokens.refresh_token
      ? await encryptSecret(tokens.refresh_token)
      : null;

    const now = new Date().toISOString();
    const { error: updateErr } = await svc
      .from('linked_accounts')
      .update({
        status_code: 'active',
        external_account_id: userInfo.sub,
        display_name: displayName,
        linked_at: now,
        last_validated_at: now,
        encrypted_access_token: encryptedAccessToken,
        encrypted_refresh_token: encryptedRefreshToken,
        scopes: (tokens.scope ?? 'openid profile').split(' ').filter(Boolean),
      })
      .eq('id', session.linked_account_id)
      .eq('user_id', user.id);

    if (updateErr) return errorResponse(500, 'INTERNAL_ERROR', 'Failed to save linked account');

    await svc.from('oauth_link_sessions').delete().eq('id', session.id);

    await svc.from('linked_account_audit').insert({
      linked_account_id: session.linked_account_id,
      event_type: 'link_completed',
      metadata: {
        platformCode,
        externalAccountId: userInfo.sub,
        displayName,
      },
    });

    return jsonResponse({
      linkedAccountId: session.linked_account_id,
      platformCode,
      status: 'active',
      displayName,
      externalAccountId: userInfo.sub,
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Roblox OAuth finalize failed';
    return errorResponse(502, 'OAUTH_EXCHANGE_FAILED', message);
  }
});
