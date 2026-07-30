# Creator Platform Architecture Blueprint

> **Updated scope (2026):** Mobile-first **Roblox classic clothing** creator.  
> AI accessory generation and Cloud Run workers are **removed** (migration `012_cleanup_ai_pipeline.sql`).

## Current stack

```
Flutter App
  → Supabase Auth / Postgres / Storage
  → Edge Functions (publish, export, billing)
  → Native IAP (App Store / Google Play)
```

## 1. Realistic System Diagram

```mermaid
graph TD
    %% Client Tier
    subgraph Mobile Client "Flutter Mobile App"
        A_UI[UI Presentation Layer]
        A_App[Application Layer / Riverpod]
        A_Dom[Domain Layer / Use Cases]
        A_Data[Data Layer / Repositories]
        
        A_Viewer[3D Viewer Adapter]
        A_Bridge[Bridge Interface]
    end

    %% Network / Gateway
    subgraph Gateway "API Gateway / Edge"
        SF_Edge[Supabase Edge Functions]
    end

    %% Backend Tier Primary
    subgraph Backend Primary "Supabase Ecosystem"
        S_Auth[Supabase Auth]
        S_DB[(PostgreSQL + RLS)]
        S_Storage[Supabase Storage]
        S_Realtime[Realtime Subscriptions]
        S_Queue[pgmq / Queues]
    end

    %% Backend Tier Workers
    subgraph Worker Services "Cloud Run Environment"
        W_IMG[AI Image Worker]
        W_3D[AI 3D Worker]
        W_Post[Asset Postprocess Worker]
        W_Prev[Preview Render Worker]
    end

    %% External Third Parties
    subgraph External Providers "Third-Party APIs"
        P_IMG[OpenAI/Gemini API]
        P_3D[Meshy/Tripo API]
        P_RC[RevenueCat]
        P_RL[Roblox/Minecraft (Publishing)]
    end

    %% Connections
    A_Data -->|REST / GraphQL / RPC| S_DB
    A_Data -->|Upload/Download| S_Storage
    A_App -->|Listen for Job Updates| S_Realtime
    A_Data -->SF_Edge
    A_Data -->S_Auth

    SF_Edge -->|Enqueue Jobs| S_Queue
    SF_Edge -->|Validate| S_DB
    
    S_Queue -->|Fetch Jobs| W_IMG
    S_Queue -->|Fetch Jobs| W_3D
    S_Queue -->|Fetch Jobs| W_Post
    S_Queue -->|Fetch Jobs| W_Prev
    
    W_IMG -->|Generate| P_IMG
    W_IMG -->|Write Output| S_DB
    W_IMG -->|Save Images| S_Storage
    
    W_3D -->|Generate| P_3D
    W_3D -->|Write Output| S_DB
    W_3D -->|Save Models| S_Storage
    
    P_RC -->|Webhook Entitlements| SF_Edge
    
    A_App -->|Verify Entitlements| P_RC
    W_Post -->|Publish| P_RL
```

## 2. Frontend-Backend Boundary Decisions

- **Supabase as Source of Truth**: All state, entitlements, user data, and job tracking reside in Postgres. The client relies on Realtime subscriptions to react to changes rather than long-polling.
- **Client-Side Responsibilities**: The Flutter client is purely for UI routing, local 2D layer editing, 3D preview visualization, and initiating requests. It contains no complex generation logic or heavy asset manipulation algorithms.
- **Edge Functions vs. Workers**: 
  - **Edge Functions**: Used *only* for synchronous, lightweight orchestration (validating credits, logging requests, inserting to DB, queueing jobs). Maximum execution target < 1s.
  - **Workers (Cloud Run)**: Used for heavy processing (polling 3D generation providers, converting mesh formats, generating thumbnails, image AI generation). Execution time bounded by Cloud Run limits (up to 60 minutes if necessary).
- **Security & RLS**: Clients connect directly to Postgres via Supabase SDK but only interact with data they own or public data, strictly controlled by Row Level Security (RLS). No service keys in the app.

## 3. 3D Strategy Decision Record

- **Viewer over Editor (v1)**: Flutter does not support an enterprise-grade native 3D authoring environment. For v1, we use `flutter_3d_controller` (or `model_viewer_plus`) strictly for **preview and texture swapping**.
- **Texture Swapping**: The 2D layer editor (in Flutter) compiles textures into a single 2D image map. This image map is applied (swapped) onto the UV coordinates of a loaded GLB/glTF model in the viewer.
- **Adapter Layer**: The 3D view is abstracted behind a `ViewerAdapter` and `BridgeInterface`. If we later migrate to a WebView embedding Three.js/Babylon.js for complex mesh manipulation, the domain logic remains untouched.
- **Format Standardization**: All models handled by the client must be pre-processed into `.glb` format by the backend workers to ensure predictable rendering across iOS and Android.

