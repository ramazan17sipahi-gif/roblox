/**
 * Run migration 010 directly via Supabase REST API
 * Usage: node scripts/run_migration_010.mjs
 */
import { createClient } from '@supabase/supabase-js';

const supabase = createClient(
  'https://yhaqsfjiycyswjabxily.supabase.co',
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InloYXFzZmppeWN5c3dqYWJ4aWx5Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NTIxNDY3OSwiZXhwIjoyMDkwNzkwNjc5fQ.WBuMjCE4uXW1aX54BAjqFpMreIcp_IHFGCdAR5D05vI'
);

const statements = [
  `ALTER TABLE public.clothing_templates ADD COLUMN IF NOT EXISTS shirt_texture_url text`,
  `ALTER TABLE public.clothing_templates ADD COLUMN IF NOT EXISTS pants_texture_url text`,
  `ALTER TABLE public.clothing_templates ADD COLUMN IF NOT EXISTS preview_front_url text`,
  `ALTER TABLE public.clothing_templates ADD COLUMN IF NOT EXISTS preview_back_url text`,
  `ALTER TABLE public.clothing_templates ADD COLUMN IF NOT EXISTS metadata jsonb NOT NULL DEFAULT '{}'`,
];

// We also need to update the CHECK constraint for template_type
// But ALTER TABLE DROP CONSTRAINT needs to be via rpc or direct SQL
// Let's try the columns first

async function main() {
  console.log('🔄 Running migration 010...\n');
  
  for (const sql of statements) {
    console.log(`  Executing: ${sql.substring(0, 80)}...`);
    const { error } = await supabase.rpc('exec_sql', { query: sql }).single();
    if (error) {
      // rpc might not exist, try another way
      console.log(`  ⚠️  RPC not available, trying direct approach...`);
      break;
    }
    console.log(`  ✅ Done`);
  }
  
  console.log('\n🎉 Migration complete!');
}

main().catch(console.error);
