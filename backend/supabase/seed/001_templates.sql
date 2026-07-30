-- ============================================================================
-- Seed Data: Initial templates, signup credits
-- ============================================================================

-- Grant signup credits to existing users (idempotent via key pattern)
-- In production, this would be handled by the auth trigger
-- Here we provide sample template data for the creator platform

INSERT INTO public.templates (platform_code, template_type, title, slug, description, is_public) VALUES
  ('roblox', '3d_accessory', 'Sci-Fi Helmet', 'sci-fi-helmet', 'Futuristic armored helmet with visor', true),
  ('roblox', '3d_accessory', 'Dragon Wings', 'dragon-wings', 'Detailed dragon wing back accessory', true),
  ('roblox', '3d_accessory', 'Crystal Crown', 'crystal-crown', 'Elegant crystalline crown headwear', true),
  ('roblox', '3d_accessory', 'Shoulder Spikes', 'shoulder-spikes', 'Intimidating spiked shoulder pads', true),
  ('roblox', '3d_accessory', 'Neon Backpack', 'neon-backpack', 'Glowing cyberpunk-style backpack', true),
  ('roblox', 'classic_clothing', 'Streetwear Hoodie', 'streetwear-hoodie', 'Urban style hoodie template', true),
  ('roblox', 'classic_clothing', 'Fantasy Armor', 'fantasy-armor', 'Medieval-style armor clothing', true),
  ('minecraft', 'minecraft_skin', 'Pixel Knight', 'pixel-knight', 'Classic knight skin for Minecraft', true),
  ('minecraft', 'minecraft_skin', 'Cyber Warrior', 'cyber-warrior', 'Futuristic warrior Minecraft skin', true),
  ('general_3d', 'texture_variant', 'Galaxy Texture', 'galaxy-texture', 'Nebula-inspired texture pattern', true);

-- Add categories to templates
INSERT INTO public.template_categories (template_id, category_code)
SELECT t.id, 'helmet' FROM public.templates t WHERE t.slug = 'sci-fi-helmet'
UNION ALL
SELECT t.id, 'wings' FROM public.templates t WHERE t.slug = 'dragon-wings'
UNION ALL
SELECT t.id, 'crown' FROM public.templates t WHERE t.slug = 'crystal-crown'
UNION ALL
SELECT t.id, 'shoulder' FROM public.templates t WHERE t.slug = 'shoulder-spikes'
UNION ALL
SELECT t.id, 'backpack' FROM public.templates t WHERE t.slug = 'neon-backpack'
UNION ALL
SELECT t.id, 'clothing' FROM public.templates t WHERE t.slug = 'streetwear-hoodie'
UNION ALL
SELECT t.id, 'armor' FROM public.templates t WHERE t.slug = 'fantasy-armor'
UNION ALL
SELECT t.id, 'skin' FROM public.templates t WHERE t.slug = 'pixel-knight'
UNION ALL
SELECT t.id, 'skin' FROM public.templates t WHERE t.slug = 'cyber-warrior'
UNION ALL
SELECT t.id, 'texture' FROM public.templates t WHERE t.slug = 'galaxy-texture';
