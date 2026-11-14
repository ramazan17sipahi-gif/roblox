-- Roblox OAuth login: identity map + pre-auth PKCE sessions (no user yet).

CREATE TABLE IF NOT EXISTS public.roblox_identities (
  roblox_user_id text PRIMARY KEY,
  user_id        uuid NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at     timestamptz NOT NULL DEFAULT now(),
  updated_at     timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_roblox_identities_user
  ON public.roblox_identities(user_id);

CREATE TRIGGER trg_roblox_identities_updated_at
  BEFORE UPDATE ON public.roblox_identities
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.roblox_identities ENABLE ROW LEVEL SECURITY;

-- Users can read their own mapping; writes only via service role (edge functions).
CREATE POLICY roblox_identities_select_own ON public.roblox_identities
  FOR SELECT USING (auth.uid() = user_id);

-- Login OAuth sessions (anonymous until finalize creates/finds a user).
CREATE TABLE IF NOT EXISTS public.oauth_login_sessions (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  platform_code  text NOT NULL CHECK (platform_code IN ('roblox')),
  state          text NOT NULL UNIQUE,
  code_verifier  text NOT NULL,
  redirect_uri   text NOT NULL,
  expires_at     timestamptz NOT NULL,
  created_at     timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_oauth_login_sessions_expires
  ON public.oauth_login_sessions(expires_at);

ALTER TABLE public.oauth_login_sessions ENABLE ROW LEVEL SECURITY;
-- No client policies: edge functions use service role only.

-- Helpful lookup when reconciling already-linked Roblox accounts.
CREATE UNIQUE INDEX IF NOT EXISTS idx_linked_accounts_roblox_external
  ON public.linked_accounts(external_account_id)
  WHERE platform_code = 'roblox'
    AND external_account_id IS NOT NULL
    AND status_code = 'active';
