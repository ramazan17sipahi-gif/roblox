# Backend Deployment Guide

## Architecture Overview

```
Flutter App → Supabase (Auth/DB/Storage/Realtime) → Edge Functions → Cloud Run Workers
                                                  → Provider Webhooks (Replicate/Meshy)
                                                  → RevenueCat Webhook
```

## Prerequisites

- Node.js 20+
- pnpm 9.15+
- Docker (for worker builds)
- Supabase CLI (`npx supabase`)
- Google Cloud SDK (`gcloud`)

## Local Development

### 1. Install Dependencies

```bash
pnpm install
```

### 2. Start Supabase Locally

```bash
cd backend/supabase
npx supabase start
npx supabase db reset  # runs migrations + seed
```

### 3. Run Workers Locally

```bash
# Set env vars (see .env.example)
cd backend/workers/replicate-image-worker
pnpm dev
```

### 4. Deploy Edge Functions Locally

```bash
cd backend/supabase
npx supabase functions serve --env-file .env.local
```

## Production Deployment

### Supabase

1. **Database Migrations**
   ```bash
   cd backend/supabase
   npx supabase db push
   ```

2. **Edge Functions**
   ```bash
   npx supabase functions deploy create-generation-job
   npx supabase functions deploy retry-generation-job
   npx supabase functions deploy create-export-job
   npx supabase functions deploy publish-design
   npx supabase functions deploy replicate-webhook
   npx supabase functions deploy meshy-webhook
   npx supabase functions deploy link-platform-account-init
   npx supabase functions deploy link-platform-account-finalize
   npx supabase functions deploy revenuecat-webhook
   ```

3. **Set Edge Function Secrets**
   ```bash
   npx supabase secrets set INTERNAL_WORKER_SHARED_SECRET=<value>
   npx supabase secrets set REPLICATE_WEBHOOK_SECRET=<value>
   npx supabase secrets set MESHY_WEBHOOK_SECRET=<value>
   npx supabase secrets set REVENUECAT_WEBHOOK_SECRET=<value>
   npx supabase secrets set CLOUD_RUN_REPLICATE_DRAIN_URL=<url>
   npx supabase secrets set CLOUD_RUN_MESHY_DRAIN_URL=<url>
   npx supabase secrets set CLOUD_RUN_POSTPROCESS_DRAIN_URL=<url>
   npx supabase secrets set CLOUD_RUN_EXPORT_DRAIN_URL=<url>
   ```

4. **Enable pgmq Extension**
   - Go to Supabase Dashboard → Database → Extensions → Enable `pgmq`

### Cloud Run Workers

Build and deploy each worker:

```bash
# From repo root
PROJECT_ID=your-gcp-project
REGION=europe-west1

# Build shared first
pnpm --filter @creator/shared build

# Replicate Image Worker
gcloud builds submit --tag gcr.io/$PROJECT_ID/replicate-image-worker \
  -f backend/workers/replicate-image-worker/Dockerfile .
gcloud run deploy replicate-image-worker \
  --image gcr.io/$PROJECT_ID/replicate-image-worker \
  --region $REGION \
  --no-allow-unauthenticated \
  --set-env-vars SUPABASE_URL=<url>,SUPABASE_SERVICE_ROLE_KEY=<key>,INTERNAL_WORKER_SHARED_SECRET=<secret>,REPLICATE_API_TOKEN=<token>

# Repeat for other workers...
```

### Cloud Scheduler (Fallback Drain)

Set up periodic triggers for each worker:

```bash
gcloud scheduler jobs create http drain-replicate \
  --location=$REGION \
  --schedule="*/5 * * * *" \
  --uri="https://replicate-image-worker-xxxxx.run.app/drain" \
  --http-method=POST \
  --headers="X-Worker-Secret=<secret>,Content-Type=application/json" \
  --body='{"trigger":"scheduler"}'
```

## Environment Variables Reference

### Edge Functions
| Variable | Required | Description |
|---|---|---|
| SUPABASE_URL | Auto | Project URL |
| SUPABASE_SERVICE_ROLE_KEY | Auto | Service role key |
| INTERNAL_WORKER_SHARED_SECRET | Yes | Shared auth secret for worker pings |
| REPLICATE_WEBHOOK_SECRET | Recommended | Webhook verification |
| MESHY_WEBHOOK_SECRET | Recommended | Webhook verification |
| REVENUECAT_WEBHOOK_SECRET | Yes | RevenueCat webhook auth |
| CLOUD_RUN_*_DRAIN_URL | Recommended | Worker drain endpoints |

### Cloud Run Workers
| Variable | Required | Default | Description |
|---|---|---|---|
| SUPABASE_URL | Yes | - | Supabase project URL |
| SUPABASE_SERVICE_ROLE_KEY | Yes | - | Service role key |
| INTERNAL_WORKER_SHARED_SECRET | Yes | - | Auth for /drain endpoint |
| REPLICATE_API_TOKEN | replicate-worker | - | Replicate API token |
| MESHY_API_KEY | meshy-worker | - | Meshy API key |
| LOG_LEVEL | No | info | pino log level |
| WORKER_BATCH_SIZE | No | 5 | Messages per drain |
| WORKER_MAX_ATTEMPTS | No | 3 | Max retry attempts |
| PORT | No | 8080 | HTTP server port |

## Queue Flow

```
1. Flutter → Edge Function (create-generation-job)
2. Edge Function → validates → charges credits → creates DB records → enqueues to pgmq
3. Edge Function → pings Cloud Run worker /drain (non-blocking)
4. Worker reads batch from pgmq → calls Replicate/Meshy → stores provider_job_id
5. Provider sends webhook → Edge Function (replicate-webhook / meshy-webhook)
6. Webhook handler → updates job status → enqueues to asset_postprocess queue
7. Postprocess worker → downloads outputs → uploads to Storage → creates records → marks complete
8. Flutter receives realtime update via Supabase table changes
```

## Health Checks

Each worker exposes `GET /health` returning `{"status":"ok","service":"<name>"}`.

## Monitoring

All workers use pino structured logging with:
- correlationId
- jobId
- userId
- service name
- automatic secret redaction