## 4. Provider Abstraction Decision Record

We will implement an adapter pattern for all external services to prevent tight coupling.

**`ImageGenerationProvider`**
- Adapters: `OpenAiImageProvider`, `GeminiImageProvider`
- Methods: `generateImage(prompt, options)`, `editImage(image, mask, options)`
- Abstracted response format mapping provider specifics to a unified `ImageGenerationResult`.

**`ThreeDGenerationProvider`**
- Adapters: `MeshyThreeDProvider`, `TripoThreeDProvider`
- Methods: `textTo3D(prompt)`, `imageTo3D(imageUrl)`, `pollJobStatus(jobId)`
- Deals with varying webhook behaviors and formatting from external 3D vendors.

**`PlatformPublisher`**
- Adapters: `RobloxClassicPublisher`, `MinecraftSkinPublisher`
- Methods: `getPublishingRequirements()`, `publishAsset(asset, credentials)`

**`MonetizationProvider`**
- Adapter: `RevenueCatAdapter`
- Methods: `checkEntitlements()`, `purchasePackage()`

## 5. Full Monorepo Tree

```text
/
├── apps
│   └── mobile_app                // The actual Flutter app entry point
│       ├── android
│       ├── ios
│       ├── lib
│       │   └── main.dart
│       └── pubspec.yaml
├── packages                      // Shared Dart packages
│   ├── app_core                  // Core abstractions, logging, base DTOs
│   ├── design_system             // UI components, themes, tokens
│   ├── networking                // Supabase clients, intercepted HTTP clients
│   ├── models                    // Freezed domain models & JSON serialization
│   ├── viewer_bridge             // 3D Viewer adapter & abstractions
│   └── utils                     // Formatters, validators, extensions
├── backend
│   ├── supabase
│   │   ├── migrations            // SQL schema definitions
│   │   ├── seed                  // Mock data
│   │   └── functions             // Edge Functions (create_job, webhooks)
│   ├── workers                   // Cloud Run services (Node.js/Go/Python)
│   │   ├── ai_image_worker
│   │   ├── ai_3d_worker
│   │   ├── asset_postprocess_worker
│   │   └── preview_render_worker
│   └── shared
│       ├── contracts             // JSON Schemas, TypeScript types mapping to Dart models
│       ├── queue                 // pgmq helpers
│       └── providers             // Backend adapters for Meshy/Tripo/OpenAI
├── docs                          // Architecture and API docs
│   ├── architecture
│   ├── api
│   ├── db
│   └── flows
└── tools
    ├── scripts                   // Build runners, environment sync
    └── ci                        // GitHub Actions / CI definitions
```

## 6. Flutter Feature / Module Tree

Inside `apps/mobile_app/lib/`:

```text
lib/
├── bootstrap/               // ProviderObserver, Initialization logic
├── app/                     // AppWidget, setup wrapper
├── config/                  // Env variables, feature flags
├── routing/                 // GoRouter configuration and route definitions
├── shared/                  // App-specific shared logic (not in design_system)
└── features/                // Feature-driven modules
    ├── auth/
    ├── onboarding/
    ├── home/
    ├── create/
    ├── editor/
    │   ├── presentation/
    │   │   ├── pages/       // EditorShell, GenerationStatus
    │   │   ├── widgets/     // LayerPanel, TextTool, 3DPreviewPanel
    │   │   └── controllers/ // EditorStateController
    │   ├── application/     // Coordinate layer logic and viewer bridge
    │   ├── domain/          // Layer entity, Coordinate math
    │   └── data/            // Design saving/loading repository
    ├── explore/
    ├── library/
    ├── profile/
    ├── settings/
    ├── subscriptions/
    ├── notifications/
    ├── linked_accounts/
    ├── export_publish/
    └── generation_jobs/     // Realtime subscriptions & state for queue UI
```

## 7. Supabase Migration & Schema Plan

**Core Tables:**
- `users_profiles` (id references auth.users, username, bio, avatar_url)
- `subscriptions` (user_id, status, plan_id, revenuecat_rc_id)
- `credits_ledger` (id, user_id, amount, source, reason, idempotency_key)
- `credits_balance_view` (SQL View summing ledger per user)
- `designs` (id, user_id, template_id, title, visibility [private/public], created_at)
- `layers` (id, design_id, type [image, text, color, ai], properties_json, z_index)
- `design_assets` (id, design_id, asset_url, type [texture, 3d_model])
- `generation_jobs` (id, user_id, type [image, 3d, retexture], status, provider, configuration_json, created_at)
- `generation_outputs` (id, job_id, asset_url, metadata_json)
- `linked_accounts` (id, user_id, platform [roblox, zepeto], access_token_enc, refresh_token_enc, status)

