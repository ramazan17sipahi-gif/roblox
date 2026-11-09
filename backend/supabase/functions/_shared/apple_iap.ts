// App Store Server API + JWS verification.
//
// JWS chain checks use Apple's SignedDataVerifier. OCSP is off: a failed
// online check on the edge runtime would reject a real App Review purchase.
// The certificate chain, bundle id, and environment are still verified.
// JWT signing uses jose with the claims from Apple's "Generating JSON Web
// Tokens" document. The library's HTTP client uses node-fetch, which cannot
// take the fetch mock the tests require, so Get Transaction Info stays here.

import { importPKCS8, SignJWT } from 'npm:jose@5.9.6';
import {
  Environment,
  SignedDataVerifier,
} from 'npm:@apple/app-store-server-library@1.6.0';
import { Buffer } from 'node:buffer';
import { APPLE_ROOT_CERTIFICATES } from './apple_roots.ts';

export const PRODUCTION_TX_BASE = 'https://api.storekit.itunes.apple.com/inApps/v1/transactions/';
export const SANDBOX_TX_BASE = 'https://api.storekit-sandbox.itunes.apple.com/inApps/v1/transactions/';
export const APP_BUNDLE_ID = 'com.rblxclothingmaker.app';
// Public App Store Apple ID. Required by SignedDataVerifier in Production.
const APP_APPLE_ID = 6805604533;

const APPLE_ROOT_BUFFERS = APPLE_ROOT_CERTIFICATES.map((der) => Buffer.from(der));

export class AppleIapError extends Error {
  constructor(message: string, readonly code: string) {
    super(message);
    this.name = 'AppleIapError';
  }
}

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
): Promise<{ ok: true; signed: string } | { ok: false; notFound: boolean; error: string }> {
  const response = await fetchImpl(`${base}${encodeURIComponent(transactionId)}`, {
    method: 'GET',
    headers: { Authorization: `Bearer ${jwt}` },
  });
  const body = await response.text();
  if (response.ok) {
    const parsed = JSON.parse(body) as { signedTransactionInfo?: string };
    if (!parsed.signedTransactionInfo) {
      return { ok: false, notFound: false, error: 'Apple response missing signedTransactionInfo' };
    }
    return { ok: true, signed: parsed.signedTransactionInfo };
  }
  return {
    ok: false,
    notFound: isTransactionNotFound(response.status, body),
    error: body || `Apple API status ${response.status}`,
  };
}

/** Production first. "Transaction id not found" retries the sandbox host. */
export async function fetchSignedTransactionInfo(
  transactionId: string,
  jwt: string,
  fetchImpl: typeof fetch = fetch,
): Promise<FetchedTransaction> {
  const production = await requestTransaction(PRODUCTION_TX_BASE, transactionId, jwt, fetchImpl);
  if (production.ok) {
    return { environment: 'Production', signedTransactionInfo: production.signed };
  }
  if (!production.notFound) {
    throw new AppleIapError(production.error, 'API');
  }
  const sandbox = await requestTransaction(SANDBOX_TX_BASE, transactionId, jwt, fetchImpl);
  if (sandbox.ok) {
    return { environment: 'Sandbox', signedTransactionInfo: sandbox.signed };
  }
  throw new AppleIapError(sandbox.error || 'transaction not found', sandbox.notFound ? 'NOT_FOUND' : 'API');
}

function productionAppAppleId(): number {
  const raw = Deno.env.get('APPLE_APP_APPLE_ID')?.trim();
  const parsed = raw ? Number(raw) : APP_APPLE_ID;
  return Number.isFinite(parsed) ? parsed : APP_APPLE_ID;
}

function verifierFor(environment: 'Production' | 'Sandbox', bundleId: string): SignedDataVerifier {
  const appleEnvironment = environment === 'Production' ? Environment.PRODUCTION : Environment.SANDBOX;
  const appAppleId = environment === 'Production' ? productionAppAppleId() : undefined;
  return new SignedDataVerifier(APPLE_ROOT_BUFFERS, false, appleEnvironment, bundleId, appAppleId);
}

function asRecord(value: unknown): Record<string, unknown> {
  return JSON.parse(JSON.stringify(value)) as Record<string, unknown>;
}

/** Verify a transaction JWS with Apple's SignedDataVerifier. */
export async function verifySignedTransaction(
  jws: string,
  environment: 'Production' | 'Sandbox',
  bundleId: string,
): Promise<Record<string, unknown>> {
  try {
    const decoded = await verifierFor(environment, bundleId).verifyAndDecodeTransaction(jws);
    return asRecord(decoded);
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    throw new AppleIapError(message || 'transaction JWS rejected', 'VERIFICATION_FAILURE');
  }
}

/** Verify a notification JWS. Tries both environments because the payload is signed. */
export async function verifySignedNotification(jws: string, bundleId: string): Promise<Record<string, unknown>> {
  let lastError: unknown;
  for (const environment of ['Production', 'Sandbox'] as const) {
    try {
      const decoded = await verifierFor(environment, bundleId).verifyAndDecodeNotification(jws);
      return asRecord(decoded);
    } catch (error) {
      lastError = error;
    }
  }
  const message = lastError instanceof Error ? lastError.message : String(lastError);
  throw new AppleIapError(message || 'notification JWS rejected', 'VERIFICATION_FAILURE');
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
 * appAccountToken is only enforced when Apple echoes it.
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
  if (tx.appAccountToken && tx.appAccountToken.toLowerCase() !== input.userId.toLowerCase()) {
    throw new AppleIapError('appAccountToken does not match the signed-in user', 'ACCOUNT');
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
