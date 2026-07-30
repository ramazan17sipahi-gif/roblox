-- ============================================================================
-- Migration 011: Production-Hardened Billing System
-- ADDITIVE ONLY — No DROP TABLE, No DROP COLUMN
-- ============================================================================

-- ── billing_products: Admin-managed product catalog ──────────────────────────
CREATE TABLE IF NOT EXISTS public.billing_products (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code               text UNIQUE NOT NULL,
  type               text NOT NULL CHECK (type IN ('subscription','topup')),
  plan_code          text,
  ios_product_id     text,
  android_product_id text,
  credit_amount      int NOT NULL DEFAULT 0,
  display_name       text NOT NULL,
  display_order      int NOT NULL DEFAULT 0,
  is_active          boolean NOT NULL DEFAULT true,
  metadata           jsonb DEFAULT '{}',
  created_at         timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_billing_products_type ON public.billing_products(type);
CREATE INDEX IF NOT EXISTS idx_billing_products_active ON public.billing_products(is_active);

ALTER TABLE public.billing_products ENABLE ROW LEVEL SECURITY;
CREATE POLICY billing_products_select_active
  ON public.billing_products FOR SELECT
  USING (is_active = true);

-- ── user_entitlements: Active subscription state per user ────────────────────
CREATE TABLE IF NOT EXISTS public.user_entitlements (
  user_id            uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  plan_code          text NOT NULL DEFAULT 'free',
  platform           text CHECK (platform IN ('ios','android')),
  status             text NOT NULL DEFAULT 'active'
    CHECK (status IN ('active','grace_period','expired','cancelled')),
  product_code       text,
  current_period_end timestamptz,
  auto_renew         boolean DEFAULT true,
  source_token       text,
  created_at         timestamptz NOT NULL DEFAULT now(),
  updated_at         timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_user_entitlements_status ON public.user_entitlements(status);
CREATE INDEX IF NOT EXISTS idx_user_entitlements_period ON public.user_entitlements(current_period_end);

ALTER TABLE public.user_entitlements ENABLE ROW LEVEL SECURITY;
CREATE POLICY user_entitlements_select_own
  ON public.user_entitlements FOR SELECT
  USING (auth.uid() = user_id);

CREATE TRIGGER trg_user_entitlements_updated_at
  BEFORE UPDATE ON public.user_entitlements
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ── credit_wallets: Materialized balance cache ──────────────────────────────
CREATE TABLE IF NOT EXISTS public.credit_wallets (
  user_id    uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  balance    int NOT NULL DEFAULT 0 CHECK (balance >= 0),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.credit_wallets ENABLE ROW LEVEL SECURITY;
CREATE POLICY credit_wallets_select_own
  ON public.credit_wallets FOR SELECT
  USING (auth.uid() = user_id);

CREATE TRIGGER trg_credit_wallets_updated_at
  BEFORE UPDATE ON public.credit_wallets
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ── purchase_events: Audit trail with global dedupe ─────────────────────────
CREATE TABLE IF NOT EXISTS public.purchase_events (
  id                     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id                uuid REFERENCES auth.users(id),
  platform               text NOT NULL CHECK (platform IN ('ios','android')),
  product_id             text NOT NULL,
  purchase_token_or_txid text NOT NULL,
  raw_payload            jsonb NOT NULL DEFAULT '{}',
  verification_status    text NOT NULL DEFAULT 'pending'
    CHECK (verification_status IN ('pending','verified','failed','refunded')),
  dedupe_key             text UNIQUE NOT NULL,
  idempotency_key        text UNIQUE,
  created_at             timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_purchase_events_user ON public.purchase_events(user_id);
CREATE INDEX IF NOT EXISTS idx_purchase_events_dedupe ON public.purchase_events(dedupe_key);
CREATE INDEX IF NOT EXISTS idx_purchase_events_status ON public.purchase_events(verification_status);

ALTER TABLE public.purchase_events ENABLE ROW LEVEL SECURITY;
CREATE POLICY purchase_events_select_own
  ON public.purchase_events FOR SELECT
  USING (auth.uid() = user_id);

-- ── Extend credits_ledger with reservation columns ──────────────────────────
-- ADDITIVE: new columns only, no drops
ALTER TABLE public.credits_ledger
  ADD COLUMN IF NOT EXISTS reservation_status text
    CHECK (reservation_status IN ('reserved','committed','rolled_back','expired')),
  ADD COLUMN IF NOT EXISTS reserved_at timestamptz,
  ADD COLUMN IF NOT EXISTS expires_at timestamptz;

CREATE INDEX IF NOT EXISTS idx_credits_ledger_reservation
  ON public.credits_ledger(reservation_status)
  WHERE reservation_status IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_credits_ledger_expires
  ON public.credits_ledger(expires_at)
  WHERE reservation_status = 'reserved';

-- ── Expand reason_code CHECK constraint ─────────────────────────────────────
-- Drop old constraint and recreate with expanded values
ALTER TABLE public.credits_ledger DROP CONSTRAINT IF EXISTS credits_ledger_reason_code_check;
ALTER TABLE public.credits_ledger ADD CONSTRAINT credits_ledger_reason_code_check
  CHECK (reason_code IN (
    -- Existing
    'generation_image_charge','generation_3d_charge','export_charge',
    'monthly_refill','admin_adjustment','compensation_refund',
    'referral_bonus','signup_bonus',
    -- New billing
    'subscription_initial_grant','subscription_renewal_grant',
    'topup_purchase','subscription_refund','topup_refund',
    'reservation_charge','reservation_rollback'
  ));

-- ═══════════════════════════════════════════════════════════════════════════════
-- ATOMIC FUNCTIONS
-- ═══════════════════════════════════════════════════════════════════════════════

-- ── billing_ledger_insert: Atomic ledger + wallet in one transaction ────────
CREATE OR REPLACE FUNCTION public.billing_ledger_insert(
  p_user_id uuid,
  p_delta int,
  p_reason_code text,
  p_idempotency_key text,
  p_reservation_status text DEFAULT NULL,
  p_expires_at timestamptz DEFAULT NULL,
  p_related_job_id uuid DEFAULT NULL,
  p_metadata jsonb DEFAULT '{}'
)
RETURNS TABLE(ledger_id uuid, new_balance int)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_lid uuid;
  v_bal int;
BEGIN
  -- Idempotency check
  SELECT id INTO v_lid FROM public.credits_ledger
    WHERE idempotency_key = p_idempotency_key;
  IF v_lid IS NOT NULL THEN
    SELECT balance INTO v_bal FROM public.credit_wallets WHERE user_id = p_user_id;
    RETURN QUERY SELECT v_lid, COALESCE(v_bal, 0);
    RETURN;
  END IF;

  -- Balance check for debits
  IF p_delta < 0 THEN
    SELECT balance INTO v_bal FROM public.credit_wallets WHERE user_id = p_user_id;
    IF COALESCE(v_bal, 0) + p_delta < 0 THEN
      RAISE EXCEPTION 'INSUFFICIENT_CREDITS: balance=%, requested=%', COALESCE(v_bal, 0), ABS(p_delta);
    END IF;
  END IF;

  -- Ledger insert
  INSERT INTO public.credits_ledger (
    user_id, delta, reason_code, idempotency_key,
    reservation_status, reserved_at, expires_at,
    related_job_id, metadata
  ) VALUES (
    p_user_id, p_delta, p_reason_code, p_idempotency_key,
    p_reservation_status,
    CASE WHEN p_reservation_status = 'reserved' THEN now() ELSE NULL END,
    p_expires_at,
    p_related_job_id, p_metadata
  )
  RETURNING id INTO v_lid;

  -- Wallet upsert (atomic, same transaction)
  INSERT INTO public.credit_wallets (user_id, balance, updated_at)
  VALUES (p_user_id, GREATEST(p_delta, 0), now())
  ON CONFLICT (user_id) DO UPDATE
  SET balance = GREATEST(public.credit_wallets.balance + p_delta, 0),
      updated_at = now();

  SELECT balance INTO v_bal FROM public.credit_wallets WHERE user_id = p_user_id;
  RETURN QUERY SELECT v_lid, v_bal;
END;
$$;

-- ── billing_reservation_commit: Transition reserved → committed ─────────────
CREATE OR REPLACE FUNCTION public.billing_reservation_commit(
  p_ledger_id uuid,
  p_user_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_updated int;
BEGIN
  UPDATE public.credits_ledger
  SET reservation_status = 'committed'
  WHERE id = p_ledger_id
    AND user_id = p_user_id
    AND reservation_status = 'reserved'
  ;
  GET DIAGNOSTICS v_updated = ROW_COUNT;
  RETURN v_updated > 0;
END;
$$;

-- ── billing_reservation_rollback: Transition reserved → rolled_back + refund ─
CREATE OR REPLACE FUNCTION public.billing_reservation_rollback(
  p_ledger_id uuid,
  p_user_id uuid
)
RETURNS TABLE(success boolean, new_balance int)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_delta int;
  v_bal int;
BEGIN
  -- Find and lock the reservation
  SELECT delta INTO v_delta FROM public.credits_ledger
    WHERE id = p_ledger_id
      AND user_id = p_user_id
      AND reservation_status = 'reserved'
    FOR UPDATE;

  IF v_delta IS NULL THEN
    -- Already committed/rolled_back/expired or wrong user
    SELECT balance INTO v_bal FROM public.credit_wallets WHERE user_id = p_user_id;
    RETURN QUERY SELECT false, COALESCE(v_bal, 0);
    RETURN;
  END IF;

  -- Mark as rolled_back
  UPDATE public.credits_ledger
  SET reservation_status = 'rolled_back'
  WHERE id = p_ledger_id;

  -- Refund: add back the absolute value of the delta
  UPDATE public.credit_wallets
  SET balance = balance + ABS(v_delta), updated_at = now()
  WHERE user_id = p_user_id;

  SELECT balance INTO v_bal FROM public.credit_wallets WHERE user_id = p_user_id;
  RETURN QUERY SELECT true, v_bal;
END;
$$;

-- ── billing_sweep_expired: Sweeper for orphaned reservations ────────────────
CREATE OR REPLACE FUNCTION public.billing_sweep_expired()
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_count int := 0;
  r RECORD;
BEGIN
  FOR r IN
    SELECT id, user_id, delta
    FROM public.credits_ledger
    WHERE reservation_status = 'reserved'
      AND expires_at < now()
    FOR UPDATE SKIP LOCKED
  LOOP
    -- Mark expired
    UPDATE public.credits_ledger
    SET reservation_status = 'expired'
    WHERE id = r.id;

    -- Refund wallet
    UPDATE public.credit_wallets
    SET balance = balance + ABS(r.delta), updated_at = now()
    WHERE user_id = r.user_id;

    v_count := v_count + 1;
  END LOOP;

  RETURN v_count;
END;
$$;

-- ── billing_drift_check: Detect wallet vs ledger divergence ─────────────────
CREATE OR REPLACE FUNCTION public.billing_drift_check()
RETURNS TABLE(user_id uuid, ledger_sum int, wallet_balance int, drift int)
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT
    w.user_id,
    COALESCE(l.s, 0)::int AS ledger_sum,
    w.balance AS wallet_balance,
    (w.balance - COALESCE(l.s, 0))::int AS drift
  FROM public.credit_wallets w
  LEFT JOIN (
    SELECT cl.user_id, SUM(cl.delta)::int AS s
    FROM public.credits_ledger cl
    WHERE cl.reservation_status IS DISTINCT FROM 'reserved'
      AND cl.reservation_status IS DISTINCT FROM 'expired'
    GROUP BY cl.user_id
  ) l ON l.user_id = w.user_id
  WHERE w.balance != COALESCE(l.s, 0);
$$;

-- ═══════════════════════════════════════════════════════════════════════════════
-- BACKFILL: Populate new tables from existing data
-- ═══════════════════════════════════════════════════════════════════════════════

-- Backfill credit_wallets from existing credits_ledger
INSERT INTO public.credit_wallets (user_id, balance, updated_at)
SELECT user_id, GREATEST(COALESCE(SUM(delta), 0)::int, 0), now()
FROM public.credits_ledger
GROUP BY user_id
ON CONFLICT (user_id) DO UPDATE
SET balance = EXCLUDED.balance, updated_at = now();

-- Backfill user_entitlements from existing subscriptions table
INSERT INTO public.user_entitlements (user_id, plan_code, status, current_period_end, updated_at)
SELECT user_id, plan_code,
  CASE WHEN status IN ('active','trialing') THEN 'active' ELSE 'expired' END,
  current_period_end, now()
FROM public.subscriptions
WHERE status IN ('active','trialing')
ON CONFLICT (user_id) DO NOTHING;

-- Seed default billing products (configurable, not hardcoded in app)
INSERT INTO public.billing_products (code, type, plan_code, ios_product_id, android_product_id, credit_amount, display_name, display_order) VALUES
  ('pro_monthly',    'subscription', 'pro',    'com.creator.pro_monthly',    'com.creator.pro_monthly',    50,  'Pro Monthly',       1),
  ('studio_monthly', 'subscription', 'studio', 'com.creator.studio_monthly', 'com.creator.studio_monthly', 200, 'Studio Monthly',    2),
  ('credits_10',     'topup',        NULL,     'com.creator.credits_10',     'com.creator.credits_10',     10,  '10 Credits',        1),
  ('credits_50',     'topup',        NULL,     'com.creator.credits_50',     'com.creator.credits_50',     50,  '50 Credits',        2),
  ('credits_200',    'topup',        NULL,     'com.creator.credits_200',    'com.creator.credits_200',    200, '200 Credits',       3)
ON CONFLICT (code) DO NOTHING;

-- Compatibility view (transition period)
CREATE OR REPLACE VIEW public.active_entitlement_v AS
SELECT user_id, plan_code, status, current_period_end, auto_renew, platform
FROM public.user_entitlements;
