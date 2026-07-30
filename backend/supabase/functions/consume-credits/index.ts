import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.0';
import { errorResponse, jsonResponse, billingLog, generateOpToken, RESERVATION_TTL_SECONDS } from '../_shared/mod.ts';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      headers: { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type' },
    });
  }
  if (req.method !== 'POST') return errorResponse(405, 'METHOD_NOT_ALLOWED', 'POST only');

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

  let body: Record<string, unknown>;
  try { body = await req.json(); } catch { return errorResponse(400, 'INVALID_BODY', 'Invalid JSON'); }

  const action = body.action as string;
  const ctx = { opToken, userId: user.id };
  billingLog.opStart(ctx, `consume-credits:${action}`);

  // ── RESERVE ─────────────────────────────────────────────────────────────────
  if (action === 'reserve') {
    const amount = body.amount as number;
    const reason = body.reason as string;
    const idempotencyKey = body.idempotencyKey as string;

    if (!amount || amount <= 0) return errorResponse(400, 'VALIDATION_ERROR', 'amount must be positive');
    if (!idempotencyKey) return errorResponse(400, 'VALIDATION_ERROR', 'idempotencyKey required');

    const expiresAt = new Date(Date.now() + RESERVATION_TTL_SECONDS * 1000).toISOString();

    try {
      const { data, error } = await svc.rpc('billing_ledger_insert', {
        p_user_id: user.id,
        p_delta: -amount,
        p_reason_code: 'reservation_charge',
        p_idempotency_key: `reserve_${idempotencyKey}`,
        p_reservation_status: 'reserved',
        p_expires_at: expiresAt,
        p_metadata: { reason, originalAmount: amount },
      });

      if (error) {
        if (error.message?.includes('INSUFFICIENT_CREDITS')) {
          billingLog.error(ctx, 'INSUFFICIENT_CREDITS', 'reserve', false);
          billingLog.opEnd(ctx, 'consume-credits:reserve', 'insufficient', Date.now() - startMs);
          return errorResponse(402, 'INSUFFICIENT_CREDITS', 'Not enough credits', { required: amount });
        }
        throw error;
      }

      const row = Array.isArray(data) ? data[0] : data;
      billingLog.reservation(ctx, 'reserved', row.ledger_id, { amount, ttl: RESERVATION_TTL_SECONDS });
      billingLog.opEnd(ctx, 'consume-credits:reserve', 'success', Date.now() - startMs);

      return jsonResponse({ opToken, reservationId: row.ledger_id, newBalance: row.new_balance, expiresAt });
    } catch (e) {
      billingLog.error(ctx, 'RESERVE_FAILED', 'billing_ledger_insert', true, String(e));
      billingLog.opEnd(ctx, 'consume-credits:reserve', 'error', Date.now() - startMs);
      return errorResponse(500, 'INTERNAL_ERROR', 'Failed to reserve credits');
    }
  }

  // ── COMMIT ──────────────────────────────────────────────────────────────────
  if (action === 'commit') {
    const reservationId = body.reservationId as string;
    if (!reservationId) return errorResponse(400, 'VALIDATION_ERROR', 'reservationId required');

    const { data, error } = await svc.rpc('billing_reservation_commit', {
      p_ledger_id: reservationId,
      p_user_id: user.id,
    });

    if (error || !data) {
      billingLog.error(ctx, 'COMMIT_FAILED', 'billing_reservation_commit', false, error?.message);
      billingLog.opEnd(ctx, 'consume-credits:commit', 'error', Date.now() - startMs);
      return errorResponse(400, 'COMMIT_FAILED', 'Reservation not found or already finalized');
    }

    billingLog.reservation(ctx, 'committed', reservationId);
    billingLog.opEnd(ctx, 'consume-credits:commit', 'success', Date.now() - startMs);
    return jsonResponse({ opToken, committed: true });
  }

  // ── ROLLBACK ────────────────────────────────────────────────────────────────
  if (action === 'rollback') {
    const reservationId = body.reservationId as string;
    if (!reservationId) return errorResponse(400, 'VALIDATION_ERROR', 'reservationId required');

    const { data, error } = await svc.rpc('billing_reservation_rollback', {
      p_ledger_id: reservationId,
      p_user_id: user.id,
    });

    const row = Array.isArray(data) ? data[0] : data;
    billingLog.reservation(ctx, row?.success ? 'rolled_back' : 'rollback_noop', reservationId);
    billingLog.opEnd(ctx, 'consume-credits:rollback', row?.success ? 'success' : 'noop', Date.now() - startMs);
    return jsonResponse({ opToken, rolledBack: row?.success ?? false, newBalance: row?.new_balance ?? 0 });
  }

  // ── SWEEP (internal/admin only) ─────────────────────────────────────────────
  if (action === 'sweep') {
    const { data, error } = await svc.rpc('billing_sweep_expired');
    billingLog.opEnd(ctx, 'consume-credits:sweep', 'success', Date.now() - startMs);
    return jsonResponse({ opToken, sweptCount: data ?? 0 });
  }

  return errorResponse(400, 'VALIDATION_ERROR', 'action must be reserve, commit, rollback, or sweep');
});
