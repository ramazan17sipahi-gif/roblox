-- PKCE OAuth sessions for platform account linking (Roblox).

CREATE TABLE IF NOT EXISTS public.oauth_link_sessions (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id            uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  platform_code      text NOT NULL CHECK (platform_code IN ('roblox')),
  linked_account_id  uuid NOT NULL REFERENCES public.linked_accounts(id) ON DELETE CASCADE,
  state              text NOT NULL UNIQUE,
  code_verifier      text NOT NULL,
  redirect_uri       text NOT NULL,
  expires_at         timestamptz NOT NULL,
  created_at         timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_oauth_link_sessions_user
  ON public.oauth_link_sessions(user_id);

CREATE INDEX IF NOT EXISTS idx_oauth_link_sessions_expires
  ON public.oauth_link_sessions(expires_at);

ALTER TABLE public.oauth_link_sessions ENABLE ROW LEVEL SECURITY;
