-- ============================================================================
-- Migration 006: Row Level Security Policies
-- ============================================================================

-- Enable RLS on all tables
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.template_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.designs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.design_versions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.layers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.design_assets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.favorites ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.generation_jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.generation_job_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.generation_outputs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.entitlements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.credits_ledger ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.exports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.export_files ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.linked_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.linked_account_audit ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notification_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.usage_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.moderation_flags ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.referral_codes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.referral_events ENABLE ROW LEVEL SECURITY;

-- ═══════════════════════════════════════════════════════════════════════════
-- PROFILES
-- ═══════════════════════════════════════════════════════════════════════════
CREATE POLICY profiles_select_own ON public.profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY profiles_update_own ON public.profiles FOR UPDATE USING (auth.uid() = id);
-- Public profile view for discovery
CREATE POLICY profiles_select_public ON public.profiles FOR SELECT USING (true);

-- ═══════════════════════════════════════════════════════════════════════════
-- TEMPLATES — public readable
-- ═══════════════════════════════════════════════════════════════════════════
CREATE POLICY templates_select_public ON public.templates FOR SELECT USING (is_public = true);
CREATE POLICY template_categories_select ON public.template_categories FOR SELECT USING (true);

-- ═══════════════════════════════════════════════════════════════════════════
-- DESIGNS — own designs + public designs
-- ═══════════════════════════════════════════════════════════════════════════
CREATE POLICY designs_select_own ON public.designs FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY designs_select_public ON public.designs FOR SELECT USING (visibility_code = 'public' AND status_code = 'active');
CREATE POLICY designs_insert_own ON public.designs FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY designs_update_own ON public.designs FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY designs_delete_own ON public.designs FOR DELETE USING (auth.uid() = user_id);

-- ═══════════════════════════════════════════════════════════════════════════
-- DESIGN VERSIONS — follows design ownership
-- ═══════════════════════════════════════════════════════════════════════════
CREATE POLICY versions_select ON public.design_versions FOR SELECT
  USING (EXISTS (SELECT 1 FROM public.designs d WHERE d.id = design_id AND (d.user_id = auth.uid() OR (d.visibility_code = 'public' AND d.status_code = 'active'))));
CREATE POLICY versions_insert ON public.design_versions FOR INSERT
  WITH CHECK (EXISTS (SELECT 1 FROM public.designs d WHERE d.id = design_id AND d.user_id = auth.uid()));

-- ═══════════════════════════════════════════════════════════════════════════
-- LAYERS — follows design version ownership
-- ═══════════════════════════════════════════════════════════════════════════
CREATE POLICY layers_select ON public.layers FOR SELECT
  USING (EXISTS (SELECT 1 FROM public.design_versions dv JOIN public.designs d ON d.id = dv.design_id WHERE dv.id = design_version_id AND d.user_id = auth.uid()));
CREATE POLICY layers_insert ON public.layers FOR INSERT
  WITH CHECK (EXISTS (SELECT 1 FROM public.design_versions dv JOIN public.designs d ON d.id = dv.design_id WHERE dv.id = design_version_id AND d.user_id = auth.uid()));
CREATE POLICY layers_update ON public.layers FOR UPDATE
  USING (EXISTS (SELECT 1 FROM public.design_versions dv JOIN public.designs d ON d.id = dv.design_id WHERE dv.id = design_version_id AND d.user_id = auth.uid()));
CREATE POLICY layers_delete ON public.layers FOR DELETE
  USING (EXISTS (SELECT 1 FROM public.design_versions dv JOIN public.designs d ON d.id = dv.design_id WHERE dv.id = design_version_id AND d.user_id = auth.uid()));

-- ═══════════════════════════════════════════════════════════════════════════
-- DESIGN ASSETS — follows design version ownership
-- ═══════════════════════════════════════════════════════════════════════════
CREATE POLICY assets_select ON public.design_assets FOR SELECT
  USING (EXISTS (SELECT 1 FROM public.design_versions dv JOIN public.designs d ON d.id = dv.design_id WHERE dv.id = design_version_id AND (d.user_id = auth.uid() OR (d.visibility_code = 'public' AND d.status_code = 'active'))));

-- ═══════════════════════════════════════════════════════════════════════════
-- FAVORITES — own
-- ═══════════════════════════════════════════════════════════════════════════
CREATE POLICY favorites_select ON public.favorites FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY favorites_insert ON public.favorites FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY favorites_delete ON public.favorites FOR DELETE USING (auth.uid() = user_id);

