// App Store Server API + JWS verification.
//
// JWS chain checks live in apple_jws.ts and use WebCrypto. Apple's
// SignedDataVerifier needs node X509Certificate methods that Supabase Edge
// does not implement, and the thrown exception has an empty message.
// JWT signing uses jose with the claims from Apple's "Generating JSON Web
// Tokens" document. The library's HTTP client uses node-fetch, which cannot
// take the fetch mock the tests require, so Get Transaction Info stays here.

import { importPKCS8, SignJWT } from 'npm:jose@5.9.6';
import { AppleIapError, verifyAppleSignedPayload } from './apple_jws.ts';

export { AppleIapError };

export const PRODUCTION_TX_BASE = 'https://api.storekit.itunes.apple.com/inApps/v1/transactions/';
export const SANDBOX_TX_BASE = 'https://api.storekit-sandbox.itunes.apple.com/inApps/v1/transactions/';
export const APP_BUNDLE_ID = 'com.rblxclothingmaker.app';

export interface AppleIapConfig {
  keyId: string;
  issuerId: string;
  privateKey: string;
  bundleId: string;
}

export interface DecodedTransaction {
  transactionId?: string;
  originalTransactionId?: string;
  bundleId?: string;
  productId?: string;
  purchaseDate?: number;
  expiresDate?: number;
  revocationDate?: number;
  environment?: string;
  appAccountToken?: string;
}

export interface AppleVerification {
  valid: boolean;
  eventType: 'initial_purchase';
  periodAnchor: string;
  expiresDate?: string;
  originalTransactionId?: string;
  environment?: string;
  error?: string;
}

export interface FetchedTransaction {
  environment: 'Production' | 'Sandbox';
  signedTransactionInfo: string;
}

export function normalizePem(raw: string): string {
  let key = raw.trim();
  if ((key.startsWith('"') && key.endsWith('"')) || (key.startsWith("'") && key.endsWith("'"))) {
    key = key.slice(1, -1);
  }
  return key.replace(/\\n/g, '\n').trim();
}

export function readAppleIapConfig(): AppleIapConfig | null {
  const keyId = Deno.env.get('APPLE_IAP_KEY_ID')?.trim() ?? '';
  const issuerId = Deno.env.get('APPLE_IAP_ISSUER_ID')?.trim() ?? '';
  const privateKey = normalizePem(Deno.env.get('APPLE_IAP_PRIVATE_KEY') ?? '');
  const bundleId = Deno.env.get('APPLE_BUNDLE_ID')?.trim() || APP_BUNDLE_ID;
  if (!keyId || !issuerId || !privateKey.includes('PRIVATE KEY')) return null;
  return { keyId, issuerId, privateKey, bundleId };
}

export async function createAppStoreJwt(config: AppleIapConfig): Promise<string> {
  const key = await importPKCS8(config.privateKey, 'ES256');
  return await new SignJWT({
    bid: config.bundleId,
    nonce: crypto.randomUUID(),
  })
    .setProtectedHeader({ alg: 'ES256', kid: config.keyId, typ: 'JWT' })
    .setIssuer(config.issuerId)
    .setAudience('appstoreconnect-v1')
    .setIssuedAt()
    .setExpirationTime('20m')
    .sign(key);
}

export function isTransactionNotFound(status: number, body: string): boolean {
  if (status === 404) return true;
  try {
    const parsed = JSON.parse(body) as { errorCode?: number; errorMessage?: string };
    if (parsed.errorCode === 4040010 || parsed.errorCode === 4040005) return true;
    const message = (parsed.errorMessage ?? '').toLowerCase();
    return message.includes('transaction id not found') || message.includes('original transaction id not found');
  } catch {
    return false;
  }
}

async function requestTransaction(
  base: string,
  transactionId: string,
  jwt: string,
  fetchImpl: typeof fetch,
): Promise<{ ok: true; signed: string } | { ok: false; notFound: boolean; unauthorized: boolean; error: string }> {
  const response = await fetchImpl(`${base}${encodeURIComponent(transactionId)}`, {
    method: 'GET',
    headers: {
      Authorization: `Bearer ${jwt}`,
      Accept: 'application/json',
    },
  });
  const body = await response.text();
  if (response.ok) {
    const parsed = JSON.parse(body) as { signedTransactionInfo?: string };
    if (!parsed.signedTransactionInfo) {
      return { ok: false, notFound: false, unauthorized: false, error: 'Apple response missing signedTransactionInfo' };
    }
    return { ok: true, signed: parsed.signedTransactionInfo };
  }
  return {
    ok: false,
    notFound: isTransactionNotFound(response.status, body),
    unauthorized: response.status === 401,
    error: body || `Apple API status ${response.status}`,
  };
}

/**
 * Production first. An unreleased app answers sandbox purchases with
 * production HTTP 401 instead of "transaction id not found", so 401 also
 * retries the sandbox host. A second 401 means the JWT itself was rejected.
 */
export async function fetchSignedTransactionInfo(
  transactionId: string,
  jwt: string,
  fetchImpl: typeof fetch = fetch,
): Promise<FetchedTransaction> {
  const production = await requestTransaction(PRODUCTION_TX_BASE, transactionId, jwt, fetchImpl);
  if (production.ok) {
    return { environment: 'Production', signedTransactionInfo: production.signed };
  }
  if (!production.notFound && !production.unauthorized) {
    throw new AppleIapError(production.error, 'API');
  }
  const sandbox = await requestTransaction(SANDBOX_TX_BASE, transactionId, jwt, fetchImpl);
  if (sandbox.ok) {
    return { environment: 'Sandbox', signedTransactionInfo: sandbox.signed };
  }
  if (production.unauthorized && sandbox.unauthorized) {
    throw new AppleIapError(production.error, 'API');
  }
  throw new AppleIapError(sandbox.error || 'transaction not found', sandbox.notFound ? 'NOT_FOUND' : 'API');
}

