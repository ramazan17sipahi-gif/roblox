// ═══════════════════════════════════════════════════════════════════════════════
// POST /google-rtdn — Google Play RTDN (Real-Time Developer Notifications)
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

  // TODO: Verify Pub/Sub JWT bearer token (audience + service account)

  const svc = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  let body: Record<string, unknown>;
  try { body = await req.json(); } catch { return errorResponse(400, 'INVALID_BODY', 'Invalid JSON'); }

  // Pub/Sub message structure
  const message = body.message as Record<string, unknown> | undefined;
  if (!message?.data) return errorResponse(400, 'VALIDATION_ERROR', 'Missing message.data');

  let notification: Record<string, unknown>;
  try {
    const decoded = atob(message.data as string);
    notification = JSON.parse(decoded);
  } catch {
    return errorResponse(400, 'INVALID_BODY', 'Cannot decode message data');
  }

  const subscriptionNotification = notification.subscriptionNotification as Record<string, unknown> | undefined;
  const oneTimeProductNotification = notification.oneTimeProductNotification as Record<string, unknown> | undefined;

  billingLog.opStart({ ...ctx, platform: 'android' }, 'google-rtdn');

  if (subscriptionNotification) {
    const notificationType = subscriptionNotification.notificationType as number;
    const purchaseToken = subscriptionNotification.purchaseToken as string;
    const subscriptionId = subscriptionNotification.subscriptionId as string;

    // TODO: Fetch actual user_id via obfuscatedAccountId from
    // androidpublisher.purchases.subscriptionsv2.get()
    // For now: lookup from purchase_events or user_entitlements
    const { data: existing } = await svc.from('purchase_events')
      .select('user_id').eq('purchase_token_or_txid', purchaseToken).limit(1).maybeSingle();
    const userId = existing?.user_id as string;

    if (!userId) {
      billingLog.error(ctx, 'USER_NOT_FOUND', 'rtdn_user_lookup', false, `token=${purchaseToken}`);
      return jsonResponse({ opToken, received: true });
    }

    // SUBSCRIPTION_RENEWED (4), SUBSCRIPTION_PURCHASED (1)
    if (notificationType === 4 || notificationType === 1) {
      const eventType = notificationType === 1 ? 'initial_purchase' as const : 'renewal' as const;
      const result = await grantBillingCredit({
        svc, ctx: { ...ctx, userId, platform: 'android', productId: subscriptionId },
        userId, platform: 'android', productId: subscriptionId,
        transactionIdOrToken: purchaseToken,
        eventType,
        periodAnchor: new Date().toISOString().slice(0, 10),
        rawPayload: { notificationType, ...subscriptionNotification },
      });
      billingLog.reconcile(ctx, 'notification', result.granted ? `${eventType}_granted` : `${eventType}_dedupe`);
    }
    // SUBSCRIPTION_CANCELED (3)
    else if (notificationType === 3) {
      await svc.from('user_entitlements').update({ auto_renew: false }).eq('user_id', userId);
      billingLog.reconcile(ctx, 'notification', 'cancelled');
    }
    // SUBSCRIPTION_EXPIRED (13)
    else if (notificationType === 13) {
      await svc.from('user_entitlements').update({ status: 'expired' }).eq('user_id', userId);
      billingLog.reconcile(ctx, 'notification', 'expired');
    }
    // SUBSCRIPTION_REVOKED (12)
    else if (notificationType === 12) {
      await svc.from('user_entitlements').update({ status: 'expired', auto_renew: false }).eq('user_id', userId);
      await svc.from('purchase_events').update({ verification_status: 'refunded' })
        .eq('purchase_token_or_txid', purchaseToken);
      billingLog.reconcile(ctx, 'notification', 'revoked');
    }
  }

  if (oneTimeProductNotification) {
    // One-time purchases are handled by verify-purchase flow
    // RTDN for one-time is informational only
    billingLog.reconcile(ctx, 'notification', 'onetime_ack');
  }

  billingLog.opEnd(ctx, 'google-rtdn', 'success', Date.now() - startMs);
  return jsonResponse({ opToken, received: true });
});
