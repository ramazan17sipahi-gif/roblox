-- ============================================================================
-- Migration 010: Clothing Templates Upgrade
-- Add shirt/pants texture URLs, preview URLs, classic_set type, metadata
-- ============================================================================

-- ── New columns for separate texture files ──
ALTER TABLE public.clothing_templates
  ADD COLUMN IF NOT EXISTS shirt_texture_url text,
  ADD COLUMN IF NOT EXISTS pants_texture_url text,
  ADD COLUMN IF NOT EXISTS preview_front_url text,
  ADD COLUMN IF NOT EXISTS preview_back_url  text,
  ADD COLUMN IF NOT EXISTS metadata          jsonb NOT NULL DEFAULT '{}';

-- ── Expand template_type to include classic_set ──
-- Drop the old CHECK and add the new one
ALTER TABLE public.clothing_templates
  DROP CONSTRAINT IF EXISTS clothing_templates_template_type_check;

ALTER TABLE public.clothing_templates
  ADD CONSTRAINT clothing_templates_template_type_check
    CHECK (template_type IN ('classic_shirt', 'classic_pants', 'classic_tshirt', 'classic_set'));

-- ── Indexes for new columns ──
CREATE INDEX IF NOT EXISTS idx_clothing_templates_shirt ON public.clothing_templates(shirt_texture_url)
  WHERE shirt_texture_url IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_clothing_templates_pants ON public.clothing_templates(pants_texture_url)
  WHERE pants_texture_url IS NOT NULL;

-- ── Validation constraints ──
-- classic_set requires BOTH shirt and pants
-- classic_shirt requires shirt
-- classic_pants requires pants
ALTER TABLE public.clothing_templates
  ADD CONSTRAINT chk_set_requires_both
    CHECK (
      template_type != 'classic_set'
      OR (shirt_texture_url IS NOT NULL AND pants_texture_url IS NOT NULL)
    );

ALTER TABLE public.clothing_templates
  ADD CONSTRAINT chk_shirt_requires_texture
    CHECK (
      template_type != 'classic_shirt'
      OR shirt_texture_url IS NOT NULL
    );

ALTER TABLE public.clothing_templates
  ADD CONSTRAINT chk_pants_requires_texture
    CHECK (
      template_type != 'classic_pants'
      OR pants_texture_url IS NOT NULL
    );
