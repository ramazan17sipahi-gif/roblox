const GOOGLE_TOKEN_URL = 'https://oauth2.googleapis.com/token';
const GOOGLE_PLAY_SCOPE = 'https://www.googleapis.com/auth/androidpublisher';

interface GoogleServiceAccount {
  client_email: string;
  private_key: string;
}

interface GoogleSubscriptionPurchase {
  subscriptionState?: string;
  lineItems?: Array<{
    productId?: string;
    expiryTime?: string;
    offerDetails?: { basePlanId?: string };
  }>;
  latestOrderId?: string;
}

function base64UrlEncode(input: string): string {
  return btoa(input).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

async function importPrivateKey(pem: string): Promise<CryptoKey> {
  const pemContents = pem
    .replace('-----BEGIN PRIVATE KEY-----', '')
    .replace('-----END PRIVATE KEY-----', '')
    .replace(/\s/g, '');
  const binary = Uint8Array.from(atob(pemContents), (c) => c.charCodeAt(0));
  return crypto.subtle.importKey(
    'pkcs8',
    binary.buffer,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
}

async function createServiceAccountJwt(serviceAccount: GoogleServiceAccount): Promise<string> {
  const header = base64UrlEncode(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const now = Math.floor(Date.now() / 1000);
  const payload = base64UrlEncode(JSON.stringify({
    iss: serviceAccount.client_email,
    scope: GOOGLE_PLAY_SCOPE,
    aud: GOOGLE_TOKEN_URL,
    iat: now,
    exp: now + 3600,
  }));
  const unsigned = `${header}.${payload}`;
  const key = await importPrivateKey(serviceAccount.private_key);
  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(unsigned),
  );
  const encodedSignature = base64UrlEncode(String.fromCharCode(...new Uint8Array(signature)));
  return `${unsigned}.${encodedSignature}`;
}

function loadServiceAccount(): GoogleServiceAccount | null {
  const raw = Deno.env.get('GOOGLE_PLAY_SERVICE_ACCOUNT_JSON');
  if (!raw) return null;
  try {
    return JSON.parse(raw) as GoogleServiceAccount;
  } catch {
    return null;
  }
}

async function getGoogleAccessToken(serviceAccount: GoogleServiceAccount): Promise<string> {
  const assertion = await createServiceAccountJwt(serviceAccount);
  const response = await fetch(GOOGLE_TOKEN_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    }),
  });
  const payload = await response.json().catch(() => ({}));
  if (!response.ok || !payload.access_token) {
    throw new Error('Failed to obtain Google Play access token');
  }
  return payload.access_token as string;
}

export interface GooglePlayVerificationResult {
  valid: boolean;
  eventType: 'initial_purchase' | 'renewal';
  periodAnchor: string;
  expiresDate?: string;
  error?: string;
}

export async function verifyGooglePlaySubscription(
  purchaseToken: string,
  expectedProductId: string,
): Promise<GooglePlayVerificationResult> {
  const allowStub = Deno.env.get('ALLOW_IAP_STUB') === 'true';
  const serviceAccount = loadServiceAccount();
  const packageName = Deno.env.get('GOOGLE_PLAY_PACKAGE_NAME') || 'com.rblxclothingmaker.app';

  if (!serviceAccount) {
    if (allowStub) {
      return {
        valid: true,
        eventType: 'initial_purchase',
        periodAnchor: new Date().toISOString().slice(0, 10),
        expiresDate: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString(),
      };
    }
    return {
      valid: false,
      eventType: 'initial_purchase',
      periodAnchor: new Date().toISOString().slice(0, 10),
      error: 'Google Play verification is not configured',
    };
  }

  const accessToken = await getGoogleAccessToken(serviceAccount);
  const url = `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${packageName}/purchases/subscriptionsv2/tokens/${encodeURIComponent(purchaseToken)}`;
  const response = await fetch(url, {
    headers: { Authorization: `Bearer ${accessToken}` },
  });

  const purchase = await response.json().catch(() => ({})) as GoogleSubscriptionPurchase;
  if (!response.ok) {
    return {
      valid: false,
      eventType: 'initial_purchase',
      periodAnchor: new Date().toISOString().slice(0, 10),
      error: 'Google Play subscription lookup failed',
    };
  }

  const state = purchase.subscriptionState ?? '';
  const activeStates = ['SUBSCRIPTION_STATE_ACTIVE', 'SUBSCRIPTION_STATE_IN_GRACE_PERIOD'];
  if (!activeStates.includes(state)) {
    return {
      valid: false,
      eventType: 'initial_purchase',
      periodAnchor: new Date().toISOString().slice(0, 10),
      error: `Subscription not active: ${state}`,
    };
  }

  const lineItem = purchase.lineItems?.find((item) => item.productId === expectedProductId)
    ?? purchase.lineItems?.[0];

  if (lineItem?.productId && lineItem.productId !== expectedProductId) {
    return {
      valid: false,
      eventType: 'initial_purchase',
      periodAnchor: new Date().toISOString().slice(0, 10),
      error: 'Product ID mismatch',
    };
  }

  const expiresDate = lineItem?.expiryTime;
  const periodAnchor = expiresDate
    ? expiresDate.slice(0, 10)
    : new Date().toISOString().slice(0, 10);

  return {
    valid: true,
    eventType: 'initial_purchase',
    periodAnchor,
    expiresDate,
  };
}
