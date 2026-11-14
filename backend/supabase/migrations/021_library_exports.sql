-- Library drafts / exports.
-- Remote DBs that never ran 004/012 will not have user_projects yet.
-- This file is idempotent: safe to paste into the Supabase SQL editor.

CREATE TABLE IF NOT EXISTS public.user_projects (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  template_type TEXT NOT NULL DEFAULT 'shirt',
  thumbnail_url TEXT,
  version INTEGER DEFAULT 1,
  visibility text NOT NULL DEFAULT 'draft'
    CHECK (visibility IN ('private', 'public', 'draft')),
  exported_at timestamptz,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.user_projects
  ADD COLUMN IF NOT EXISTS visibility text NOT NULL DEFAULT 'draft';

ALTER TABLE public.user_projects
  ADD COLUMN IF NOT EXISTS exported_at timestamptz;

ALTER TABLE public.user_projects ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "user_projects_all" ON public.user_projects;
CREATE POLICY "user_projects_all" ON public.user_projects
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS user_projects_select_public ON public.user_projects;
CREATE POLICY user_projects_select_public ON public.user_projects
  FOR SELECT USING (visibility = 'public' OR auth.uid() = user_id);

CREATE TABLE IF NOT EXISTS public.project_revisions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  project_id UUID NOT NULL REFERENCES public.user_projects(id) ON DELETE CASCADE,
  version INTEGER NOT NULL,
  thumbnail_url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.project_revisions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "project_revisions_select" ON public.project_revisions;
CREATE POLICY "project_revisions_select" ON public.project_revisions
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.user_projects WHERE id = project_id AND user_id = auth.uid())
  );

DROP POLICY IF EXISTS "project_revisions_insert" ON public.project_revisions;
CREATE POLICY "project_revisions_insert" ON public.project_revisions
  FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM public.user_projects WHERE id = project_id AND user_id = auth.uid())
  );

INSERT INTO storage.buckets (id, name, public)
VALUES ('projects', 'projects', false)
ON CONFLICT DO NOTHING;

DROP POLICY IF EXISTS "projects_storage_all" ON storage.objects;
CREATE POLICY "projects_storage_all" ON storage.objects
  FOR ALL USING (
    bucket_id = 'projects' AND auth.uid()::text = (storage.foldername(name))[1]
  );

CREATE INDEX IF NOT EXISTS idx_user_projects_user
  ON public.user_projects(user_id);

CREATE INDEX IF NOT EXISTS idx_user_projects_user_visibility
  ON public.user_projects (user_id, visibility);

CREATE INDEX IF NOT EXISTS idx_user_projects_visibility
  ON public.user_projects(visibility)
  WHERE visibility = 'public';

CREATE INDEX IF NOT EXISTS idx_user_projects_exported_at
  ON public.user_projects (user_id, exported_at DESC)
  WHERE exported_at IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_project_revisions_project
  ON public.project_revisions(project_id);

COMMENT ON COLUMN public.user_projects.visibility IS
  'private = personal library, public = published, draft = work-in-progress auto-save';
