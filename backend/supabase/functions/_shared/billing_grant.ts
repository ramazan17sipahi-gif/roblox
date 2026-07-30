// ═══════════════════════════════════════════════════════════════════════════════
// Shared Billing Grant Service
// SINGLE entry point for all credit grants. Enforces global dedupe.
// Used by: verify-purchase, appstore-notifications, google-rtdn
// NEVER used by: restore-purchases (restore reconciles, never grants)
// ═══════════════════════════════════════════════════════════════════════════════

import { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2.49.0';
import { billingLog, BillingLogContext } from './billing_log.ts';

export interface GrantParams {
  svc: SupabaseClient;
  ctx: BillingLogContext;
  userId: string;
  platform: 'ios' | 'android';
  productId: string;
  transactionIdOrToken: string;
  eventType: 'initial_purchase' | 'renewal' | 'topup';
  periodAnchor: string; // ISO date for subscription period, or transaction timestamp for topup
  rawPayload: Record<string, unknown>;
}

export interface GrantResult {
  granted: boolean;
  dedupeHit: boolean;
  creditsGranted: number;
  newBalance: number;
  entitlement: {
    planCode: string;
    status: string;
    currentPeriodEnd: string | null;
  } | null;
  error?: string;
}

/**
 * grantBillingCredit — The ONLY function that grants credits for purchases.
 *
 * Dedupe contract:
 *   dedupe_key = {platform}:{transactionIdOrToken}:{eventType}:{periodAnchor}
 *
 * Rules:
 *   - initial_purchase → 1× grant
 *   - renewal → 1× per period (period_anchor = period_start_date)
 *   - topup → 1× per transaction
 *   - restore → NEVER calls this function
 */
export async function grantBillingCredit(params: GrantParams): Promise<GrantResult> {
  const { svc, ctx, userId, platform, productId, transactionIdOrToken, eventType, periodAnchor, rawPayload } = params;

  // ── Build dedupe key ──────────────────────────────────────────────────────
  const dedupeKey = `${platform}:${transactionIdOrToken}:${eventType}:${periodAnchor}`;
  billingLog.dedupe(ctx, dedupeKey, false); // Will update if hit

  // ── Check dedupe (purchase_events) ────────────────────────────────────────
  const { data: existing } = await svc
    .from('purchase_events')
    .select('id, verification_status')
    .eq('dedupe_key', dedupeKey)
    .maybeSingle();

  if (existing) {
    billingLog.dedupe(ctx, dedupeKey, true);
    // Already processed — return current state without granting
    const wallet = await getWalletBalance(svc, userId);
    const ent = await getEntitlement(svc, userId);
    return {
      granted: false,
      dedupeHit: true,
      creditsGranted: 0,
      newBalance: wallet,
      entitlement: ent,
    };
  }

  // ── Lookup billing_products ───────────────────────────────────────────────
  const platformCol = platform === 'ios' ? 'ios_product_id' : 'android_product_id';
  const { data: product, error: prodError } = await svc
    .from('billing_products')
    .select('*')
    .eq(platformCol, productId)
    .eq('is_active', true)
    .maybeSingle();

  if (prodError || !product) {
    billingLog.error(ctx, 'PRODUCT_NOT_FOUND', 'billing_products_lookup', false, `productId=${productId}`);
    return {
      granted: false, dedupeHit: false, creditsGranted: 0,
      newBalance: await getWalletBalance(svc, userId),
      entitlement: null,
      error: `Unknown product: ${productId}`,
    };
  }

  const creditAmount = product.credit_amount as number;
  const productType = product.type as string;
  const planCode = product.plan_code as string | null;

  // ── Record purchase event (dedupe_key UNIQUE enforces atomicity) ───────────
  const { error: insertError } = await svc
    .from('purchase_events')
    .insert({
      user_id: userId,
      platform,
      product_id: productId,
      purchase_token_or_txid: transactionIdOrToken,
      raw_payload: rawPayload,
      verification_status: 'verified',
      dedupe_key: dedupeKey,
      idempotency_key: dedupeKey, // Same key for both columns
    });

  if (insertError) {
    // UNIQUE violation means concurrent request already processed
    if (insertError.code === '23505') {
      billingLog.dedupe(ctx, dedupeKey, true);
      const wallet = await getWalletBalance(svc, userId);
      const ent = await getEntitlement(svc, userId);
      return { granted: false, dedupeHit: true, creditsGranted: 0, newBalance: wallet, entitlement: ent };
    }
    billingLog.error(ctx, 'PURCHASE_EVENT_INSERT_FAILED', 'insert_purchase_events', true, insertError.message);
    return {
      granted: false, dedupeHit: false, creditsGranted: 0,
      newBalance: await getWalletBalance(svc, userId),
      entitlement: null,
      error: insertError.message,
    };
  }

  // ── Grant credits via atomic ledger+wallet function ────────────────────────
  const reasonCode = eventType === 'topup' ? 'topup_purchase'
    : eventType === 'initial_purchase' ? 'subscription_initial_grant'
    : 'subscription_renewal_grant';

  const balanceBefore = await getWalletBalance(svc, userId);

  const { data: ledgerResult, error: ledgerError } = await svc.rpc('billing_ledger_insert', {
    p_user_id: userId,
    p_delta: creditAmount,
    p_reason_code: reasonCode,
    p_idempotency_key: `grant_${dedupeKey}`,
    p_metadata: { productId, eventType, periodAnchor, productCode: product.code },
  });

  if (ledgerError) {
    billingLog.error(ctx, 'LEDGER_INSERT_FAILED', 'billing_ledger_insert', true, ledgerError.message);
    return {
      granted: false, dedupeHit: false, creditsGranted: 0,
      newBalance: balanceBefore,
      entitlement: null,
      error: ledgerError.message,
    };
  }

  const row = Array.isArray(ledgerResult) ? ledgerResult[0] : ledgerResult;
  const newBalance = row?.new_balance ?? balanceBefore + creditAmount;

  billingLog.grant(ctx, `${eventType}`, creditAmount);
  billingLog.wallet(ctx, balanceBefore, creditAmount, newBalance);

  // ── If subscription: UPSERT entitlement ───────────────────────────────────
  let entitlement: GrantResult['entitlement'] = null;
  if (productType === 'subscription' && planCode) {
    const periodEnd = rawPayload.expiresDate as string
      ?? rawPayload.expires_date as string
      ?? null;

    const { error: entError } = await svc
      .from('user_entitlements')
      .upsert({
        user_id: userId,
        plan_code: planCode,
        platform,
        status: 'active',
        product_code: product.code,
        current_period_end: periodEnd,
        auto_renew: true,
        source_token: transactionIdOrToken,
      }, { onConflict: 'user_id' });

    if (entError) {
      billingLog.error(ctx, 'ENTITLEMENT_UPSERT_FAILED', 'user_entitlements_upsert', true, entError.message);
    }

    entitlement = {
      planCode,
      status: 'active',
      currentPeriodEnd: periodEnd,
    };
  }

  return {
    granted: true,
    dedupeHit: false,
    creditsGranted: creditAmount,
    newBalance,
    entitlement,
  };
}

// ── Helpers ─────────────────────────────────────────────────────────────────

async function getWalletBalance(svc: SupabaseClient, userId: string): Promise<number> {
  const { data } = await svc
    .from('credit_wallets')
    .select('balance')
    .eq('user_id', userId)
    .maybeSingle();
  return data?.balance ?? 0;
}

async function getEntitlement(svc: SupabaseClient, userId: string) {
  const { data } = await svc
    .from('user_entitlements')
    .select('plan_code, status, current_period_end')
    .eq('user_id', userId)
    .maybeSingle();
  if (!data) return null;
  return {
    planCode: data.plan_code,
    status: data.status,
    currentPeriodEnd: data.current_period_end,
  };
}
