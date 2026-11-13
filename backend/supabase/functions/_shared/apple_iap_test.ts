import {
  AppleIapError,
  assertPurchaseTransaction,
  fetchSignedTransactionInfo,
  verifySignedNotification,
  verifySignedTransaction,
} from './apple_iap.ts';

const USER = '11111111-1111-4111-8111-111111111111';
const BUNDLE = 'com.rblxclothingmaker.app';
const PRODUCT = 'com.rblxclothingmaker.app.pro_monthly';

function assert(condition: unknown, message: string) {
  if (!condition) throw new Error(message);
}

function liveTransaction(overrides: Record<string, unknown> = {}) {
  const now = Date.now();
  return {
    bundleId: BUNDLE,
    productId: PRODUCT,
    transactionId: '2000000000000001',
    originalTransactionId: '2000000000000001',
    purchaseDate: now - 60_000,
    expiresDate: now + 30 * 24 * 60 * 60 * 1000,
    environment: 'Sandbox',
    appAccountToken: USER,
    ...overrides,
  };
}

Deno.test('invalid JWS signature is rejected', async () => {
  let transactionRejected = false;
  try {
    await verifySignedTransaction('not-a-jws', 'Sandbox', BUNDLE);
  } catch (error) {
    transactionRejected = error instanceof AppleIapError;
  }
  assert(transactionRejected, 'garbage transaction JWS was accepted');

  let notificationRejected = false;
  let notificationMessage = '';
  try {
    await verifySignedNotification('aaa.bbb.ccc', BUNDLE);
  } catch (error) {
    notificationRejected = error instanceof AppleIapError;
    notificationMessage = error instanceof AppleIapError ? error.message : '';
  }
  assert(notificationRejected, 'garbage notification JWS was accepted');
  assert(notificationMessage.length > 0, 'notification rejection had an empty message');
});

Deno.test('a transaction with a different bundle id is rejected', () => {
  const tx = liveTransaction({ bundleId: 'com.example.other' });
  let code = '';
  try {
    assertPurchaseTransaction(tx, {
      bundleId: BUNDLE,
      productId: PRODUCT,
      userId: USER,
      environment: 'Sandbox',
    });
  } catch (error) {
    code = error instanceof AppleIapError ? error.code : '';
  }
  assert(code === 'BUNDLE', `expected BUNDLE, got ${code}`);
});

Deno.test('an expired subscription is rejected', () => {
  const tx = liveTransaction({ expiresDate: Date.now() - 60_000 });
  let code = '';
  try {
    assertPurchaseTransaction(tx, {
      bundleId: BUNDLE,
      productId: PRODUCT,
      userId: USER,
      environment: 'Sandbox',
    });
  } catch (error) {
    code = error instanceof AppleIapError ? error.code : '';
  }
  assert(code === 'EXPIRED', `expected EXPIRED, got ${code}`);
});

Deno.test('a production transaction-not-found response falls back to sandbox', async () => {
  const calls: string[] = [];
  const fetchImpl: typeof fetch = async (input) => {
    const url = String(input);
    calls.push(url);
    if (url.includes('api.storekit.itunes.apple.com')) {
      return new Response(JSON.stringify({
        errorCode: 4040010,
        errorMessage: 'Transaction id not found.',
      }), { status: 404 });
    }
    return new Response(JSON.stringify({ signedTransactionInfo: 'sandbox-jws' }), { status: 200 });
  };
  const result = await fetchSignedTransactionInfo('2000000000000001', 'test-jwt', fetchImpl);
  assert(calls.length === 2, `expected 2 calls, got ${calls.length}`);
  assert(calls[0].includes('api.storekit.itunes.apple.com'), 'first call was not production');
  assert(calls[1].includes('api.storekit-sandbox.itunes.apple.com'), 'second call was not sandbox');
  assert(result.environment === 'Sandbox', result.environment);
  assert(result.signedTransactionInfo === 'sandbox-jws', 'sandbox payload was not returned');
});

Deno.test('a production 401 falls back to sandbox for an unreleased app', async () => {
  const calls: string[] = [];
  const fetchImpl: typeof fetch = async (input) => {
    const url = String(input);
    calls.push(url);
    if (url.includes('api.storekit.itunes.apple.com')) {
      return new Response('', { status: 401 });
    }
    return new Response(JSON.stringify({ signedTransactionInfo: 'sandbox-jws' }), { status: 200 });
  };
  const result = await fetchSignedTransactionInfo('2000000123456789', 'test-jwt', fetchImpl);
  assert(calls.length === 2, `expected 2 calls, got ${calls.length}`);
  assert(result.environment === 'Sandbox', result.environment);
  assert(result.signedTransactionInfo === 'sandbox-jws', 'sandbox payload was not returned');
});

Deno.test('a real sandbox transaction JWS verifies', async () => {
  const jws = Deno.readTextFileSync(new URL('./sandbox_transaction.jws', import.meta.url)).trim();
  const payload = await verifySignedTransaction(jws, 'Sandbox', BUNDLE);
  assert(payload.bundleId === BUNDLE, `bundle ${payload.bundleId}`);
  assert(payload.environment === 'Sandbox', `environment ${payload.environment}`);
  assert(payload.productId === PRODUCT, `product ${payload.productId}`);
});

Deno.test('401 from both Apple hosts stays an auth failure', async () => {
  const fetchImpl: typeof fetch = async () => new Response('', { status: 401 });
  let code = '';
  try {
    await fetchSignedTransactionInfo('2000000123456789', 'test-jwt', fetchImpl);
  } catch (error) {
    code = error instanceof AppleIapError ? error.code : '';
  }
  assert(code === 'API', `expected API, got ${code}`);
});
