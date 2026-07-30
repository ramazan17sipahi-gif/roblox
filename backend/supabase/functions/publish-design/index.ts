import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.0';
import { errorResponse, jsonResponse } from '../_shared/mod.ts';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

Deno.serve(async (req: Request) => {
  const authHeader = req.headers.get('Authorization');
  if (!authHeader) return errorResponse(401, 'UNAUTHORIZED', 'Missing authorization header');

  const supabaseUser = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
    global: { headers: { Authorization: authHeader } },
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { data: { user }, error: authError } = await supabaseUser.auth.getUser();
  if (authError || !user) return errorResponse(401, 'UNAUTHORIZED', 'Invalid token');

  const svc = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  let body: Record<string, unknown>;
  try { body = await req.json(); } catch { return errorResponse(400, 'INVALID_BODY', 'Invalid JSON'); }

  const designId = body.designId as string;
  const visibility = (body.visibility as string) ?? 'public';
  const title = body.title as string | undefined;
  const description = body.description as string | undefined;

  if (!designId) return errorResponse(400, 'VALIDATION_ERROR', 'designId is required');
  if (!['public', 'unlisted'].includes(visibility)) {
    return errorResponse(400, 'VALIDATION_ERROR', 'visibility must be public or unlisted');
  }

  // Verify ownership and readiness
  const { data: design, error: designErr } = await svc
    .from('designs')
    .select('id, user_id, status_code, current_version_id')
    .eq('id', designId)
    .eq('user_id', user.id)
    .single();

  if (designErr || !design) return errorResponse(404, 'NOT_FOUND', 'Design not found');

  // Cannot publish without a version
  if (!design.current_version_id) {
    return errorResponse(422, 'BUSINESS_RULE', 'Cannot publish design without a completed version');
  }

  // Must not be deleted
  if (design.status_code === 'deleted') {
    return errorResponse(422, 'BUSINESS_RULE', 'Cannot publish a deleted design');
  }

  // Update design
  const updates: Record<string, unknown> = {
    visibility_code: visibility,
    status_code: 'active',
  };
  if (title) updates.title = title;

  const { error: updateErr } = await svc.from('designs').update(updates).eq('id', designId);
  if (updateErr) return errorResponse(500, 'INTERNAL_ERROR', 'Failed to update design');

  // Usage event
  await svc.from('usage_events').insert({
    user_id: user.id,
    event_type: 'design_published',
    subject_type: 'design',
    subject_id: designId,
    metadata: { visibility },
  });

  // Notification
  await svc.from('notification_records').insert({
    user_id: user.id,
    notification_type: 'publish_completed',
    title: 'Design Published!',
    body: `Your design "${title ?? 'Untitled'}" is now ${visibility}.`,
    payload: { designId, visibility },
  });

  return jsonResponse({ designId, status: 'active', visibility });
});
