// ═══════════════════════════════════════════════════════════════════════════════
// POST /appstore-notifications — App Store Server Notifications V2
// Apple calls this with no Supabase JWT. Deploy with verify_jwt = false.
// The signedPayload JWS is verified against Apple Root CA - G3.
// ═══════════════════════════════════════════════════════════════════════════════

import { createClient, SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2.49.0';
import { errorResponse, jsonResponse, grantBillingCredit, billingLog, generateOpToken } from '../_shared/mod.ts';
import {
  AppleIapError,
  DecodedTransaction,
  isoFromMillis,
  periodAnchorFromMillis,
  readAppleIapConfig,
  readTransaction,
  verifySignedNotification,
  verifySignedTransaction,
} from '../_shared/apple_iap.ts';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

Deno.serve(async (req: Request) => {
  if (req.method !== 'POST') return errorResponse(405, 'METHOD_NOT_ALLOWED', 'POST only');

  const startMs = Date.now();
  const opToken = generateOpToken();
  const ctx = { opToken };

  const config = readAppleIapConfig();
  if (!config) {
    billingLog.error(ctx, 'APPLE_NOT_CONFIGURED', 'appstore_notification', false);
    return errorResponse(500, 'NOT_CONFIGURED', 'Apple purchase verification is not configured');
  }

  const svc = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  let body: Record<string, unknown>;
  try { body = await req.json(); } catch { return errorResponse(400, 'INVALID_BODY', 'Invalid JSON'); }

  const signedPayload = body.signedPayload;
  if (typeof signedPayload !== 'string' || !signedPayload) {
    return errorResponse(400, 'VALIDATION_ERROR', 'signedPayload required');
  }

  let notification: Record<string, unknown>;
  try {
    notification = await verifySignedNotification(signedPayload, config.bundleId);
  } catch (error) {
    const message = error instanceof AppleIapError ? error.message : String(error);
    billingLog.error(ctx, 'JWS_INVALID', 'verify_notification', false, message);
    return errorResponse(401, 'INVALID_SIGNATURE', message);
  }

  const notificationType = typeof notification.notificationType === 'string' ? notification.notificationType : 'UNKNOWN';
  const subtype = typeof notification.subtype === 'string' ? notification.subtype : '';
  const data = (notification.data ?? {}) as Record<string, unknown>;
  const environment = typeof data.environment === 'string' ? data.environment : '';
  const bundleId = typeof data.bundleId === 'string' ? data.bundleId : '';
  const signedTransactionInfo = data.signedTransactionInfo;

  if (bundleId !== config.bundleId) {
    billingLog.error(ctx, 'BUNDLE_MISMATCH', 'verify_notification', false, bundleId);
    return errorResponse(401, 'INVALID_BUNDLE', 'bundleId does not match');
  }
  if (typeof signedTransactionInfo !== 'string' || !signedTransactionInfo) {
    return errorResponse(400, 'VALIDATION_ERROR', 'signedTransactionInfo required');
  }

  let tx: DecodedTransaction;
  try {
    const txEnvironment = environment === 'Production' ? 'Production' : 'Sandbox';
    tx = readTransaction(await verifySignedTransaction(signedTransactionInfo, txEnvironment, config.bundleId));
  } catch (error) {
    const message = error instanceof AppleIapError ? error.message : String(error);
    billingLog.error(ctx, 'TX_JWS_INVALID', 'verify_transaction', false, message);
    return errorResponse(401, 'INVALID_SIGNATURE', message);
  }
  if (tx.bundleId !== config.bundleId || tx.environment !== environment) {
    billingLog.error(ctx, 'TX_MISMATCH', 'verify_transaction', false);
    return errorResponse(401, 'INVALID_TRANSACTION', 'transaction bundle or environment does not match');
  }

  const userId = await findUserId(svc, tx);
  const productId = tx.productId ?? '';
  const originalTransactionId = tx.originalTransactionId ?? '';
  const transactionId = tx.transactionId || originalTransactionId;
  billingLog.opStart({ ...ctx, userId: userId ?? undefined, platform: 'ios', productId }, `appstore-notification:${notificationType}`);

  if (!userId || !originalTransactionId) {
    billingLog.error(ctx, 'USER_NOT_FOUND', 'match_user', false);
    billingLog.opEnd(ctx, `appstore-notification:${notificationType}`, 'unmatched', Date.now() - startMs);
    return jsonResponse({ opToken, received: true, matched: false });
  }

  const expiresDate = tx.expiresDate != null ? isoFromMillis(tx.expiresDate) : undefined;
  const rawPayload = {
    notificationType,
    subtype,
    environment,
    bundleId,
    originalTransactionId,
    transactionId,
    productId,
    expiresDate,
    appAccountToken: tx.appAccountToken,
  };

  if (notificationType === 'DID_RENEW' || notificationType === 'SUBSCRIBED') {
    if (tx.revocationDate != null || tx.expiresDate == null || tx.expiresDate <= Date.now() || tx.purchaseDate == null) {
      billingLog.reconcile(ctx, 'notification', 'skipped_inactive');
    } else {
      const result = await grantBillingCredit({
        svc,
        ctx: { ...ctx, userId, platform: 'ios', productId },
        userId,
        platform: 'ios',
        productId,
        transactionIdOrToken: transactionId,
        eventType: notificationType === 'DID_RENEW' ? 'renewal' : 'initial_purchase',
        periodAnchor: periodAnchorFromMillis(tx.purchaseDate),
        rawPayload,
      });
      billingLog.reconcile(ctx, 'notification', result.granted ? 'granted' : 'dedupe');
    }
  } else if (notificationType === 'EXPIRED' || notificationType === 'REVOKE' || notificationType === 'REFUND') {
    await svc.from('user_entitlements').update({
      status: 'expired',
      auto_renew: false,
    }).eq('user_id', userId);
    if (notificationType === 'REFUND') {
      await svc.from('purchase_events').update({ verification_status: 'refunded' })
        .eq('user_id', userId)
        .eq('purchase_token_or_txid', transactionId);
    }
    billingLog.reconcile(ctx, 'notification', `entitlement_closed:${notificationType}`);
  } else if (notificationType === 'DID_CHANGE_RENEWAL_STATUS') {
    const autoRenew = subtype !== 'AUTO_RENEW_DISABLED';
    await svc.from('user_entitlements').update({ auto_renew: autoRenew }).eq('user_id', userId);
    billingLog.reconcile(ctx, 'notification', `auto_renew_changed:${autoRenew}`);
  }

  billingLog.opEnd(ctx, `appstore-notification:${notificationType}`, 'success', Date.now() - startMs);
  return jsonResponse({ opToken, received: true, matched: true });
});

async function findUserId(svc: SupabaseClient, tx: DecodedTransaction): Promise<string | null> {
  const token = tx.appAccountToken ?? '';
  if (UUID_RE.test(token)) {
    const { data, error } = await svc.auth.admin.getUserById(token);
    if (!error && data?.user) return data.user.id;
  }
  const original = tx.originalTransactionId;
  if (!original) return null;

  const byToken = await svc.from('purchase_events')
    .select('user_id')
    .eq('platform', 'ios')
    .eq('purchase_token_or_txid', original)
    .order('created_at', { ascending: false })
    .limit(1)
    .maybeSingle();
  if (byToken.data?.user_id) return byToken.data.user_id as string;

  const byPayload = await svc.from('purchase_events')
    .select('user_id')
    .eq('platform', 'ios')
    .filter('raw_payload->>originalTransactionId', 'eq', original)
    .order('created_at', { ascending: false })
    .limit(1)
    .maybeSingle();
  return (byPayload.data?.user_id as string | undefined) ?? null;
}
