-- ============================================================================
-- Migration 004: Exports, Linked Accounts, Notifications, Usage, Moderation
-- ============================================================================

-- ── Exports ─────────────────────────────────────────────────────────────────
CREATE TABLE public.exports (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id           uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  design_id         uuid NOT NULL REFERENCES public.designs(id),
  design_version_id uuid NOT NULL REFERENCES public.design_versions(id),
  export_target     text NOT NULL CHECK (export_target IN ('preview_in_roblox','upload_to_roblox','save_private','publish_public','download_package')),
  status_code       text NOT NULL DEFAULT 'pending' CHECK (status_code IN ('pending','processing','completed','failed')),
  requested_format  text NOT NULL DEFAULT 'default',
  requested_params  jsonb DEFAULT '{}',
  error_code        text,
  error_message     text,
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_exports_user ON public.exports(user_id);
CREATE INDEX idx_exports_design ON public.exports(design_id);

CREATE TRIGGER trg_exports_updated_at
  BEFORE UPDATE ON public.exports
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE public.export_files (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  export_id       uuid NOT NULL REFERENCES public.exports(id) ON DELETE CASCADE,
  storage_bucket  text NOT NULL,
  storage_path    text NOT NULL,
  mime_type       text,
  file_size       bigint,
  created_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_export_files_export ON public.export_files(export_id);

-- ── Linked Accounts ─────────────────────────────────────────────────────────
CREATE TABLE public.linked_accounts (
  id                      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id                 uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  platform_code           text NOT NULL CHECK (platform_code IN ('roblox','minecraft','zepeto','fortnite','general_3d')),
  external_account_id     text,
  display_name            text,
  status_code             text NOT NULL DEFAULT 'pending' CHECK (status_code IN ('pending','active','expired','revoked')),
  encrypted_access_token  text,
  encrypted_refresh_token text,
  scopes                  jsonb DEFAULT '[]',
  linked_at               timestamptz,
  last_validated_at       timestamptz,
  created_at              timestamptz NOT NULL DEFAULT now(),
  updated_at              timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX idx_linked_accounts_user_platform ON public.linked_accounts(user_id, platform_code);
CREATE INDEX idx_linked_accounts_user ON public.linked_accounts(user_id);

CREATE TRIGGER trg_linked_accounts_updated_at
  BEFORE UPDATE ON public.linked_accounts
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE public.linked_account_audit (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  linked_account_id uuid NOT NULL REFERENCES public.linked_accounts(id) ON DELETE CASCADE,
  event_type        text NOT NULL,
  metadata          jsonb DEFAULT '{}',
  created_at        timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_linked_account_audit_account ON public.linked_account_audit(linked_account_id);

-- ── Notifications ───────────────────────────────────────────────────────────
CREATE TABLE public.notification_records (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id           uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  notification_type text NOT NULL CHECK (notification_type IN (
    'generation_queued','generation_processing','generation_completed','generation_failed',
    'export_ready','publish_completed','linked_account_required','insufficient_credits'
  )),
  title             text NOT NULL,
  body              text NOT NULL,
  payload           jsonb DEFAULT '{}',
  is_read           boolean NOT NULL DEFAULT false,
  created_at        timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_notifications_user ON public.notification_records(user_id);
CREATE INDEX idx_notifications_unread ON public.notification_records(user_id) WHERE is_read = false;

-- ── Usage Events ────────────────────────────────────────────────────────────
CREATE TABLE public.usage_events (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  event_type   text NOT NULL,
  subject_type text,
  subject_id   uuid,
  metadata     jsonb DEFAULT '{}',
  created_at   timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_usage_events_user ON public.usage_events(user_id);
CREATE INDEX idx_usage_events_type ON public.usage_events(event_type);

-- ── Moderation Flags ────────────────────────────────────────────────────────
CREATE TABLE public.moderation_flags (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  subject_type text NOT NULL,
  subject_id   uuid NOT NULL,
  flag_code    text NOT NULL,
  metadata     jsonb DEFAULT '{}',
  created_at   timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_moderation_flags_subject ON public.moderation_flags(subject_type, subject_id);
