// ═══════════════════════════════════════════════════════════════════════════════
// POST /billing/verify-purchase
// Verifies a store receipt and grants credits/entitlements.
// Uses shared grantBillingCredit() — never grants independently.
// ═══════════════════════════════════════════════════════════════════════════════

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.0';
import {
  errorResponse, jsonResponse,
  grantBillingCredit, billingLog, generateOpToken,
  RESERVATION_TTL_SECONDS,
} from '../_shared/mod.ts';
import type { BillingLogContext } from '../_shared/mod.ts';
import { verifyGooglePlaySubscription } from '../_shared/google_play_verify.ts';

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
  if (req.method !== 'POST') return errorResponse(405, 'METHOD_NOT_ALLOWED', 'POST only');

  const startMs = Date.now();
  const opToken = generateOpToken();

  // ── Auth ────────────────────────────────────────────────────────────────────
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

  // ── Parse Body ──────────────────────────────────────────────────────────────
  let body: Record<string, unknown>;
  try { body = await req.json(); }
  catch { return errorResponse(400, 'INVALID_BODY', 'Invalid JSON'); }

  const platform = body.platform as 'ios' | 'android';
  const productId = body.productId as string;
  const purchaseToken = body.purchaseToken as string | undefined;
  const transactionId = body.transactionId as string | undefined;
  const receiptData = body.receiptData as string | undefined;

  // ── Validation ──────────────────────────────────────────────────────────────
  if (!platform || !['ios', 'android'].includes(platform)) {
    return errorResponse(400, 'VALIDATION_ERROR', 'platform must be ios or android');
  }
  if (!productId) return errorResponse(400, 'VALIDATION_ERROR', 'productId required');

  const txIdOrToken = platform === 'ios'
    ? (transactionId ?? '')
    : (purchaseToken ?? '');
  if (!txIdOrToken) {
    return errorResponse(400, 'VALIDATION_ERROR', `${platform === 'ios' ? 'transactionId' : 'purchaseToken'} required`);
  }

  const ctx: BillingLogContext = { opToken, userId: user.id, platform, productId };
  billingLog.opStart(ctx, 'verify-purchase');

  // ── Platform Verification ───────────────────────────────────────────────────
  let verificationResult: {
    valid: boolean;
    eventType: 'initial_purchase' | 'renewal' | 'topup';
    periodAnchor: string;
    expiresDate?: string;
    error?: string;
  };

  try {
    if (platform === 'ios') {
      verificationResult = await verifyApple(ctx, receiptData, transactionId!, productId);
    } else {
      verificationResult = await verifyGoogle(ctx, purchaseToken!, productId, svc);
    }
  } catch (e) {
    billingLog.error(ctx, 'PLATFORM_VERIFY_EXCEPTION', 'verify_platform', false, String(e));
    billingLog.opEnd(ctx, 'verify-purchase', 'error', Date.now() - startMs);
    return errorResponse(500, 'VERIFICATION_FAILED', 'Platform verification failed');
  }

  if (!verificationResult.valid) {
    billingLog.error(ctx, 'PLATFORM_VERIFY_INVALID', 'verify_platform', false, verificationResult.error);
    billingLog.opEnd(ctx, 'verify-purchase', 'invalid', Date.now() - startMs);
    return errorResponse(403, 'VERIFICATION_FAILED', verificationResult.error ?? 'Invalid receipt');
  }

  // ── Grant via shared service ────────────────────────────────────────────────
  const grantResult = await grantBillingCredit({
    svc, ctx, userId: user.id, platform, productId,
    transactionIdOrToken: txIdOrToken,
    eventType: verificationResult.eventType,
    periodAnchor: verificationResult.periodAnchor,
    rawPayload: {
      ...body,
      expiresDate: verificationResult.expiresDate,
      verifiedAt: new Date().toISOString(),
    },
  });

  billingLog.opEnd(ctx, 'verify-purchase', grantResult.granted ? 'granted' : 'dedupe_hit', Date.now() - startMs);

  return jsonResponse({
    opToken,
    verified: true,
    granted: grantResult.granted,
    dedupeHit: grantResult.dedupeHit,
    creditsGranted: grantResult.creditsGranted,
    wallet: { balance: grantResult.newBalance },
    entitlement: grantResult.entitlement,
  });
});

// ═══════════════════════════════════════════════════════════════════════════════
// Platform Verification Implementations
// ═══════════════════════════════════════════════════════════════════════════════

async function verifyApple(
  ctx: BillingLogContext,
  _receiptData: string | undefined,
  _transactionId: string,
  _productId: string,
) {
  billingLog.reconcile(ctx, 'verify', 'apple_not_configured');
  return {
    valid: false,
    eventType: 'initial_purchase' as const,
    periodAnchor: new Date().toISOString().slice(0, 10),
    error: 'Apple purchase verification is not configured',
  };
}

async function verifyGoogle(
  ctx: BillingLogContext,
  purchaseToken: string,
  productId: string,
  _svc: unknown,
) {
  const result = await verifyGooglePlaySubscription(purchaseToken, productId);
  billingLog.reconcile(ctx, 'verify', result.valid ? 'google_verified' : 'google_rejected');
  return result;
}
