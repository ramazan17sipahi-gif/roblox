-- ============================================================================
-- Migration 012: Remove deprecated AI generation pipeline + project visibility
-- ============================================================================

-- Drop FK from design_versions → generation_jobs
ALTER TABLE public.design_versions
  DROP CONSTRAINT IF EXISTS fk_design_versions_source_job;

-- Drop generation pipeline tables (no longer used by the app)
DROP TABLE IF EXISTS public.generation_outputs CASCADE;
DROP TABLE IF EXISTS public.generation_job_events CASCADE;
DROP TABLE IF EXISTS public.generation_jobs CASCADE;

-- Drop AI worker queues (keep export_jobs + notifications for billing/export)
SELECT pgmq.drop_queue('generation_image');
SELECT pgmq.drop_queue('generation_3d');
SELECT pgmq.drop_queue('asset_postprocess');

-- Project library visibility for Profile tabs (Library / Public / Drafts)
ALTER TABLE public.user_projects
  ADD COLUMN IF NOT EXISTS visibility text NOT NULL DEFAULT 'private'
  CHECK (visibility IN ('private', 'public', 'draft'));

CREATE INDEX IF NOT EXISTS idx_user_projects_user_visibility
  ON public.user_projects (user_id, visibility);

COMMENT ON COLUMN public.user_projects.visibility IS
  'private = personal library, public = published, draft = work-in-progress auto-save';
