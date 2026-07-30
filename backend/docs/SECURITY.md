# Security checklist (production)

## Fixed in codebase

| Issue | Fix |
|-------|-----|
| OAuth bypass via direct `linked_accounts` INSERT/UPDATE | Migration `018` — only edge functions can link |
| IAP stub granting free Pro | `verify-purchase` uses Google Play API; stub only if `ALLOW_IAP_STUB=true` |
| Roblox token encryption fallback to service role | Requires `LINKED_ACCOUNT_TOKEN_SECRET` (32+ chars) |
| Supabase debug logs in release | `debug: kDebugMode` only |
| Android backup exfiltration | `allowBackup="false"` |

## Required Supabase secrets (production)

```bash
supabase secrets set LINKED_ACCOUNT_TOKEN_SECRET=<32+ random chars>
supabase secrets set ROBLOX_OAUTH_CLIENT_ID=<from Roblox Creator Dashboard>
supabase secrets set GOOGLE_PLAY_SERVICE_ACCOUNT_JSON='{"client_email":"...","private_key":"..."}'
supabase secrets set GOOGLE_PLAY_PACKAGE_NAME=com.rblxclothingmaker.app
# Do NOT set ALLOW_IAP_STUB in production
```

## Open risks (admin panel — not in mobile AAB)

- `apps/admin_panel/src/app/templates/page.tsx` is a **client component** that may embed `NEXT_PUBLIC_SUPABASE_SERVICE_KEY` in the browser bundle.
- **Fix:** Move admin writes to Next.js Route Handlers / Server Actions; never prefix service role key with `NEXT_PUBLIC_`.

## Signing keys

- `key.properties` and `*.jks` are gitignored — never commit them.
- Rotate keystore passwords if they were shared or exposed.
