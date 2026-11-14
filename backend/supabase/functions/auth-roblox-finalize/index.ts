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
const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY')!;

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

function syntheticEmail(robloxUserId: string): string {
  return `roblox_${robloxUserId}@oauth.hun.social`;
}

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

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return errorResponse(400, 'INVALID_BODY', 'Invalid JSON');
  }

  const authorizationCode = body.authorizationCode as string;
  const state = body.state as string;

  if (!authorizationCode || !state) {
    return errorResponse(400, 'VALIDATION_ERROR', 'authorizationCode and state are required');
  }

  const { data: session, error: sessionErr } = await svc
    .from('oauth_login_sessions')
    .select('*')
    .eq('platform_code', 'roblox')
    .eq('state', state)
    .maybeSingle();

  if (sessionErr || !session) {
    return errorResponse(404, 'NOT_FOUND', 'OAuth login session not found');
  }

  if (new Date(session.expires_at).getTime() < Date.now()) {
    await svc.from('oauth_login_sessions').delete().eq('id', session.id);
    return errorResponse(410, 'SESSION_EXPIRED', 'OAuth session expired. Please try again.');
  }

  try {
    const tokens = await exchangeRobloxAuthorizationCode({
      code: authorizationCode,
      redirectUri: session.redirect_uri,
      codeVerifier: session.code_verifier,
    });

    const userInfo = await fetchRobloxUserInfo(tokens.access_token);
    const robloxUserId = userInfo.sub;
    if (!robloxUserId) {
      return errorResponse(502, 'OAUTH_EXCHANGE_FAILED', 'Roblox user id missing');
    }

    const displayName = resolveRobloxDisplayName(userInfo);
    const email = syntheticEmail(robloxUserId);
    let userId: string | null = null;
    let isNewUser = false;

    const { data: identity } = await svc
      .from('roblox_identities')
      .select('user_id')
      .eq('roblox_user_id', robloxUserId)
      .maybeSingle();

    if (identity?.user_id) {
      userId = identity.user_id as string;
    } else {
      // Reconcile previously linked account (email-user who linked Roblox).
      const { data: linked } = await svc
        .from('linked_accounts')
        .select('user_id')
        .eq('platform_code', 'roblox')
        .eq('external_account_id', robloxUserId)
        .eq('status_code', 'active')
        .maybeSingle();

      if (linked?.user_id) {
        userId = linked.user_id as string;
        await svc.from('roblox_identities').upsert({
          roblox_user_id: robloxUserId,
          user_id: userId,
        });
      } else {
        const { data: created, error: createErr } = await svc.auth.admin.createUser({
          email,
          email_confirm: true,
          user_metadata: {
            provider: 'roblox',
            roblox_user_id: robloxUserId,
            preferred_username: userInfo.preferred_username ?? userInfo.nickname ?? null,
            display_name: displayName,
          },
        });

        if (createErr || !created.user) {
          // Race: user may already exist with this synthetic email.
          const existing = await findUserIdByEmail(svc, email);
          if (!existing) {
            return errorResponse(
              500,
              'INTERNAL_ERROR',
              createErr?.message ?? 'Failed to create Supabase user',
            );
          }
          userId = existing;
        } else {
          userId = created.user.id;
          isNewUser = true;
        }

        await svc.from('roblox_identities').upsert({
          roblox_user_id: robloxUserId,
          user_id: userId,
        });
      }
    }

    // Keep profile display name in sync (username is unique — skip if taken).
    await svc.from('profiles').update({ display_name: displayName }).eq('id', userId);
    const preferred =
      userInfo.preferred_username || userInfo.nickname || null;
    if (preferred) {
      await svc
        .from('profiles')
        .update({ username: preferred })
        .eq('id', userId)
        .is('username', null);
    }

    // Ensure linked_accounts row is active for this Roblox identity.
    const encryptedAccessToken = await encryptSecret(tokens.access_token);
    const encryptedRefreshToken = tokens.refresh_token
      ? await encryptSecret(tokens.refresh_token)
      : null;
    const now = new Date().toISOString();
    const scopes = (tokens.scope ?? 'openid profile').split(' ').filter(Boolean);

    const { data: existingLink } = await svc
      .from('linked_accounts')
      .select('id')
      .eq('user_id', userId)
      .eq('platform_code', 'roblox')
      .maybeSingle();

    if (existingLink?.id) {
      await svc
        .from('linked_accounts')
        .update({
          status_code: 'active',
          external_account_id: robloxUserId,
          display_name: displayName,
          linked_at: now,
          last_validated_at: now,
          encrypted_access_token: encryptedAccessToken,
          encrypted_refresh_token: encryptedRefreshToken,
          scopes,
        })
        .eq('id', existingLink.id);
    } else {
      await svc.from('linked_accounts').insert({
        user_id: userId,
        platform_code: 'roblox',
        status_code: 'active',
        external_account_id: robloxUserId,
        display_name: displayName,
        linked_at: now,
        last_validated_at: now,
        encrypted_access_token: encryptedAccessToken,
        encrypted_refresh_token: encryptedRefreshToken,
        scopes,
      });
    }

    await svc.from('oauth_login_sessions').delete().eq('id', session.id);

    // Mint a Supabase session for the mobile client.
    const { data: linkData, error: linkErr } = await svc.auth.admin.generateLink({
      type: 'magiclink',
      email: (await svc.auth.admin.getUserById(userId)).data.user?.email ?? email,
    });

    if (linkErr || !linkData?.properties?.hashed_token) {
      return errorResponse(
        500,
        'INTERNAL_ERROR',
        linkErr?.message ?? 'Failed to mint session',
      );
    }

    const anon = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    const { data: otpData, error: otpErr } = await anon.auth.verifyOtp({
      type: 'email',
      token_hash: linkData.properties.hashed_token,
    });

    if (otpErr || !otpData.session) {
      return errorResponse(
        500,
        'INTERNAL_ERROR',
        otpErr?.message ?? 'Failed to verify login session',
      );
    }

    return jsonResponse({
      accessToken: otpData.session.access_token,
      refreshToken: otpData.session.refresh_token,
      expiresIn: otpData.session.expires_in,
      userId,
      displayName,
      externalAccountId: robloxUserId,
      isNewUser,
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Roblox login finalize failed';
    if (message.includes('LINKED_ACCOUNT_TOKEN_SECRET')) {
      return errorResponse(503, 'OAUTH_NOT_CONFIGURED', message);
    }
    return errorResponse(502, 'OAUTH_EXCHANGE_FAILED', message);
  }
});

async function findUserIdByEmail(
  svc: ReturnType<typeof createClient>,
  email: string,
): Promise<string | null> {
  // Paginate admin users until email match (small user bases / race recovery).
  for (let page = 1; page <= 20; page++) {
    const { data, error } = await svc.auth.admin.listUsers({ page, perPage: 200 });
    if (error || !data?.users?.length) return null;
    const match = data.users.find((u) => u.email?.toLowerCase() === email.toLowerCase());
    if (match) return match.id;
    if (data.users.length < 200) return null;
  }
  return null;
}
