-- ============================================================================
-- Migration 005: Queue Setup — pgmq initialization
-- ============================================================================

-- Enable pgmq extension (must be enabled on Supabase dashboard or CLI first)
CREATE EXTENSION IF NOT EXISTS pgmq;

-- Create named queues
SELECT pgmq.create('generation_image');
SELECT pgmq.create('generation_3d');
SELECT pgmq.create('asset_postprocess');
SELECT pgmq.create('export_jobs');
SELECT pgmq.create('notifications');

-- ── Wrapper RPCs for Edge Function / Worker access ──────────────────────────
-- These wrap pgmq functions so they're accessible via supabase.rpc()

CREATE OR REPLACE FUNCTION public.pgmq_send(queue_name text, message jsonb)
RETURNS bigint
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT pgmq.send(queue_name, message);
$$;

CREATE OR REPLACE FUNCTION public.pgmq_read(queue_name text, vt integer, qty integer)
RETURNS TABLE(msg_id bigint, read_ct integer, enqueued_at timestamptz, vt timestamptz, message jsonb)
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT msg_id, read_ct, enqueued_at, vt, message FROM pgmq.read(queue_name, vt, qty);
$$;

CREATE OR REPLACE FUNCTION public.pgmq_archive(queue_name text, msg_id bigint)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT pgmq.archive(queue_name, msg_id);
$$;

CREATE OR REPLACE FUNCTION public.pgmq_delete(queue_name text, msg_id bigint)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT pgmq.delete(queue_name, msg_id);
$$;
