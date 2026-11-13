// ═══════════════════════════════════════════════════════════════════════════════
// Billing Structured Logger
// Every billing operation produces machine-parseable truth logs.
// ═══════════════════════════════════════════════════════════════════════════════

export function generateOpToken(): string {
  return crypto.randomUUID().slice(0, 12);
}

export interface BillingLogContext {
  opToken: string;
  userId?: string;
  platform?: string;
  productId?: string;
}

function fmt(ctx: BillingLogContext, parts: Record<string, unknown>): string {
  const base = `[billing] opToken=${ctx.opToken}`;
  const extra = Object.entries(parts)
    .map(([k, v]) => `${k}=${v}`)
    .join(' ');
  return `${base} ${extra}`;
}

export const billingLog = {
  opStart(ctx: BillingLogContext, op: string) {
    console.log(fmt(ctx, {
      op: 'start',
      action: op,
      user: ctx.userId ?? 'unknown',
      platform: ctx.platform ?? 'unknown',
      product: ctx.productId ?? 'none',
    }));
  },

  opEnd(ctx: BillingLogContext, op: string, result: string, durationMs: number) {
    console.log(fmt(ctx, {
      op: 'end',
      action: op,
      result,
      duration_ms: durationMs,
    }));
  },

  dedupe(ctx: BillingLogContext, key: string, hit: boolean) {
    console.log(fmt(ctx, { dedupe: '', key, hit }));
  },

  grant(ctx: BillingLogContext, type: string, amount: number) {
    console.log(fmt(ctx, {
      grant: '', type, amount, user: ctx.userId ?? 'unknown',
    }));
  },

  wallet(ctx: BillingLogContext, balanceBefore: number, delta: number, balanceAfter: number) {
    console.log(fmt(ctx, {
      wallet: '', balance_before: balanceBefore, delta, balance_after: balanceAfter,
    }));
  },

  reservation(ctx: BillingLogContext, state: string, id: string, extra?: Record<string, unknown>) {
    console.log(fmt(ctx, {
      reservation: '', state, id, user: ctx.userId ?? 'unknown',
      ...(extra ?? {}),
    }));
  },

  reconcile(ctx: BillingLogContext, source: string, result: string) {
    console.log(fmt(ctx, { reconcile: '', source, result }));
  },

  error(ctx: BillingLogContext, code: string, step: string, retryable: boolean, detail?: string) {
    console.error(fmt(ctx, {
      error: '', code, step, retryable, detail: detail ?? '',
    }));
  },
};
