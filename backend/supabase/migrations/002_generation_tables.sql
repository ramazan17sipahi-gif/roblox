-- ============================================================================
-- Migration 002: Generation Jobs, Events, Outputs
-- ============================================================================

CREATE TABLE public.generation_jobs (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id           uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  design_id         uuid REFERENCES public.designs(id),
  design_version_id uuid REFERENCES public.design_versions(id),
  job_type          text NOT NULL CHECK (job_type IN ('image_generation','3d_generation','image_to_3d','retexture','style_transfer')),
  provider_code     text NOT NULL CHECK (provider_code IN ('replicate','meshy')),
  status_code       text NOT NULL DEFAULT 'queued' CHECK (status_code IN (
    'draft','queued','processing','waiting_external',
    'provider_preview_ready','provider_refining',
    'postprocessing','completed','failed','cancelled'
  )),
  input_prompt      text,
  input_params      jsonb DEFAULT '{}',
  input_asset_id    uuid REFERENCES public.design_assets(id),
  provider_job_id   text,
  idempotency_key   text UNIQUE NOT NULL,
  error_code        text,
  error_message     text,
  queued_at         timestamptz,
  started_at        timestamptz,
  completed_at      timestamptz,
  failed_at         timestamptz,
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_generation_jobs_user ON public.generation_jobs(user_id);
CREATE INDEX idx_generation_jobs_design ON public.generation_jobs(design_id);
CREATE INDEX idx_generation_jobs_status ON public.generation_jobs(status_code);
CREATE INDEX idx_generation_jobs_provider_job ON public.generation_jobs(provider_job_id);

CREATE TRIGGER trg_generation_jobs_updated_at
  BEFORE UPDATE ON public.generation_jobs
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- Add FK from design_versions.source_job_id
ALTER TABLE public.design_versions
  ADD CONSTRAINT fk_design_versions_source_job
  FOREIGN KEY (source_job_id)
  REFERENCES public.generation_jobs(id);

-- ── Generation Job Events ───────────────────────────────────────────────────
CREATE TABLE public.generation_job_events (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  job_id        uuid NOT NULL REFERENCES public.generation_jobs(id) ON DELETE CASCADE,
  event_type    text NOT NULL,
  event_payload jsonb DEFAULT '{}',
  created_at    timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_job_events_job ON public.generation_job_events(job_id);
CREATE INDEX idx_job_events_type ON public.generation_job_events(event_type);

-- ── Generation Outputs ──────────────────────────────────────────────────────
CREATE TABLE public.generation_outputs (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  job_id        uuid NOT NULL REFERENCES public.generation_jobs(id) ON DELETE CASCADE,
  output_kind   text NOT NULL,
  storage_bucket text NOT NULL,
  storage_path  text NOT NULL,
  preview_path  text,
  mime_type     text,
  metadata      jsonb DEFAULT '{}',
  created_at    timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_generation_outputs_job ON public.generation_outputs(job_id);
