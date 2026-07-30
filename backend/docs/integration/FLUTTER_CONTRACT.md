# Flutter Integration Contract

## Overview

This document defines the contract between the Flutter frontend and the backend services.
The Flutter app communicates with the backend exclusively through:

1. **Supabase Auth** — login, session management
2. **Supabase Edge Functions** — orchestration RPCs
3. **Supabase Realtime** — live job status updates
4. **Supabase Storage** — asset download/upload
5. **Supabase Tables** — direct reads for designs, profiles, notifications

## Edge Function Endpoints

### `create_generation_job`
**Request:**
```json
{
  "prompt": "A cyberpunk helmet with neon visor",
  "jobType": "image_generation",
  "platformCode": "roblox",
  "modeCode": "3d_accessory",
  "idempotencyKey": "uuid-v4",
  "inputParams": {},
  "designId": null,
  "inputAssetId": null
}
```

**Response (200):**
```json
{
  "jobId": "uuid",
  "status": "queued",
  "designId": "uuid",
  "designVersionId": "uuid",
  "creditsCharged": 1
}
```

**Errors:** 402 (insufficient credits), 401 (unauthorized), 400 (validation)

---

### `retry_generation_job`
**Request:** `{ "jobId": "uuid" }`
**Response:** `{ "jobId": "uuid", "status": "queued", "message": "..." }`

---

### `create_export_job`
**Request:**
```json
{
  "designId": "uuid",
  "designVersionId": "uuid",
  "exportTarget": "download_package",
  "requestedFormat": "default",
  "requestedParams": {}
}
```
**Response:** `{ "exportId": "uuid", "status": "pending" }`

---

### `publish_design`
**Request:**
```json
{
  "designId": "uuid",
  "visibility": "public",
  "title": "My Design",
  "description": "..."
}
```
**Response:** `{ "designId": "uuid", "status": "active", "visibility": "public" }`

---

### `link_platform_account_init`
**Request:** `{ "platformCode": "roblox" }`
**Response:** `{ "linkedAccountId": "uuid", "status": "pending", "nextStep": "authorization" }`

---

### `link_platform_account_finalize`
**Request:** `{ "platformCode": "roblox", "authorizationCode": "..." }`
**Response:** `{ "linkedAccountId": "uuid", "status": "active", "displayName": "..." }`

## Realtime Subscriptions

### Job Status (recommended)
```dart
supabase
  .from('generation_jobs')
  .stream(primaryKey: ['id'])
  .eq('user_id', currentUserId)
  .order('created_at', ascending: false)
  .listen((data) => { /* update UI */ });
```

### Notifications
```dart
supabase
  .from('notification_records')
  .stream(primaryKey: ['id'])
  .eq('user_id', currentUserId)
  .order('created_at', ascending: false)
  .listen((data) => { /* show notification */ });
```

## Tables Accessible via Client (RLS-protected)

| Table | Operations | Notes |
|---|---|---|
| profiles | SELECT, UPDATE | Own profile |
| designs | SELECT, INSERT, UPDATE, DELETE | Own + public |
| design_versions | SELECT, INSERT | Via design ownership |
| layers | CRUD | Via design ownership |
| design_assets | SELECT | Via design ownership |
| favorites | SELECT, INSERT, DELETE | Own |
| generation_jobs | SELECT | Own only (stream) |
| generation_job_events | SELECT | Via job ownership |
| generation_outputs | SELECT | Via job ownership |
| credits_ledger | SELECT | Own only |
| subscriptions | SELECT | Own only |
| entitlements | SELECT | Own only |
| exports | SELECT | Own only |
| export_files | SELECT | Via export ownership |
| linked_accounts_safe | SELECT | View (no tokens) |
| notification_records | SELECT, UPDATE | Own (mark read) |
| templates | SELECT | Public only |

## RPC Functions (Client-Callable)

| Function | Purpose |
|---|---|
| `get_credits_balance(user_id)` | Get current credit balance |

## Credits Integration

The Flutter app should:
1. Call `get_credits_balance` to show current balance
2. Check response for 402 on `create_generation_job` → show paywall
3. Credits auto-refill on RevenueCat subscription events

## Changes Required in Flutter

### Existing `GenerationRepository`
The existing `createGenerationJob` method needs to be updated to pass the new contract:
- Add `jobType`, `platformCode`, `modeCode`, `idempotencyKey` parameters
- Handle 402 (insufficient credits) as specific error type

### Existing `GenerationJobModel`
Extend to include new fields from the schema:
- `design_id`, `design_version_id`
- `provider_code`
- `error_code`, `error_message`

### New: `DesignRepository`
For CRUD on designs table via direct Supabase client.

### New: `ExportRepository`
For creating exports via Edge Function and listing from table.

### New: `LinkedAccountRepository`
For platform linking flow via Edge Functions.

### New: `NotificationRepository`
For streaming notifications and marking read.

### New: `CreditsRepository`
For balance queries and ledger reads.