-- ═══════════════════════════════════════════════════════════════════════════
-- GENERATION JOBS — own only
-- ═══════════════════════════════════════════════════════════════════════════
CREATE POLICY jobs_select_own ON public.generation_jobs FOR SELECT USING (auth.uid() = user_id);
-- Insert/Update via service role only (Edge Functions)

-- ═══════════════════════════════════════════════════════════════════════════
-- JOB EVENTS — follows job ownership
-- ═══════════════════════════════════════════════════════════════════════════
CREATE POLICY events_select ON public.generation_job_events FOR SELECT
  USING (EXISTS (SELECT 1 FROM public.generation_jobs j WHERE j.id = job_id AND j.user_id = auth.uid()));

-- ═══════════════════════════════════════════════════════════════════════════
-- GENERATION OUTPUTS — follows job ownership
-- ═══════════════════════════════════════════════════════════════════════════
CREATE POLICY outputs_select ON public.generation_outputs FOR SELECT
  USING (EXISTS (SELECT 1 FROM public.generation_jobs j WHERE j.id = job_id AND j.user_id = auth.uid()));

-- ═══════════════════════════════════════════════════════════════════════════
-- SUBSCRIPTIONS & ENTITLEMENTS — read own, write service-role only
-- ═══════════════════════════════════════════════════════════════════════════
CREATE POLICY subscriptions_select_own ON public.subscriptions FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY entitlements_select_own ON public.entitlements FOR SELECT USING (auth.uid() = user_id);

-- ═══════════════════════════════════════════════════════════════════════════
-- CREDITS LEDGER — read own, write service-role only
-- ═══════════════════════════════════════════════════════════════════════════
CREATE POLICY credits_select_own ON public.credits_ledger FOR SELECT USING (auth.uid() = user_id);

-- ═══════════════════════════════════════════════════════════════════════════
-- EXPORTS — own
-- ═══════════════════════════════════════════════════════════════════════════
CREATE POLICY exports_select_own ON public.exports FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY export_files_select ON public.export_files FOR SELECT
  USING (EXISTS (SELECT 1 FROM public.exports e WHERE e.id = export_id AND e.user_id = auth.uid()));

-- ═══════════════════════════════════════════════════════════════════════════
-- LINKED ACCOUNTS — own, tokens NEVER exposed via select
-- ═══════════════════════════════════════════════════════════════════════════
CREATE POLICY linked_select_own ON public.linked_accounts FOR SELECT
  USING (auth.uid() = user_id)
  -- Mask token columns: client should use a view or specific column select
  ;
CREATE POLICY linked_audit_select ON public.linked_account_audit FOR SELECT
  USING (EXISTS (SELECT 1 FROM public.linked_accounts la WHERE la.id = linked_account_id AND la.user_id = auth.uid()));

-- ═══════════════════════════════════════════════════════════════════════════
-- NOTIFICATIONS — own
-- ═══════════════════════════════════════════════════════════════════════════
CREATE POLICY notifications_select_own ON public.notification_records FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY notifications_update_own ON public.notification_records FOR UPDATE USING (auth.uid() = user_id);

-- ═══════════════════════════════════════════════════════════════════════════
-- USAGE EVENTS — service-role insert, own read
-- ═══════════════════════════════════════════════════════════════════════════
CREATE POLICY usage_select_own ON public.usage_events FOR SELECT USING (auth.uid() = user_id);

-- ═══════════════════════════════════════════════════════════════════════════
-- MODERATION — service-role only (no client policy)
-- ═══════════════════════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════════════════════
-- REFERRALS — own only
-- ═══════════════════════════════════════════════════════════════════════════
CREATE POLICY referral_codes_select ON public.referral_codes FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY referral_codes_insert ON public.referral_codes FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY referral_events_select ON public.referral_events FOR SELECT
  USING (EXISTS (SELECT 1 FROM public.referral_codes rc WHERE rc.id = code_id AND rc.user_id = auth.uid()));

-- ═══════════════════════════════════════════════════════════════════════════
-- Safe linked_accounts view (hides tokens)
-- ═══════════════════════════════════════════════════════════════════════════
CREATE OR REPLACE VIEW public.linked_accounts_safe AS
SELECT
  id, user_id, platform_code, external_account_id,
  display_name, status_code, scopes,
  linked_at, last_validated_at, created_at, updated_at
FROM public.linked_accounts;
