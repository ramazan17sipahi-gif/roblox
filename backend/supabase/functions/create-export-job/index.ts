import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.0';
import { errorResponse, jsonResponse, QUEUE_NAMES, QUEUE_MESSAGE_SCHEMA_VERSION } from '../_shared/mod.ts';

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
  const designVersionId = body.designVersionId as string;
  const exportTarget = body.exportTarget as string;
  const requestedFormat = (body.requestedFormat as string) ?? 'default';
  const requestedParams = (body.requestedParams ?? {}) as Record<string, unknown>;

  if (!designId || !designVersionId || !exportTarget) {
    return errorResponse(400, 'VALIDATION_ERROR', 'designId, designVersionId, exportTarget are required');
  }

  const validTargets = ['preview_in_roblox', 'upload_to_roblox', 'save_private', 'publish_public', 'download_package'];
  if (!validTargets.includes(exportTarget)) {
    return errorResponse(400, 'VALIDATION_ERROR', `Invalid exportTarget: ${exportTarget}`);
  }

  // Verify ownership
  const { data: design, error: designErr } = await svc
    .from('designs')
    .select('id, user_id')
    .eq('id', designId)
    .eq('user_id', user.id)
    .single();

  if (designErr || !design) return errorResponse(404, 'NOT_FOUND', 'Design not found');

  // Linked account check for platform exports
  if (exportTarget === 'upload_to_roblox' || exportTarget === 'preview_in_roblox') {
    const { data: linked } = await svc
      .from('linked_accounts')
      .select('id')
      .eq('user_id', user.id)
      .eq('platform_code', 'roblox')
      .eq('status_code', 'active')
      .maybeSingle();

    if (!linked) {
      return errorResponse(422, 'LINKED_ACCOUNT_REQUIRED', 'Active Roblox account link required for this export target');
    }
  }

  // Create export record
  const { data: exportRecord, error: exportErr } = await svc
    .from('exports')
    .insert({
      user_id: user.id,
      design_id: designId,
      design_version_id: designVersionId,
      export_target: exportTarget,
      status_code: 'pending',
      requested_format: requestedFormat,
      requested_params: requestedParams,
    })
    .select('id')
    .single();

  if (exportErr || !exportRecord) return errorResponse(500, 'INTERNAL_ERROR', 'Failed to create export');

  // Enqueue
  const correlationId = crypto.randomUUID();
  await svc.rpc('pgmq_send', {
    queue_name: QUEUE_NAMES.EXPORT_JOBS,
    message: {
      schemaVersion: QUEUE_MESSAGE_SCHEMA_VERSION,
      correlationId,
      idempotencyKey: `export_${exportRecord.id}`,
      jobId: exportRecord.id,
      userId: user.id,
      attemptNumber: 1,
      createdAt: new Date().toISOString(),
      payload: { designId, designVersionId, exportTarget, requestedFormat, requestedParams },
    },
  });

  // Ping worker
  const drainUrl = Deno.env.get('CLOUD_RUN_EXPORT_DRAIN_URL');
  const workerSecret = Deno.env.get('INTERNAL_WORKER_SHARED_SECRET');
  if (drainUrl && workerSecret) {
    try {
      await fetch(drainUrl, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'X-Worker-Secret': workerSecret },
        body: JSON.stringify({ trigger: 'new_export', correlationId }),
      });
    } catch { /* non-fatal */ }
  }

  return jsonResponse({ exportId: exportRecord.id, status: 'pending' });
});
