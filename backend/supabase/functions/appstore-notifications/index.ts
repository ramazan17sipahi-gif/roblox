// ═══════════════════════════════════════════════════════════════════════════════
// POST /appstore-notifications — App Store Server Notifications V2
// Uses shared grantBillingCredit() — never grants independently.
// ═══════════════════════════════════════════════════════════════════════════════

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.0';
import { errorResponse, jsonResponse, grantBillingCredit, billingLog, generateOpToken } from '../_shared/mod.ts';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

Deno.serve(async (req: Request) => {
  if (req.method !== 'POST') return errorResponse(405, 'METHOD_NOT_ALLOWED', 'POST only');

  const startMs = Date.now();
  const opToken = generateOpToken();
  const ctx = { opToken };

  const svc = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  let body: Record<string, unknown>;
  try { body = await req.json(); } catch { return errorResponse(400, 'INVALID_BODY', 'Invalid JSON'); }

  // TODO: Verify signedPayload JWS signature with Apple root cert
  // For production: decode body.signedPayload → extract notification data
  const signedPayload = body.signedPayload as string;
  if (!signedPayload) return errorResponse(400, 'VALIDATION_ERROR', 'signedPayload required');

  // Stub: parse notification (production: JWS decode)
  const notificationType = body.notificationType as string ?? 'UNKNOWN';
  const subtype = body.subtype as string ?? '';
  const txInfo = (body.data as Record<string, unknown> ?? {});
  const userId = txInfo.appAccountToken as string;
  const originalTransactionId = txInfo.originalTransactionId as string ?? '';
  const productId = txInfo.productId as string ?? '';
  const expiresDate = txInfo.expiresDate as string;

  billingLog.opStart({ ...ctx, userId, platform: 'ios', productId }, `appstore-notification:${notificationType}`);

  if (!userId || !originalTransactionId) {
    billingLog.error(ctx, 'MISSING_FIELDS', 'parse_notification', false);
    return jsonResponse({ opToken, received: true });
  }

  // ── Handle notification types ──
  if (notificationType === 'DID_RENEW') {
    const periodAnchor = expiresDate
      ? new Date(new Date(expiresDate).getTime() - 30 * 24 * 60 * 60 * 1000).toISOString().slice(0, 10)
      : new Date().toISOString().slice(0, 10);

    const result = await grantBillingCredit({
      svc, ctx: { ...ctx, userId, platform: 'ios', productId },
      userId, platform: 'ios', productId,
      transactionIdOrToken: originalTransactionId,
      eventType: 'renewal',
      periodAnchor,
      rawPayload: { notificationType, subtype, ...txInfo },
    });

    billingLog.reconcile(ctx, 'notification', result.granted ? 'renewal_granted' : 'renewal_dedupe');
  } else if (notificationType === 'SUBSCRIBED' && subtype === 'INITIAL_BUY') {
    const result = await grantBillingCredit({
      svc, ctx: { ...ctx, userId, platform: 'ios', productId },
      userId, platform: 'ios', productId,
      transactionIdOrToken: originalTransactionId,
      eventType: 'initial_purchase',
      periodAnchor: new Date().toISOString().slice(0, 10),
      rawPayload: { notificationType, subtype, ...txInfo },
    });
    billingLog.reconcile(ctx, 'notification', result.granted ? 'initial_granted' : 'initial_dedupe');
  } else if (notificationType === 'EXPIRED' || notificationType === 'REVOKE') {
    await svc.from('user_entitlements').update({
      status: 'expired', auto_renew: false,
    }).eq('user_id', userId);
    billingLog.reconcile(ctx, 'notification', `entitlement_expired:${notificationType}`);
  } else if (notificationType === 'DID_CHANGE_RENEWAL_STATUS') {
    const autoRenew = subtype !== 'AUTO_RENEW_DISABLED';
    await svc.from('user_entitlements').update({ auto_renew: autoRenew }).eq('user_id', userId);
    billingLog.reconcile(ctx, 'notification', `auto_renew_changed:${autoRenew}`);
  } else if (notificationType === 'REFUND') {
    // Clawback: mark purchase as refunded, no wallet change (policy decision)
    await svc.from('purchase_events').update({ verification_status: 'refunded' })
      .eq('user_id', userId).eq('purchase_token_or_txid', originalTransactionId);
    await svc.from('user_entitlements').update({ status: 'expired' }).eq('user_id', userId);
    billingLog.reconcile(ctx, 'notification', 'refund_processed');
  }

  billingLog.opEnd(ctx, `appstore-notification:${notificationType}`, 'success', Date.now() - startMs);
  return jsonResponse({ opToken, received: true });
});
