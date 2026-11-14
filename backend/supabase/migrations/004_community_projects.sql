-- ═══════════════════════════════════════════════════════════════
-- Community & Projects Migration
-- Adds: published_designs, design_likes, design_comments,
--        user_projects, project_revisions tables
-- ═══════════════════════════════════════════════════════════════

-- Published designs for community discover
CREATE TABLE IF NOT EXISTS public.published_designs (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT DEFAULT '',
  category TEXT NOT NULL DEFAULT 'shirt',
  thumbnail_url TEXT,
  design_data JSONB DEFAULT '{}',
  likes_count INTEGER DEFAULT 0,
  comments_count INTEGER DEFAULT 0,
  views_count INTEGER DEFAULT 0,
  is_featured BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.published_designs ENABLE ROW LEVEL SECURITY;

-- Everyone can view published designs
CREATE POLICY "published_designs_select" ON public.published_designs
  FOR SELECT USING (true);

-- Only owner can insert/update/delete
CREATE POLICY "published_designs_insert" ON public.published_designs
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "published_designs_update" ON public.published_designs
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "published_designs_delete" ON public.published_designs
  FOR DELETE USING (auth.uid() = user_id);

-- Design likes
CREATE TABLE IF NOT EXISTS public.design_likes (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  design_id UUID NOT NULL REFERENCES public.published_designs(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, design_id)
);

ALTER TABLE public.design_likes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "design_likes_select" ON public.design_likes
  FOR SELECT USING (true);

CREATE POLICY "design_likes_insert" ON public.design_likes
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "design_likes_delete" ON public.design_likes
  FOR DELETE USING (auth.uid() = user_id);

-- Auto-update likes_count on insert/delete
CREATE OR REPLACE FUNCTION public.update_likes_count()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE public.published_designs SET likes_count = likes_count + 1 WHERE id = NEW.design_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE public.published_designs SET likes_count = GREATEST(likes_count - 1, 0) WHERE id = OLD.design_id;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER tr_likes_count
  AFTER INSERT OR DELETE ON public.design_likes
  FOR EACH ROW EXECUTE FUNCTION public.update_likes_count();

-- Design comments
CREATE TABLE IF NOT EXISTS public.design_comments (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  design_id UUID NOT NULL REFERENCES public.published_designs(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.design_comments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "design_comments_select" ON public.design_comments
  FOR SELECT USING (true);

CREATE POLICY "design_comments_insert" ON public.design_comments
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "design_comments_delete" ON public.design_comments
  FOR DELETE USING (auth.uid() = user_id);

-- Auto-update comments_count
CREATE OR REPLACE FUNCTION public.update_comments_count()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE public.published_designs SET comments_count = comments_count + 1 WHERE id = NEW.design_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE public.published_designs SET comments_count = GREATEST(comments_count - 1, 0) WHERE id = OLD.design_id;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER tr_comments_count
  AFTER INSERT OR DELETE ON public.design_comments
  FOR EACH ROW EXECUTE FUNCTION public.update_comments_count();

-- User projects (auto-save)
CREATE TABLE IF NOT EXISTS public.user_projects (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  template_type TEXT NOT NULL DEFAULT 'shirt',
  thumbnail_url TEXT,
  version INTEGER DEFAULT 1,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.user_projects ENABLE ROW LEVEL SECURITY;

CREATE POLICY "user_projects_all" ON public.user_projects
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Project revision history
CREATE TABLE IF NOT EXISTS public.project_revisions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  project_id UUID NOT NULL REFERENCES public.user_projects(id) ON DELETE CASCADE,
  version INTEGER NOT NULL,
  thumbnail_url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.project_revisions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "project_revisions_select" ON public.project_revisions
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.user_projects WHERE id = project_id AND user_id = auth.uid())
  );

CREATE POLICY "project_revisions_insert" ON public.project_revisions
  FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM public.user_projects WHERE id = project_id AND user_id = auth.uid())
  );

-- Storage bucket for projects
INSERT INTO storage.buckets (id, name, public)
VALUES ('projects', 'projects', false)
ON CONFLICT DO NOTHING;

-- Storage policy for projects bucket
CREATE POLICY "projects_storage_all" ON storage.objects
  FOR ALL USING (
    bucket_id = 'projects' AND auth.uid()::text = (storage.foldername(name))[1]
  );

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_published_designs_category ON public.published_designs(category);
CREATE INDEX IF NOT EXISTS idx_published_designs_likes ON public.published_designs(likes_count DESC);
CREATE INDEX IF NOT EXISTS idx_published_designs_created ON public.published_designs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_design_likes_design ON public.design_likes(design_id);
CREATE INDEX IF NOT EXISTS idx_design_comments_design ON public.design_comments(design_id);
CREATE INDEX IF NOT EXISTS idx_user_projects_user ON public.user_projects(user_id);
CREATE INDEX IF NOT EXISTS idx_project_revisions_project ON public.project_revisions(project_id);

-- Profiles view for community (username + avatar)
CREATE OR REPLACE VIEW public.profiles AS
SELECT 
  id,
  raw_user_meta_data->>'username' AS username,
  raw_user_meta_data->>'avatar_url' AS avatar_url
FROM auth.users;
