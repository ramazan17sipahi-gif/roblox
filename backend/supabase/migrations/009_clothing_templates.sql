-- ============================================================================
-- Migration 009: Clothing Templates, Sticker Categories, Stickers
-- Admin-managed content for the Classic Clothing Editor
-- ============================================================================

-- ── Clothing Templates ──────────────────────────────────────────────────
-- Admin tarafından yönetilen kıyafet şablonları.
-- Mobile app sadece is_active=true olanları görür.
-- template_type: Roblox Classic Clothing mantığına uygun.
CREATE TABLE public.clothing_templates (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name            text NOT NULL,
  slug            text UNIQUE NOT NULL,
  template_type   text NOT NULL CHECK (template_type IN ('classic_shirt','classic_pants','classic_tshirt')),
  description     text,
  cover_image_url text,
  uv_overlay_url  text,
  is_active       boolean NOT NULL DEFAULT true,
  is_pro          boolean NOT NULL DEFAULT false,
  sort_order      int NOT NULL DEFAULT 0,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_clothing_templates_type ON public.clothing_templates(template_type);
CREATE INDEX idx_clothing_templates_active ON public.clothing_templates(is_active);
CREATE INDEX idx_clothing_templates_sort ON public.clothing_templates(sort_order);

CREATE TRIGGER trg_clothing_templates_updated_at
  BEFORE UPDATE ON public.clothing_templates
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ── Sticker Categories ──────────────────────────────────────────────────
CREATE TABLE public.sticker_categories (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name       text NOT NULL,
  slug       text UNIQUE NOT NULL,
  icon_name  text,
  sort_order int NOT NULL DEFAULT 0,
  is_active  boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_sticker_categories_active ON public.sticker_categories(is_active);
CREATE INDEX idx_sticker_categories_sort ON public.sticker_categories(sort_order);

-- ── Stickers ────────────────────────────────────────────────────────────
CREATE TABLE public.stickers (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  category_id uuid NOT NULL REFERENCES public.sticker_categories(id) ON DELETE CASCADE,
  name        text NOT NULL,
  image_url   text NOT NULL,
  is_active   boolean NOT NULL DEFAULT true,
  is_pro      boolean NOT NULL DEFAULT false,
  sort_order  int NOT NULL DEFAULT 0,
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_stickers_category ON public.stickers(category_id);
CREATE INDEX idx_stickers_active ON public.stickers(is_active);
CREATE INDEX idx_stickers_sort ON public.stickers(sort_order);

-- ═══════════════════════════════════════════════════════════════════════════
-- RLS POLICIES
-- Read: anon + authenticated can read active records
-- Write: service_role only (admin panel)
-- ═══════════════════════════════════════════════════════════════════════════

ALTER TABLE public.clothing_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sticker_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stickers ENABLE ROW LEVEL SECURITY;

-- clothing_templates: public read active
CREATE POLICY clothing_templates_select_active
  ON public.clothing_templates FOR SELECT
  USING (is_active = true);

-- sticker_categories: public read active
CREATE POLICY sticker_categories_select_active
  ON public.sticker_categories FOR SELECT
  USING (is_active = true);

-- stickers: public read active
CREATE POLICY stickers_select_active
  ON public.stickers FOR SELECT
  USING (is_active = true);

-- Write policies omitted intentionally:
-- Admin panel uses service_role key which bypasses RLS.
-- No client-side writes allowed on these tables.

-- ═══════════════════════════════════════════════════════════════════════════
-- Storage bucket for clothing assets (covers, stickers, overlays)
-- ═══════════════════════════════════════════════════════════════════════════
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'clothing-assets',
  'clothing-assets',
  true,
  5242880, -- 5MB per file
  ARRAY['image/png','image/jpeg','image/webp','image/svg+xml']
) ON CONFLICT (id) DO NOTHING;

-- Public read on clothing-assets bucket
CREATE POLICY clothing_assets_public_read
  ON storage.objects FOR SELECT
  USING (bucket_id = 'clothing-assets');

-- Service-role only write (admin panel uploads)
-- No insert/update/delete policy = only service_role can write
