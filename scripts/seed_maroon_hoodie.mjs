/**
 * Seed script: Import Maroon Hoodie Set template into Supabase
 * Usage: node scripts/seed_maroon_hoodie.mjs
 */
import { createClient } from '@supabase/supabase-js';
import { readFileSync } from 'fs';
import { resolve } from 'path';

const supabase = createClient(
  'https://yhaqsfjiycyswjabxily.supabase.co',
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InloYXFzZmppeWN5c3dqYWJ4aWx5Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NTIxNDY3OSwiZXhwIjoyMDkwNzkwNjc5fQ.WBuMjCE4uXW1aX54BAjqFpMreIcp_IHFGCdAR5D05vI'
);

const TEMPLATE_DIR = resolve('template/template-1');

async function uploadFile(localPath, storagePath) {
  const buffer = readFileSync(localPath);
  const { data, error } = await supabase.storage
    .from('clothing-assets')
    .upload(storagePath, buffer, { upsert: true, contentType: 'image/png' });
  if (error) { console.error(`❌ Upload failed:`, error.message); return null; }
  const { data: urlData } = supabase.storage.from('clothing-assets').getPublicUrl(data.path);
  console.log(`✅ Uploaded: ${storagePath}`);
  return urlData.publicUrl;
}

async function main() {
  console.log('🚀 Seeding Maroon Hoodie Set...\n');
  const shirtUrl = await uploadFile(resolve(TEMPLATE_DIR, 'Shirt.png'), 'templates/maroon-hoodie-set/Shirt.png');
  const pantsUrl = await uploadFile(resolve(TEMPLATE_DIR, 'Pants.png'), 'templates/maroon-hoodie-set/Pants.png');
  if (!shirtUrl || !pantsUrl) { console.error('❌ Upload failed'); process.exit(1); }

  const { data, error } = await supabase
    .from('clothing_templates')
    .upsert({
      name: 'Maroon Hoodie Set',
      slug: 'maroon-hoodie-set',
      template_type: 'classic_set',
      description: 'Stylish maroon hoodie with teal pants combination',
      sort_order: 2,
      is_active: true,
      is_pro: false,
      shirt_texture_url: shirtUrl,
      pants_texture_url: pantsUrl,
    }, { onConflict: 'slug' })
    .select().single();

  if (error) { console.error('❌ DB error:', error.message); process.exit(1); }
  console.log(`\n✅ ${data.name} created (${data.id})\n🎉 Done!`);
}

main().catch(console.error);
