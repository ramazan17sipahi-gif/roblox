// Who currently holds an Apple subscription, and how Restore moves it.
// One originalTransactionId maps to one app account. Restore onto a
// different account expires the previous Pro row and records the move in
// purchase_events.raw_payload. No new columns.

import { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2.49.0';
import { grantBillingCredit, GrantResult } from './billing_grant.ts';
import { BillingLogContext } from './billing_log.ts';

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

interface OwnerRow {
  user_id?: string | null;
  verification_status?: string | null;
  raw_payload?: { kind?: string; originalTransactionId?: string } | null;
  created_at?: string | null;
}

function isCurrentOwnerRow(row: OwnerRow): boolean {
  const kind = row.raw_payload?.kind;
  return row.verification_status === 'verified' || kind === 'transfer';
}

/** Latest verified or transferred purchase_events user for this Apple subscription. */
export async function currentOwnerForOriginalTransaction(
  svc: SupabaseClient,
  originalTransactionId: string,
): Promise<string | null> {
  if (!originalTransactionId) return null;

  const [byPayload, byToken] = await Promise.all([
    svc.from('purchase_events')
      .select('user_id, verification_status, raw_payload, created_at')
      .eq('platform', 'ios')
      .filter('raw_payload->>originalTransactionId', 'eq', originalTransactionId)
      .order('created_at', { ascending: false })
      .limit(20),
    svc.from('purchase_events')
      .select('user_id, verification_status, raw_payload, created_at')
      .eq('platform', 'ios')
      .eq('purchase_token_or_txid', originalTransactionId)
      .order('created_at', { ascending: false })
      .limit(20),
  ]);

  const rows = [...(byPayload.data ?? []), ...(byToken.data ?? [])] as OwnerRow[];
  rows.sort((a, b) => String(b.created_at ?? '').localeCompare(String(a.created_at ?? '')));
  for (const row of rows) {
    if (row.user_id && isCurrentOwnerRow(row)) return row.user_id;
  }
  return null;
}

/**
 * If the subscription belongs to someone else, expire their Pro and record
 * the move. Returns the previous user id, or null when nothing moved.
 */
export async function transferAppleSubscriptionIfNeeded(
  svc: SupabaseClient,
  input: { originalTransactionId: string; toUserId: string; productId: string },
): Promise<string | null> {
  const owner = await currentOwnerForOriginalTransaction(svc, input.originalTransactionId);
  if (!owner || owner === input.toUserId) return null;

  const { data: entitlement } = await svc
    .from('user_entitlements')
    .select('plan_code, status')
    .eq('user_id', owner)
    .maybeSingle();
  const plan = entitlement?.plan_code;
  const status = entitlement?.status;
  const activePro = (status === 'active' || status === 'grace_period') && (plan === 'pro' || plan === 'studio');
  if (activePro) {
    await svc.from('user_entitlements').update({
      status: 'expired',
      auto_renew: false,
    }).eq('user_id', owner);
  }

  const transferredAt = new Date().toISOString();
  const dedupeKey = `ios:${input.originalTransactionId}:transfer:${input.toUserId}:${transferredAt}`;
  await svc.from('purchase_events').insert({
    user_id: input.toUserId,
    platform: 'ios',
    product_id: input.productId,
    purchase_token_or_txid: input.originalTransactionId,
    raw_payload: {
      kind: 'transfer',
      originalTransactionId: input.originalTransactionId,
      fromUserId: owner,
      toUserId: input.toUserId,
      transferredAt,
    },
    verification_status: 'verified',
    dedupe_key: dedupeKey,
    idempotency_key: dedupeKey,
    created_at: transferredAt,
  });
  return owner;
}

/** Notification recipient: current owner, otherwise the original appAccountToken. */
export async function resolveAppleNotificationUser(
  svc: SupabaseClient,
  tx: { originalTransactionId?: string; appAccountToken?: string },
): Promise<string | null> {
  if (tx.originalTransactionId) {
    const owner = await currentOwnerForOriginalTransaction(svc, tx.originalTransactionId);
    if (owner) return owner;
  }
  const token = tx.appAccountToken ?? '';
  if (!UUID_RE.test(token)) return null;
  const { data, error } = await svc.auth.admin.getUserById(token);
  if (!error && data?.user?.id) return data.user.id;
  return null;
}

export async function completeIosPurchase(input: {
  svc: SupabaseClient;
  ctx: BillingLogContext;
  userId: string;
  productId: string;
  transactionId: string;
  verification: {
    eventType: 'initial_purchase' | 'renewal' | 'topup';
    periodAnchor: string;
    expiresDate?: string;
    originalTransactionId?: string;
    environment?: string;
  };
  body?: Record<string, unknown>;
}): Promise<GrantResult & { transferredFrom: string | null }> {
  const original = input.verification.originalTransactionId ?? '';
  const transferredFrom = original
    ? await transferAppleSubscriptionIfNeeded(input.svc, {
      originalTransactionId: original,
      toUserId: input.userId,
      productId: input.productId,
    })
    : null;
  const grant = await grantBillingCredit({
    svc: input.svc,
    ctx: input.ctx,
    userId: input.userId,
    platform: 'ios',
    productId: input.productId,
    transactionIdOrToken: input.transactionId,
    eventType: input.verification.eventType,
    periodAnchor: input.verification.periodAnchor,
    rawPayload: {
      ...(input.body ?? {}),
      expiresDate: input.verification.expiresDate,
      originalTransactionId: original,
      environment: input.verification.environment,
      verifiedAt: new Date().toISOString(),
      ...(transferredFrom ? { transferFromUserId: transferredFrom } : {}),
    },
  });
  return { ...grant, transferredFrom };
}
