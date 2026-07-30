# Roblox OAuth setup

## 1. Register OAuth app (Roblox Creator Dashboard)

1. Open [Roblox Creator Dashboard → Credentials](https://create.roblox.com/dashboard/credentials)
2. Create an OAuth 2.0 app (public client / mobile)
3. Add redirect URI:

```
com.rblxclothingmaker.app://roblox-oauth-callback
```

4. Copy the **Client ID**
5. Permissions (scopes): `openid`, `profile` (add `asset:read`, `asset:write` if needed)
6. OAuth **Entry / website** link: `https://hun.social`
7. Privacy / Terms: `https://hun.social/privacy`, `https://hun.social/terms`

## 2. Supabase secrets

```bash
supabase secrets set ROBLOX_OAUTH_CLIENT_ID=<your-client-id>
supabase secrets set ROBLOX_OAUTH_REDIRECT_URI=com.rblxclothingmaker.app://roblox-oauth-callback
supabase secrets set LINKED_ACCOUNT_TOKEN_SECRET=<random-32+-char-secret>
```

## 3. Deploy

```bash
supabase db push
supabase functions deploy auth-roblox-init
supabase functions deploy auth-roblox-finalize
supabase functions deploy link-platform-account-init
supabase functions deploy link-platform-account-finalize
```

## Flows

### A) Sign in / sign up with Roblox (no email)

1. App calls `auth-roblox-init` (no session) → authorization URL + state
2. User signs in on Roblox (deep link callback)
3. App calls `auth-roblox-finalize` with `code` + `state`
4. Server exchanges code, finds/creates Supabase user via `roblox_identities`, returns session tokens
5. App calls `setSession(refreshToken)` → home

Same Roblox account always maps to the same Supabase user. A `linked_accounts` row is created/updated automatically.

### B) Link Roblox while already signed in (email users)

1. App calls `link-platform-account-init` (requires session)
2. User authorizes on Roblox
3. App calls `link-platform-account-finalize`
4. Tokens stored encrypted on `linked_accounts`

Scopes: `openid profile`
