-- ============================================================================
-- Migration 007: Storage Buckets
-- ============================================================================

-- profile-avatars: Public bucket for user profile images
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('profile-avatars', 'profile-avatars', true, 5242880, ARRAY['image/jpeg','image/png','image/webp']);

-- reference-images: Private, user reference uploads for generation
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('reference-images', 'reference-images', false, 10485760, ARRAY['image/jpeg','image/png','image/webp']);

-- user-uploads: Private, general user uploads
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('user-uploads', 'user-uploads', false, 52428800, NULL);

-- generated-images: Private, AI-generated 2D outputs
INSERT INTO storage.buckets (id, name, public, file_size_limit)
VALUES ('generated-images', 'generated-images', false, 52428800);

-- generated-models: Private, AI-generated 3D model files
INSERT INTO storage.buckets (id, name, public, file_size_limit)
VALUES ('generated-models', 'generated-models', false, 104857600);

-- preview-renders: Public for sharing, preview thumbnails/renders
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('preview-renders', 'preview-renders', true, 10485760, ARRAY['image/jpeg','image/png','image/webp']);

-- export-packages: Private, downloadable export bundles
INSERT INTO storage.buckets (id, name, public, file_size_limit)
VALUES ('export-packages', 'export-packages', false, 209715200);

-- temporary-processing: Private, worker scratch space (auto-cleanup)
INSERT INTO storage.buckets (id, name, public, file_size_limit)
VALUES ('temporary-processing', 'temporary-processing', false, 209715200);

-- ═══════════════════════════════════════════════════════════════════════════
-- Storage RLS Policies
-- ═══════════════════════════════════════════════════════════════════════════

-- Profile avatars: own upload, public read
CREATE POLICY "avatar_upload" ON storage.objects FOR INSERT
  WITH CHECK (bucket_id = 'profile-avatars' AND auth.uid()::text = (storage.foldername(name))[2]);
CREATE POLICY "avatar_read" ON storage.objects FOR SELECT
  USING (bucket_id = 'profile-avatars');

-- Reference images: own only
CREATE POLICY "ref_upload" ON storage.objects FOR INSERT
  WITH CHECK (bucket_id = 'reference-images' AND auth.uid()::text = (storage.foldername(name))[2]);
CREATE POLICY "ref_read" ON storage.objects FOR SELECT
  USING (bucket_id = 'reference-images' AND auth.uid()::text = (storage.foldername(name))[2]);

-- User uploads: own only
CREATE POLICY "uploads_insert" ON storage.objects FOR INSERT
  WITH CHECK (bucket_id = 'user-uploads' AND auth.uid()::text = (storage.foldername(name))[2]);
CREATE POLICY "uploads_read" ON storage.objects FOR SELECT
  USING (bucket_id = 'user-uploads' AND auth.uid()::text = (storage.foldername(name))[2]);

-- Generated images: read own (written by service role)
CREATE POLICY "gen_img_read" ON storage.objects FOR SELECT
  USING (bucket_id = 'generated-images' AND auth.uid()::text = (storage.foldername(name))[2]);

-- Generated models: read own
CREATE POLICY "gen_model_read" ON storage.objects FOR SELECT
  USING (bucket_id = 'generated-models' AND auth.uid()::text = (storage.foldername(name))[2]);

-- Preview renders: public read
CREATE POLICY "preview_read" ON storage.objects FOR SELECT
  USING (bucket_id = 'preview-renders');

-- Export packages: read own
CREATE POLICY "export_read" ON storage.objects FOR SELECT
  USING (bucket_id = 'export-packages' AND auth.uid()::text = (storage.foldername(name))[2]);
