/**
 * Seed script: Import King Urban Set template into Supabase
 * 
 * Usage:
 *   cd C:\Users\User\Desktop\roblox
 *   node scripts/seed_king_urban.mjs
 * 
 * Requires: SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY env vars or hardcoded below.
 */

import { createClient } from '@supabase/supabase-js';
import { readFileSync } from 'fs';
import { resolve } from 'path';

const SUPABASE_URL = process.env.SUPABASE_URL || 'https://yhaqsfjiycyswjabxily.supabase.co';
const SUPABASE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InloYXFzZmppeWN5c3dqYWJ4aWx5Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NTIxNDY3OSwiZXhwIjoyMDkwNzkwNjc5fQ.WBuMjCE4uXW1aX54BAjqFpMreIcp_IHFGCdAR5D05vI';

const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);

const TEMPLATE_DIR = resolve('template/template-2');
const TEMPLATE = {
  name: 'King Urban Set',
  slug: 'king-urban-set',
  template_type: 'classic_set',
  description: 'Premium urban streetwear set with detailed textures',
  sort_order: 1,
  is_active: true,
  is_pro: false,
};

async function uploadFile(localPath, storagePath) {
  const buffer = readFileSync(localPath);
  const { data, error } = await supabase.storage
    .from('clothing-assets')
    .upload(storagePath, buffer, { upsert: true, contentType: 'image/png' });

  if (error) {
    console.error(`❌ Upload failed (${storagePath}):`, error.message);
    return null;
  }

  const { data: urlData } = supabase.storage.from('clothing-assets').getPublicUrl(data.path);
  console.log(`✅ Uploaded: ${storagePath} → ${urlData.publicUrl}`);
  return urlData.publicUrl;
}

async function main() {
  console.log('🚀 Seeding King Urban Set...\n');

  // 1. Upload textures
  const shirtUrl = await uploadFile(
    resolve(TEMPLATE_DIR, 'Shirt.png'),
    `templates/${TEMPLATE.slug}/Shirt.png`
  );
  const pantsUrl = await uploadFile(
    resolve(TEMPLATE_DIR, 'Pants.png'),
    `templates/${TEMPLATE.slug}/Pants.png`
  );

  if (!shirtUrl || !pantsUrl) {
    console.error('\n❌ Upload failed, aborting DB insert.');
    process.exit(1);
  }

  // 2. Upsert into clothing_templates
  const { data, error } = await supabase
    .from('clothing_templates')
    .upsert({
      ...TEMPLATE,
      shirt_texture_url: shirtUrl,
      pants_texture_url: pantsUrl,
    }, { onConflict: 'slug' })
    .select()
    .single();

  if (error) {
    console.error('\n❌ DB insert failed:', error.message);
    process.exit(1);
  }

  console.log(`\n✅ Template created: ${data.name} (${data.id})`);
  console.log(`   Shirt: ${data.shirt_texture_url}`);
  console.log(`   Pants: ${data.pants_texture_url}`);
  console.log('\n🎉 Done!');
}

main().catch(console.error);
