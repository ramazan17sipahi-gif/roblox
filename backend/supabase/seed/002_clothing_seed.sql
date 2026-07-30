-- ============================================================================
-- Seed 002: Clothing Templates + Sticker Categories + Stickers
-- Run AFTER migration 009_clothing_templates.sql
-- ============================================================================

-- ── Clothing Templates (3 required + 3 extra) ──────────────────────────
INSERT INTO public.clothing_templates (name, slug, template_type, description, is_active, is_pro, sort_order) VALUES
  ('Urban Black Shirt', 'urban-black-shirt', 'classic_shirt',
   'Sade siyah urban tarz gömlek şablonu. Roblox Shirt (585×559) UV layout.',
   true, false, 1),
  ('Urban Black Pants', 'urban-black-pants', 'classic_pants',
   'Sade siyah urban tarz pantolon şablonu. Roblox Pants (585×559) UV layout.',
   true, false, 2),
  ('King Logo Tee', 'king-logo-tee', 'classic_tshirt',
   'Minimalist taç logolu tişört. Roblox ShirtGraphic (128×128) front decal.',
   true, false, 3),
  ('Camo Military Pants', 'camo-military-pants', 'classic_pants',
   'Askeri kamuflaj deseni pantolon şablonu.',
   true, false, 4),
  ('Neon Glow Shirt', 'neon-glow-shirt', 'classic_shirt',
   'Neon renkli parlayan gömlek şablonu.',
   true, true, 5),
  ('Pixel Art Tee', 'pixel-art-tee', 'classic_tshirt',
   'Retro pixel art tişört şablonu.',
   true, false, 6);

-- ── Sticker Categories ──────────────────────────────────────────────────
INSERT INTO public.sticker_categories (name, slug, icon_name, sort_order, is_active) VALUES
  ('Logolar', 'logos', 'diamond', 1, true),
  ('Desenler', 'patterns', 'grid_view', 2, true),
  ('Yazılar', 'texts', 'title', 3, true),
  ('Emojiler', 'emojis', 'emoji_emotions', 4, true);

-- ── Stickers (Logos) ────────────────────────────────────────────────────
INSERT INTO public.stickers (category_id, name, image_url, is_active, is_pro, sort_order)
SELECT c.id, 'Crown Badge',
  'https://yhaqsfjiycyswjabxily.supabase.co/storage/v1/object/public/clothing-assets/stickers/crown-badge.png',
  true, false, 1
FROM public.sticker_categories c WHERE c.slug = 'logos';

INSERT INTO public.stickers (category_id, name, image_url, is_active, is_pro, sort_order)
SELECT c.id, 'Star Logo',
  'https://yhaqsfjiycyswjabxily.supabase.co/storage/v1/object/public/clothing-assets/stickers/star-logo.png',
  true, false, 2
FROM public.sticker_categories c WHERE c.slug = 'logos';

INSERT INTO public.stickers (category_id, name, image_url, is_active, is_pro, sort_order)
SELECT c.id, 'Fire Emblem',
  'https://yhaqsfjiycyswjabxily.supabase.co/storage/v1/object/public/clothing-assets/stickers/fire-emblem.png',
  true, false, 3
FROM public.sticker_categories c WHERE c.slug = 'logos';

-- ── Stickers (Patterns) ────────────────────────────────────────────────
INSERT INTO public.stickers (category_id, name, image_url, is_active, is_pro, sort_order)
SELECT c.id, 'Stripes',
  'https://yhaqsfjiycyswjabxily.supabase.co/storage/v1/object/public/clothing-assets/stickers/stripes.png',
  true, false, 1
FROM public.sticker_categories c WHERE c.slug = 'patterns';

INSERT INTO public.stickers (category_id, name, image_url, is_active, is_pro, sort_order)
SELECT c.id, 'Camo',
  'https://yhaqsfjiycyswjabxily.supabase.co/storage/v1/object/public/clothing-assets/stickers/camo.png',
  true, false, 2
FROM public.sticker_categories c WHERE c.slug = 'patterns';

INSERT INTO public.stickers (category_id, name, image_url, is_active, is_pro, sort_order)
SELECT c.id, 'Polka Dots',
  'https://yhaqsfjiycyswjabxily.supabase.co/storage/v1/object/public/clothing-assets/stickers/polka-dots.png',
  true, true, 3
FROM public.sticker_categories c WHERE c.slug = 'patterns';
