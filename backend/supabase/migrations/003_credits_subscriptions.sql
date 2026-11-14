-- ============================================================================
-- Migration 003: Credits, Subscriptions, Entitlements
-- ============================================================================

-- ── Subscriptions ───────────────────────────────────────────────────────────
CREATE TABLE public.subscriptions (
  id                        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id                   uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  provider                  text NOT NULL DEFAULT 'revenuecat',
  provider_customer_id      text,
  provider_subscription_id  text,
  plan_code                 text NOT NULL,
  status                    text NOT NULL DEFAULT 'active' CHECK (status IN ('active','past_due','cancelled','expired','trialing')),
  current_period_start      timestamptz,
  current_period_end        timestamptz,
  created_at                timestamptz NOT NULL DEFAULT now(),
  updated_at                timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX idx_subscriptions_provider ON public.subscriptions(provider, provider_subscription_id);
CREATE INDEX idx_subscriptions_user ON public.subscriptions(user_id);

CREATE TRIGGER trg_subscriptions_updated_at
  BEFORE UPDATE ON public.subscriptions
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ── Entitlements ────────────────────────────────────────────────────────────
CREATE TABLE public.entitlements (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  entitlement_code text NOT NULL CHECK (entitlement_code IN ('pro_generation','pro_export','pro_templates','priority_queue')),
  is_active        boolean NOT NULL DEFAULT true,
  source           text NOT NULL DEFAULT 'subscription',
  expires_at       timestamptz,
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_entitlements_user ON public.entitlements(user_id);
CREATE UNIQUE INDEX idx_entitlements_user_code ON public.entitlements(user_id, entitlement_code);

CREATE TRIGGER trg_entitlements_updated_at
  BEFORE UPDATE ON public.entitlements
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ── Credits Ledger ──────────────────────────────────────────────────────────
CREATE TABLE public.credits_ledger (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  delta           integer NOT NULL,
  reason_code     text NOT NULL CHECK (reason_code IN (
    'generation_image_charge','generation_3d_charge','export_charge',
    'monthly_refill','admin_adjustment','compensation_refund',
    'referral_bonus','signup_bonus'
  )),
  source          text NOT NULL DEFAULT 'system',
  related_job_id  uuid REFERENCES public.generation_jobs(id),
  idempotency_key text UNIQUE NOT NULL,
  metadata        jsonb DEFAULT '{}',
  created_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_credits_ledger_user ON public.credits_ledger(user_id);

-- ── Credits Balance Function ────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_credits_balance(p_user_id uuid)
RETURNS integer
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT COALESCE(SUM(delta), 0)::integer
  FROM public.credits_ledger
  WHERE user_id = p_user_id;
$$;

-- ── Charge Credits Function (idempotent) ────────────────────────────────────
CREATE OR REPLACE FUNCTION public.charge_credits(
  p_user_id uuid,
  p_amount integer,
  p_reason_code text,
  p_idempotency_key text,
  p_related_job_id uuid DEFAULT NULL,
  p_metadata jsonb DEFAULT '{}'
)
RETURNS TABLE(success boolean, new_balance integer, error_message text)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_balance integer;
  v_existing uuid;
BEGIN
  -- Idempotency check
  SELECT id INTO v_existing FROM public.credits_ledger WHERE idempotency_key = p_idempotency_key;
  IF v_existing IS NOT NULL THEN
    v_balance := public.get_credits_balance(p_user_id);
    RETURN QUERY SELECT true, v_balance, NULL::text;
    RETURN;
  END IF;

  -- Check balance
  v_balance := public.get_credits_balance(p_user_id);
  IF v_balance < p_amount THEN
    RETURN QUERY SELECT false, v_balance, 'Insufficient credits'::text;
    RETURN;
  END IF;

  -- Insert debit
  INSERT INTO public.credits_ledger (user_id, delta, reason_code, related_job_id, idempotency_key, metadata)
  VALUES (p_user_id, -p_amount, p_reason_code, p_related_job_id, p_idempotency_key, p_metadata);

  v_balance := public.get_credits_balance(p_user_id);
  RETURN QUERY SELECT true, v_balance, NULL::text;
END;
$$;

-- ── Refund Credits Function (idempotent) ────────────────────────────────────
CREATE OR REPLACE FUNCTION public.refund_credits(
  p_user_id uuid,
  p_amount integer,
  p_reason_code text,
  p_idempotency_key text,
  p_related_job_id uuid DEFAULT NULL
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_existing uuid;
  v_balance integer;
BEGIN
  SELECT id INTO v_existing FROM public.credits_ledger WHERE idempotency_key = p_idempotency_key;
  IF v_existing IS NOT NULL THEN
    RETURN public.get_credits_balance(p_user_id);
  END IF;

  INSERT INTO public.credits_ledger (user_id, delta, reason_code, related_job_id, idempotency_key)
  VALUES (p_user_id, p_amount, p_reason_code, p_related_job_id, p_idempotency_key);

  RETURN public.get_credits_balance(p_user_id);
END;
$$;

-- ── Referral System ─────────────────────────────────────────────────────────
CREATE TABLE public.referral_codes (
  id        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id   uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  code      text UNIQUE NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.referral_events (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code_id         uuid NOT NULL REFERENCES public.referral_codes(id) ON DELETE CASCADE,
  invited_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at      timestamptz NOT NULL DEFAULT now(),
  UNIQUE(code_id, invited_user_id)
);
