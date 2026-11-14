-- ============================================================================
-- Migration 001: Core Tables — profiles, templates, designs, versions, layers
-- ============================================================================

-- ── Trigger function for updated_at ─────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ── Profiles ────────────────────────────────────────────────────────────────
CREATE TABLE public.profiles (
  id          uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  username    text UNIQUE,
  display_name text,
  bio         text,
  avatar_path text,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);

CREATE TRIGGER trg_profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- Auto-create profile on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, display_name)
  VALUES (NEW.id, COALESCE(NEW.raw_user_meta_data->>'display_name', 'Creator'));
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ── Templates ───────────────────────────────────────────────────────────────
CREATE TABLE public.templates (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  platform_code     text NOT NULL CHECK (platform_code IN ('roblox','minecraft','zepeto','fortnite','general_3d')),
  template_type     text NOT NULL,
  title             text NOT NULL,
  slug              text UNIQUE,
  description       text,
  cover_image_path  text,
  preview_model_path text,
  is_public         boolean NOT NULL DEFAULT true,
  created_by        uuid REFERENCES auth.users(id),
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now()
);

CREATE TRIGGER trg_templates_updated_at
  BEFORE UPDATE ON public.templates
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE public.template_categories (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  template_id   uuid NOT NULL REFERENCES public.templates(id) ON DELETE CASCADE,
  category_code text NOT NULL
);
CREATE INDEX idx_template_categories_template ON public.template_categories(template_id);
CREATE INDEX idx_template_categories_code ON public.template_categories(category_code);

-- ── Designs ─────────────────────────────────────────────────────────────────
CREATE TABLE public.designs (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id             uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title               text NOT NULL DEFAULT 'Untitled Design',
  slug                text,
  mode_code           text NOT NULL CHECK (mode_code IN ('3d_accessory','classic_clothing','minecraft_skin','texture_variant')),
  platform_code       text NOT NULL CHECK (platform_code IN ('roblox','minecraft','zepeto','fortnite','general_3d')),
  visibility_code     text NOT NULL DEFAULT 'private' CHECK (visibility_code IN ('private','public','unlisted')),
  status_code         text NOT NULL DEFAULT 'draft' CHECK (status_code IN ('draft','active','archived','deleted')),
  current_version_id  uuid,
  source_template_id  uuid REFERENCES public.templates(id),
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now(),
  deleted_at          timestamptz
);

CREATE INDEX idx_designs_user ON public.designs(user_id);
CREATE INDEX idx_designs_visibility ON public.designs(visibility_code);
CREATE INDEX idx_designs_status ON public.designs(status_code);

CREATE TRIGGER trg_designs_updated_at
  BEFORE UPDATE ON public.designs
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ── Design Versions ─────────────────────────────────────────────────────────
CREATE TABLE public.design_versions (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  design_id       uuid NOT NULL REFERENCES public.designs(id) ON DELETE CASCADE,
  version_number  integer NOT NULL DEFAULT 1,
  source_job_id   uuid,
  prompt_snapshot text,
  parameters      jsonb DEFAULT '{}',
  created_at      timestamptz NOT NULL DEFAULT now(),
  UNIQUE(design_id, version_number)
);

CREATE INDEX idx_design_versions_design ON public.design_versions(design_id);

-- Add FK from designs.current_version_id after design_versions exists
ALTER TABLE public.designs
  ADD CONSTRAINT fk_designs_current_version
  FOREIGN KEY (current_version_id)
  REFERENCES public.design_versions(id);

-- ── Layers ──────────────────────────────────────────────────────────────────
CREATE TABLE public.layers (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  design_version_id uuid NOT NULL REFERENCES public.design_versions(id) ON DELETE CASCADE,
  layer_type        text NOT NULL,
  name              text NOT NULL DEFAULT 'Layer',
  z_index           integer NOT NULL DEFAULT 0,
  is_visible        boolean NOT NULL DEFAULT true,
  opacity           numeric(3,2) NOT NULL DEFAULT 1.00,
  transform         jsonb DEFAULT '{}',
  payload           jsonb DEFAULT '{}',
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_layers_version ON public.layers(design_version_id);

CREATE TRIGGER trg_layers_updated_at
  BEFORE UPDATE ON public.layers
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ── Design Assets ───────────────────────────────────────────────────────────
CREATE TABLE public.design_assets (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  design_version_id uuid NOT NULL REFERENCES public.design_versions(id) ON DELETE CASCADE,
  asset_kind        text NOT NULL,
  storage_bucket    text NOT NULL,
  storage_path      text NOT NULL,
  mime_type         text,
  width             integer,
  height            integer,
  file_size         bigint,
  metadata          jsonb DEFAULT '{}',
  created_at        timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_design_assets_version ON public.design_assets(design_version_id);

-- ── Favorites ───────────────────────────────────────────────────────────────
CREATE TABLE public.favorites (
  user_id    uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  design_id  uuid NOT NULL REFERENCES public.designs(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, design_id)
);
