const ROBLOX_AUTHORIZE_URL = 'https://apis.roblox.com/oauth/v1/authorize';
const ROBLOX_TOKEN_URL = 'https://apis.roblox.com/oauth/v1/token';
const ROBLOX_USERINFO_URL = 'https://apis.roblox.com/oauth/v1/userinfo';
const ROBLOX_REVOKE_URL = 'https://apis.roblox.com/oauth/v1/token/revoke';
const DEFAULT_REDIRECT_URI = 'com.rblxclothingmaker.app://roblox-oauth-callback';
const DEFAULT_SCOPES = 'openid profile';

export interface RobloxPkcePair {
  codeVerifier: string;
  codeChallenge: string;
}

export interface RobloxTokenResponse {
  access_token: string;
  refresh_token?: string;
  expires_in?: number;
  token_type?: string;
  scope?: string;
  id_token?: string;
}

export interface RobloxUserInfo {
  sub: string;
  name?: string;
  nickname?: string;
  preferred_username?: string;
  profile?: string;
  picture?: string;
}

function base64UrlEncode(bytes: Uint8Array): string {
  let binary = '';
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

export async function generatePkcePair(): Promise<RobloxPkcePair> {
  const verifierBytes = crypto.getRandomValues(new Uint8Array(32));
  const codeVerifier = base64UrlEncode(verifierBytes);
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(codeVerifier));
  const codeChallenge = base64UrlEncode(new Uint8Array(digest));
  return { codeVerifier, codeChallenge };
}

export function getRobloxRedirectUri(override?: string): string {
  return override || Deno.env.get('ROBLOX_OAUTH_REDIRECT_URI') || DEFAULT_REDIRECT_URI;
}

export function getRobloxClientId(): string {
  const clientId = Deno.env.get('ROBLOX_OAUTH_CLIENT_ID');
  if (!clientId) throw new Error('ROBLOX_OAUTH_CLIENT_ID is not configured');
  return clientId;
}

export function buildRobloxAuthorizationUrl(params: {
  state: string;
  codeChallenge: string;
  redirectUri: string;
  scopes?: string;
}): string {
  const clientId = getRobloxClientId();
  const url = new URL(ROBLOX_AUTHORIZE_URL);
  url.searchParams.set('client_id', clientId);
  url.searchParams.set('redirect_uri', params.redirectUri);
  url.searchParams.set('scope', params.scopes ?? DEFAULT_SCOPES);
  url.searchParams.set('response_type', 'code');
  url.searchParams.set('state', params.state);
  url.searchParams.set('code_challenge', params.codeChallenge);
  url.searchParams.set('code_challenge_method', 'S256');
  return url.toString();
}

export async function exchangeRobloxAuthorizationCode(params: {
  code: string;
  redirectUri: string;
  codeVerifier: string;
}): Promise<RobloxTokenResponse> {
  const body = new URLSearchParams({
    grant_type: 'authorization_code',
    code: params.code,
    client_id: getRobloxClientId(),
    redirect_uri: params.redirectUri,
    code_verifier: params.codeVerifier,
  });

  const response = await fetch(ROBLOX_TOKEN_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body,
  });

  const payload = await response.json().catch(() => ({}));
  if (!response.ok) {
    const message = typeof payload?.error_description === 'string'
      ? payload.error_description
      : typeof payload?.error === 'string'
        ? payload.error
        : 'Token exchange failed';
    throw new Error(message);
  }

  return payload as RobloxTokenResponse;
}

export async function fetchRobloxUserInfo(accessToken: string): Promise<RobloxUserInfo> {
  const response = await fetch(ROBLOX_USERINFO_URL, {
    headers: { Authorization: `Bearer ${accessToken}` },
  });

  const payload = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new Error('Failed to fetch Roblox user profile');
  }

  return payload as RobloxUserInfo;
}

export async function revokeRobloxToken(token: string): Promise<void> {
  const body = new URLSearchParams({
    token,
    client_id: getRobloxClientId(),
  });

  await fetch(ROBLOX_REVOKE_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body,
  }).catch(() => undefined);
}

async function getEncryptionKey(): Promise<CryptoKey> {
  const secret = Deno.env.get('LINKED_ACCOUNT_TOKEN_SECRET');
  if (!secret || secret.length < 32) {
    throw new Error('LINKED_ACCOUNT_TOKEN_SECRET must be set (min 32 chars)');
  }

  const raw = new TextEncoder().encode(secret.slice(0, 32));
  return crypto.subtle.importKey('raw', raw, { name: 'AES-GCM' }, false, ['encrypt', 'decrypt']);
}

export async function encryptSecret(plaintext: string): Promise<string> {
  const key = await getEncryptionKey();
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const ciphertext = await crypto.subtle.encrypt(
    { name: 'AES-GCM', iv },
    key,
    new TextEncoder().encode(plaintext),
  );
  const combined = new Uint8Array(iv.length + new Uint8Array(ciphertext).length);
  combined.set(iv, 0);
  combined.set(new Uint8Array(ciphertext), iv.length);
  return base64UrlEncode(combined);
}

export function resolveRobloxDisplayName(userInfo: RobloxUserInfo): string {
  return userInfo.preferred_username || userInfo.nickname || userInfo.name || userInfo.sub;
}
