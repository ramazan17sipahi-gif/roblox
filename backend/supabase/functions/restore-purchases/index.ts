// ═══════════════════════════════════════════════════════════════════════════════
// POST /billing/restore
// Restores purchases from the store. NEVER grants credits.
// Only reconciles entitlement state.
// ═══════════════════════════════════════════════════════════════════════════════

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.0';
import {
  errorResponse, jsonResponse,
  billingLog, generateOpToken,
} from '../_shared/mod.ts';
import type { BillingLogContext } from '../_shared/mod.ts';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

interface RestoreReceipt {
  transactionId?: string;
  purchaseToken?: string;
  productId: string;
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
      },
    });
  }
  if (req.method !== 'POST') return errorResponse(405, 'METHOD_NOT_ALLOWED', 'POST only');

  const startMs = Date.now();
  const opToken = generateOpToken();

  // ── Auth ──
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

  // ── Parse Body ──
  let body: Record<string, unknown>;
  try { body = await req.json(); }
  catch { return errorResponse(400, 'INVALID_BODY', 'Invalid JSON'); }

  const platform = body.platform as 'ios' | 'android';
  const receipts = body.receipts as RestoreReceipt[];

  if (!platform || !['ios', 'android'].includes(platform)) {
    return errorResponse(400, 'VALIDATION_ERROR', 'platform must be ios or android');
  }
  if (!receipts || !Array.isArray(receipts) || receipts.length === 0) {
    return errorResponse(400, 'VALIDATION_ERROR', 'receipts array required');
  }

  const ctx: BillingLogContext = { opToken, userId: user.id, platform };
  billingLog.opStart(ctx, 'restore-purchases');

  // ── Process each receipt — ENTITLEMENT ONLY, NO CREDIT GRANT ──
  let restoredPlan: string = 'free';
  let restoredPeriodEnd: string | null = null;

  for (const receipt of receipts) {
    const productId = receipt.productId;
    if (!productId) continue;

    // Check if this is a subscription product
    const platformCol = platform === 'ios' ? 'ios_product_id' : 'android_product_id';
    const { data: product } = await svc
      .from('billing_products')
      .select('*')
      .eq(platformCol, productId)
      .eq('type', 'subscription')
      .eq('is_active', true)
      .maybeSingle();

    if (!product) {
      billingLog.reconcile(ctx, 'restore', `skip_unknown_product:${productId}`);
      continue;
    }

    // TODO: Verify with platform API that subscription is still active
    // Apple: GET /inApps/v1/subscriptions/{originalTransactionId}
    // Google: purchases.subscriptionsv2.get()

    const planCode = product.plan_code as string;
    const isActive = true; // Replace with actual platform verification

    if (isActive && planCode) {
      // UPSERT entitlement — NO credit grant
      const periodEnd = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString();

      await svc.from('user_entitlements').upsert({
        user_id: user.id,
        plan_code: planCode,
        platform,
        status: 'active',
        product_code: product.code,
        current_period_end: periodEnd,
        auto_renew: true,
        source_token: receipt.transactionId ?? receipt.purchaseToken ?? '',
      }, { onConflict: 'user_id' });

      restoredPlan = planCode;
      restoredPeriodEnd = periodEnd;

      billingLog.reconcile(ctx, 'restore', `entitlement_synced:${planCode}`);
    }
  }

  // ── Get current wallet (no modification) ──
  const { data: wallet } = await svc
    .from('credit_wallets')
    .select('balance')
    .eq('user_id', user.id)
    .maybeSingle();

  billingLog.opEnd(ctx, 'restore-purchases', 'success', Date.now() - startMs);

  return jsonResponse({
    opToken,
    restored: restoredPlan !== 'free',
    entitlement: {
      planCode: restoredPlan,
      status: 'active',
      currentPeriodEnd: restoredPeriodEnd,
    },
    wallet: { balance: wallet?.balance ?? 0 },
    // NOTE: No creditsGranted field — restore never grants credits
  });
});
