// Shared types for Edge Functions (Deno)
// Mirrors @creator/shared contracts but adapted for Deno runtime.

export const JOB_TYPES = ['image_generation', '3d_generation', 'image_to_3d', 'retexture', 'style_transfer'] as const;
export const PLATFORM_CODES = ['roblox', 'minecraft', 'zepeto', 'fortnite', 'general_3d'] as const;
export const MODE_CODES = ['3d_accessory', 'classic_clothing', 'minecraft_skin', 'texture_variant'] as const;
export const PROVIDER_CODES = ['replicate', 'meshy'] as const;
export const EXPORT_TARGETS = ['preview_in_roblox', 'upload_to_roblox', 'save_private', 'publish_public', 'download_package'] as const;
export const NOTIFICATION_TYPES = [
  'generation_queued', 'generation_processing', 'generation_completed', 'generation_failed',
  'export_ready', 'publish_completed', 'linked_account_required', 'insufficient_credits',
] as const;

export const QUEUE_MESSAGE_SCHEMA_VERSION = 1;

export const QUEUE_NAMES = {
  GENERATION_IMAGE: 'generation_image',
  GENERATION_3D: 'generation_3d',
  ASSET_POSTPROCESS: 'asset_postprocess',
  EXPORT_JOBS: 'export_jobs',
  NOTIFICATIONS: 'notifications',
} as const;

export const CREDIT_COSTS: Record<string, number> = {
  image_generation: 1,
  '3d_generation': 5,
  image_to_3d: 3,
  retexture: 2,
  style_transfer: 1,
};

/** Map job type to provider */
export function resolveProvider(jobType: string): 'replicate' | 'meshy' {
  if (jobType === '3d_generation' || jobType === 'image_to_3d' || jobType === 'retexture') return 'meshy';
  return 'replicate';
}

/** Map job type to queue name */
export function resolveQueue(jobType: string): string {
  if (jobType === '3d_generation' || jobType === 'image_to_3d' || jobType === 'retexture') return QUEUE_NAMES.GENERATION_3D;
  return QUEUE_NAMES.GENERATION_IMAGE;
}

/** Standard JSON error response */
export function errorResponse(status: number, code: string, message: string, details?: Record<string, unknown>): Response {
  return new Response(JSON.stringify({ error: { code, message, details } }), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

/** Standard JSON success response */
export function jsonResponse(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

// ═══════════════════════════════════════════════════════════════════════════════
// Billing Constants
// ═══════════════════════════════════════════════════════════════════════════════

export const PLAN_CODES = ['free', 'pro', 'studio'] as const;
export const BILLING_PRODUCT_TYPES = ['subscription', 'topup'] as const;
export const RESERVATION_STATES = ['reserved', 'committed', 'rolled_back', 'expired'] as const;
export const RESERVATION_TTL_SECONDS = 600; // 10 minutes

export const CREDIT_REASON_CODES = [
  // Existing
  'generation_image_charge', 'generation_3d_charge', 'export_charge',
  'monthly_refill', 'admin_adjustment', 'compensation_refund',
  'referral_bonus', 'signup_bonus',
  // Billing v2
  'subscription_initial_grant', 'subscription_renewal_grant',
  'topup_purchase', 'subscription_refund', 'topup_refund',
  'reservation_charge', 'reservation_rollback',
] as const;

// Re-export billing modules
export { grantBillingCredit } from './billing_grant.ts';
export type { GrantParams, GrantResult } from './billing_grant.ts';
export { billingLog, generateOpToken } from './billing_log.ts';
export type { BillingLogContext } from './billing_log.ts';
