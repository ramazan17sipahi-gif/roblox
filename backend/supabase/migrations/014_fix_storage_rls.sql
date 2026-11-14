-- ============================================================================
-- Migration 014: Fix storage RLS folder index (foldername[1] = user id)
-- Migration 007 incorrectly used [2] for single-level paths like userId/file.png
-- ============================================================================

-- Profile avatars
DROP POLICY IF EXISTS "avatar_upload" ON storage.objects;
CREATE POLICY "avatar_upload" ON storage.objects FOR INSERT
  WITH CHECK (bucket_id = 'profile-avatars' AND auth.uid()::text = (storage.foldername(name))[1]);

-- Reference images
DROP POLICY IF EXISTS "ref_upload" ON storage.objects;
CREATE POLICY "ref_upload" ON storage.objects FOR INSERT
  WITH CHECK (bucket_id = 'reference-images' AND auth.uid()::text = (storage.foldername(name))[1]);

DROP POLICY IF EXISTS "ref_read" ON storage.objects;
CREATE POLICY "ref_read" ON storage.objects FOR SELECT
  USING (bucket_id = 'reference-images' AND auth.uid()::text = (storage.foldername(name))[1]);

-- User uploads
DROP POLICY IF EXISTS "uploads_insert" ON storage.objects;
CREATE POLICY "uploads_insert" ON storage.objects FOR INSERT
  WITH CHECK (bucket_id = 'user-uploads' AND auth.uid()::text = (storage.foldername(name))[1]);

DROP POLICY IF EXISTS "uploads_read" ON storage.objects;
CREATE POLICY "uploads_read" ON storage.objects FOR SELECT
  USING (bucket_id = 'user-uploads' AND auth.uid()::text = (storage.foldername(name))[1]);

-- Generated images
DROP POLICY IF EXISTS "gen_img_read" ON storage.objects;
CREATE POLICY "gen_img_read" ON storage.objects FOR SELECT
  USING (bucket_id = 'generated-images' AND auth.uid()::text = (storage.foldername(name))[1]);

-- Generated models
DROP POLICY IF EXISTS "gen_model_read" ON storage.objects;
CREATE POLICY "gen_model_read" ON storage.objects FOR SELECT
  USING (bucket_id = 'generated-models' AND auth.uid()::text = (storage.foldername(name))[1]);

-- Export packages
DROP POLICY IF EXISTS "export_read" ON storage.objects;
CREATE POLICY "export_read" ON storage.objects FOR SELECT
  USING (bucket_id = 'export-packages' AND auth.uid()::text = (storage.foldername(name))[1]);
