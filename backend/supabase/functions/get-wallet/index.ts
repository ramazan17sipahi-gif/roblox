import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.0';
import { errorResponse, jsonResponse, billingLog, generateOpToken } from '../_shared/mod.ts';

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
  if (req.method !== 'GET') return errorResponse(405, 'METHOD_NOT_ALLOWED', 'GET only');

  const startMs = Date.now();
  const opToken = generateOpToken();

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

  const ctx = { opToken, userId: user.id };
  billingLog.opStart(ctx, 'get-wallet');

  const { data: wallet } = await svc.from('credit_wallets').select('balance, updated_at').eq('user_id', user.id).maybeSingle();
  const { data: entitlement } = await svc.from('user_entitlements').select('plan_code, status, current_period_end, auto_renew, platform, product_code').eq('user_id', user.id).maybeSingle();
  const { data: recentLedger } = await svc.from('credits_ledger').select('id, delta, reason_code, reservation_status, created_at, metadata').eq('user_id', user.id).or('reservation_status.is.null,reservation_status.eq.committed').order('created_at', { ascending: false }).limit(10);

  billingLog.opEnd(ctx, 'get-wallet', 'success', Date.now() - startMs);

  return jsonResponse({
    opToken,
    balance: wallet?.balance ?? 0,
    entitlement: entitlement ? {
      planCode: entitlement.plan_code, status: entitlement.status,
      currentPeriodEnd: entitlement.current_period_end, autoRenew: entitlement.auto_renew,
      platform: entitlement.platform, productCode: entitlement.product_code,
    } : { planCode: 'free', status: 'active', currentPeriodEnd: null, autoRenew: false, platform: null, productCode: null },
    recentLedger: (recentLedger ?? []).map(e => ({
      id: e.id, delta: e.delta, reason: e.reason_code,
      status: e.reservation_status, createdAt: e.created_at, metadata: e.metadata,
    })),
  });
});
