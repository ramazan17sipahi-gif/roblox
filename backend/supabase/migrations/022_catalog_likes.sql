-- Catalog likes (clothing_templates) + library worn-preview URLs.
-- Idempotent: safe to paste into the Supabase SQL editor.

ALTER TABLE public.clothing_templates
  ADD COLUMN IF NOT EXISTS likes_count integer NOT NULL DEFAULT 0;

CREATE TABLE IF NOT EXISTS public.template_likes (
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  template_id uuid NOT NULL REFERENCES public.clothing_templates(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, template_id)
);

ALTER TABLE public.template_likes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS template_likes_select ON public.template_likes;
CREATE POLICY template_likes_select ON public.template_likes
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS template_likes_insert ON public.template_likes;
CREATE POLICY template_likes_insert ON public.template_likes
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS template_likes_delete ON public.template_likes;
CREATE POLICY template_likes_delete ON public.template_likes
  FOR DELETE USING (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_template_likes_user
  ON public.template_likes (user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_clothing_templates_likes
  ON public.clothing_templates (likes_count DESC);

CREATE OR REPLACE FUNCTION public.update_template_likes_count()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE public.clothing_templates
      SET likes_count = likes_count + 1
      WHERE id = NEW.template_id;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE public.clothing_templates
      SET likes_count = GREATEST(likes_count - 1, 0)
      WHERE id = OLD.template_id;
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS tr_template_likes_count ON public.template_likes;
CREATE TRIGGER tr_template_likes_count
  AFTER INSERT OR DELETE ON public.template_likes
  FOR EACH ROW EXECUTE FUNCTION public.update_template_likes_count();

-- Library cards can reuse catalog shirt/pants URLs (same as Home).
ALTER TABLE public.user_projects
  ADD COLUMN IF NOT EXISTS shirt_texture_url text;

ALTER TABLE public.user_projects
  ADD COLUMN IF NOT EXISTS pants_texture_url text;