function bundleAndEnvironment(payload: Record<string, unknown>): { bundleId?: string; environment?: string } {
  const data = (payload.data ?? payload.summary ?? {}) as Record<string, unknown>;
  const bundleId = typeof data.bundleId === 'string'
    ? data.bundleId
    : typeof payload.bundleId === 'string' ? payload.bundleId : undefined;
  const environment = typeof data.environment === 'string'
    ? data.environment
    : typeof payload.environment === 'string' ? payload.environment : undefined;
  return { bundleId, environment };
}

/** Verify a transaction JWS, then check the bundle and the API host environment. */
export async function verifySignedTransaction(
  jws: string,
  environment: 'Production' | 'Sandbox',
  bundleId: string,
): Promise<Record<string, unknown>> {
  const payload = await verifyAppleSignedPayload(jws);
  const tx = bundleAndEnvironment(payload);
  if (tx.bundleId !== bundleId) throw new AppleIapError('bundleId does not match', 'BUNDLE');
  if (tx.environment !== environment) {
    throw new AppleIapError(`environment ${tx.environment ?? 'missing'} does not match ${environment}`, 'ENVIRONMENT');
  }
  return payload;
}

/** Verify a notification JWS. The environment is inside the signed payload. */
export async function verifySignedNotification(jws: string, bundleId: string): Promise<Record<string, unknown>> {
  const payload = await verifyAppleSignedPayload(jws);
  const note = bundleAndEnvironment(payload);
  if (note.bundleId !== bundleId) throw new AppleIapError('bundleId does not match', 'INVALID_APP_IDENTIFIER');
  if (note.environment !== 'Production' && note.environment !== 'Sandbox') {
    throw new AppleIapError(`environment ${note.environment ?? 'missing'} is not Production or Sandbox`, 'INVALID_ENVIRONMENT');
  }
  return payload;
}

function asMillis(value: unknown): number | undefined {
  if (typeof value === 'number' && Number.isFinite(value)) return value;
  if (typeof value === 'string' && /^\d+$/.test(value)) return Number(value);
  return undefined;
}

export function readTransaction(payload: Record<string, unknown>): DecodedTransaction {
  return {
    transactionId: typeof payload.transactionId === 'string' ? payload.transactionId : undefined,
    originalTransactionId: typeof payload.originalTransactionId === 'string' ? payload.originalTransactionId : undefined,
    bundleId: typeof payload.bundleId === 'string' ? payload.bundleId : undefined,
    productId: typeof payload.productId === 'string' ? payload.productId : undefined,
    purchaseDate: asMillis(payload.purchaseDate),
    expiresDate: asMillis(payload.expiresDate),
    revocationDate: asMillis(payload.revocationDate),
    environment: typeof payload.environment === 'string' ? payload.environment : undefined,
    appAccountToken: typeof payload.appAccountToken === 'string' ? payload.appAccountToken : undefined,
  };
}

export function isoFromMillis(ms: number): string {
  return new Date(ms).toISOString();
}

export function periodAnchorFromMillis(ms: number): string {
  return new Date(ms).toISOString().slice(0, 10);
}

/**
 * Checks required for a purchase the signed-in user is trying to redeem.
 * A different appAccountToken does not reject the receipt. The caller moves
 * the subscription onto the signed-in account instead.
 */
export function assertPurchaseTransaction(
  tx: DecodedTransaction,
  input: { bundleId: string; productId: string; userId: string; environment: string; now?: number },
): AppleVerification {
  const now = input.now ?? Date.now();
  if (tx.bundleId !== input.bundleId) {
    throw new AppleIapError('bundleId does not match', 'BUNDLE');
  }
  if (tx.environment !== input.environment) {
    throw new AppleIapError('environment does not match the API host', 'ENVIRONMENT');
  }
  if (tx.productId !== input.productId) {
    throw new AppleIapError('productId does not match', 'PRODUCT');
  }
  if (tx.revocationDate != null) {
    throw new AppleIapError('transaction is revoked', 'REVOKED');
  }
  if (tx.expiresDate == null || tx.expiresDate <= now) {
    throw new AppleIapError('subscription is expired', 'EXPIRED');
  }
  if (tx.purchaseDate == null) {
    throw new AppleIapError('purchaseDate is missing', 'PURCHASE_DATE');
  }
  return {
    valid: true,
    eventType: 'initial_purchase',
    periodAnchor: periodAnchorFromMillis(tx.purchaseDate),
    expiresDate: isoFromMillis(tx.expiresDate),
    originalTransactionId: tx.originalTransactionId,
    environment: tx.environment,
  };
}

export async function verifyApplePurchase(input: {
  config: AppleIapConfig;
  transactionId: string;
  productId: string;
  userId: string;
  fetchImpl?: typeof fetch;
  now?: number;
}): Promise<AppleVerification> {
  const jwt = await createAppStoreJwt(input.config);
  const fetched = await fetchSignedTransactionInfo(input.transactionId, jwt, input.fetchImpl ?? fetch);
  const payload = await verifySignedTransaction(fetched.signedTransactionInfo, fetched.environment, input.config.bundleId);
  const tx = readTransaction(payload);
  return assertPurchaseTransaction(tx, {
    bundleId: input.config.bundleId,
    productId: input.productId,
    userId: input.userId,
    environment: fetched.environment,
    now: input.now,
  });
}
