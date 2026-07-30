-- ============================================================================
-- Migration 013: Community bookmarks + public project discovery
-- ============================================================================

-- Bookmarks / saved designs
CREATE TABLE IF NOT EXISTS public.saved_designs (
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  design_id UUID NOT NULL REFERENCES public.published_designs(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, design_id)
);

ALTER TABLE public.saved_designs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS saved_designs_select ON public.saved_designs;
CREATE POLICY saved_designs_select ON public.saved_designs
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS saved_designs_insert ON public.saved_designs;
CREATE POLICY saved_designs_insert ON public.saved_designs
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS saved_designs_delete ON public.saved_designs;
CREATE POLICY saved_designs_delete ON public.saved_designs
  FOR DELETE USING (auth.uid() = user_id);

-- Optional link back to editor project
ALTER TABLE public.published_designs
  ADD COLUMN IF NOT EXISTS source_project_id UUID REFERENCES public.user_projects(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_published_designs_source
  ON public.published_designs(source_project_id);

CREATE INDEX IF NOT EXISTS idx_saved_designs_user
  ON public.saved_designs(user_id);

-- Public projects visible in community queries (metadata only)
DROP POLICY IF EXISTS user_projects_select_public ON public.user_projects;
CREATE POLICY user_projects_select_public ON public.user_projects
  FOR SELECT USING (visibility = 'public' OR auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_user_projects_visibility
  ON public.user_projects(visibility)
  WHERE visibility = 'public';
