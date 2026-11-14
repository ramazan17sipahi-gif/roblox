-- ═══════════════════════════════════════════════════════════════
-- 005: Referral System & Additional Features
-- New tables for referral tracking and credit rewards
-- ═══════════════════════════════════════════════════════════════

-- Referral codes (Clean start)
DROP TABLE IF EXISTS public.credit_transactions CASCADE;
DROP TABLE IF EXISTS public.referral_uses CASCADE;
DROP TABLE IF EXISTS public.referral_codes CASCADE;

CREATE TABLE IF NOT EXISTS public.referral_codes (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  code TEXT NOT NULL UNIQUE,
  uses_count INTEGER DEFAULT 0,
  max_uses INTEGER DEFAULT 100,
  reward_credits INTEGER DEFAULT 5,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.referral_codes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "referral_codes_select" ON public.referral_codes;
CREATE POLICY "referral_codes_select" ON public.referral_codes
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "referral_codes_owner" ON public.referral_codes;
CREATE POLICY "referral_codes_owner" ON public.referral_codes
  FOR ALL USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Referral usage log
CREATE TABLE IF NOT EXISTS public.referral_uses (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  referral_code_id UUID NOT NULL REFERENCES public.referral_codes(id) ON DELETE CASCADE,
  referred_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  reward_given BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(referral_code_id, referred_user_id)
);

ALTER TABLE public.referral_uses ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "referral_uses_own" ON public.referral_uses;
CREATE POLICY "referral_uses_own" ON public.referral_uses
  FOR SELECT USING (
    referred_user_id = auth.uid() OR
    EXISTS (SELECT 1 FROM public.referral_codes WHERE id = referral_code_id AND user_id = auth.uid())
  );

DROP POLICY IF EXISTS "referral_uses_insert" ON public.referral_uses;
CREATE POLICY "referral_uses_insert" ON public.referral_uses
  FOR INSERT WITH CHECK (referred_user_id = auth.uid());

-- Auto-increment referral uses_count and give credits
CREATE OR REPLACE FUNCTION public.process_referral()
RETURNS TRIGGER AS $$
BEGIN
  -- Increment uses count
  UPDATE public.referral_codes 
  SET uses_count = uses_count + 1 
  WHERE id = NEW.referral_code_id;
  
  -- Give credits to referrer
  UPDATE auth.users 
  SET raw_user_meta_data = raw_user_meta_data || 
    jsonb_build_object('credits', 
      COALESCE((raw_user_meta_data->>'credits')::integer, 0) + 
      (SELECT reward_credits FROM public.referral_codes WHERE id = NEW.referral_code_id)
    )
  WHERE id = (SELECT user_id FROM public.referral_codes WHERE id = NEW.referral_code_id);
  
  -- Give credits to referred user too
  UPDATE auth.users
  SET raw_user_meta_data = raw_user_meta_data || 
    jsonb_build_object('credits', COALESCE((raw_user_meta_data->>'credits')::integer, 0) + 3)
  WHERE id = NEW.referred_user_id;
  
  UPDATE public.referral_uses SET reward_given = TRUE WHERE id = NEW.id;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS tr_process_referral ON public.referral_uses;
CREATE TRIGGER tr_process_referral
  AFTER INSERT ON public.referral_uses
  FOR EACH ROW EXECUTE FUNCTION public.process_referral();

-- User credits tracking 
CREATE TABLE IF NOT EXISTS public.credit_transactions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  amount INTEGER NOT NULL,
  type TEXT NOT NULL DEFAULT 'referral',
  description TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.credit_transactions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "credit_transactions_own" ON public.credit_transactions;
CREATE POLICY "credit_transactions_own" ON public.credit_transactions
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "credit_transactions_insert" ON public.credit_transactions;
CREATE POLICY "credit_transactions_insert" ON public.credit_transactions
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_referral_codes_user ON public.referral_codes(user_id);
CREATE INDEX IF NOT EXISTS idx_referral_codes_code ON public.referral_codes(code);
CREATE INDEX IF NOT EXISTS idx_referral_uses_referred ON public.referral_uses(referred_user_id);
CREATE INDEX IF NOT EXISTS idx_credit_transactions_user ON public.credit_transactions(user_id);