**RLS Policy Rules:**
- Read `users_profiles`: Publicly accessible.
- Update `users_profiles`: Only owner (`auth.uid() = id`).
- Select/Insert/Update/Delete `designs`: Only owner, UNLESS visibility is 'public', then Select is allowed for all.
- Select `generation_jobs`: Only owner.
- Insert `credits_ledger`: STRICTLY Service Role only.

## 8. Worker Service Plan

- **AI Image Worker**: Listens to `generation_image` queue. Calls OpenAI/Gemini with the prompt, downloads the resulting image, optimizes it via sharp/imagemagick, uploads to `generated-images` bucket, and marks the job complete.
- **AI 3D Worker**: Listens to `generation_3d` queue. Dispatches job to Meshy. Maintains an internal state machine (often driven by incoming webhooks updating the DB). Once Meshy webhooks report success, this worker downloads the `.glb`, uploads to `generated-models`, and enqueues an `asset_postprocess` task.
- **Asset Postprocess Worker**: Converts `.obj` to `.glb` if needed, normalizes normals, extracts a default UV map preview image, generates a thumbnail using headless Three.js/puppeteer, and saves metadata into DB.

## 9. Storage Bucket Plan

All buckets hosted on Supabase Storage.

| Bucket Name | Accessibility | Purpose | Cleanup Strategy |
| --- | --- | --- | --- |
| `profile-avatars` | Public | User profile images. | Retained |
| `reference-images` | Private (Owner) | User-uploaded images for img2img generation or layer use. | Retained |
| `generated-images` | Private (Owner)* | Raw outputs from AI. *Public if design is published. | Delete if abandoned > 30 days |
| `generated-models` | Private (Owner)* | `.glb` outputs from 3D AI. | Delete if abandoned > 30 days |
| `export-packages` | Private (Owner) | `.zip` files generated for user download (e.g., Roblox clothing wrapper). | 24-hour TTL (Temp files) |
| `preview-renders` | Public | Thumbnails of published or discoverable designs. | Retained |

## 10. Naming Conventions

- **Database**: `snake_case` for all tables and columns. Plural for tables (`designs`, `layers`).
- **Dart/Flutter**: `snake_case` for files and folders. `PascalCase` for classes. `camelCase` for variables and methods.
- **Environment Variables**: `UPPER_SNAKE_CASE`. Prefix Flutter variables with `APP_` or config structures. Prefix worker variables with `WORKER_`.
- **API/Endpoints**: Kebab-case URL paths `/api/v1/create-job`.

## 11. Environment Variable Plan

```bash
# Flutter (.env)
APP_SUPABASE_URL=...
APP_SUPABASE_ANON_KEY=...
APP_REVENUECAT_PUBLIC_KEY=...
APP_ENVIRONMENT=development

# Edge Functions (.env)
SUPABASE_URL=...
SUPABASE_SERVICE_ROLE_KEY=... # Absolute necessity for secure admin tasks

# Workers (.env)
SUPABASE_URL=...
SUPABASE_SERVICE_ROLE_KEY=...
PROVIDER_MESHY_API_KEY=...
PROVIDER_OPENAI_API_KEY=...
```

## 12. Risks and Mitigation

> [!WARNING]
> **Risk**: 3D Generation times out or fails silently due to provider instability.
> **Mitigation**: Implement robust pgmq dead-letter queues, exponential backoff, and 3D provider fallback logic (e.g., swap to Tripo if Meshy is down).

> [!WARNING]
> **Risk**: Users abuse free credits using disposable emails.
> **Mitigation**: Require device-level attestation/fingerprinting. Implement rigorous RevenueCat checks and tie credits to validated App Store/Google Play account IDs where possible. 

> [!CAUTION]
> **Risk**: Exposing sensitive tokens (e.g., Roblox OAuth) to the client.
> **Mitigation**: The `linked_accounts` table masks API tokens using Supabase Column Encryption or Vault. They are ONLY decrypted by Edge Functions during publish operations.

## Next Steps / User Review Required
Please review the architecture blueprint. Specifically:
- **Provider choices**: Are you aligned with using Meshy/Tripo for 3D and OpenAI/Gemini for 2D?
- **3D Strategy**: Does the viewer + texture map swapping strategy for v1 meet your expectations?
- **Cloud Run vs Edge**: Do you approve the use of Cloud Run for the long-running worker processes?

Once approved, we will proceed to **PHASE 2 — Flutter frontend foundation**.
