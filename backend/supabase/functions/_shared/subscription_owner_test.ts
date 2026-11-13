import { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2.49.0';
import {
  AppleIapError,
  assertPurchaseTransaction,
  fetchSignedTransactionInfo,
  readTransaction,
  verifySignedTransaction,
} from './apple_iap.ts';
import { completeIosPurchase, resolveAppleNotificationUser } from './subscription_owner.ts';
import { grantBillingCredit } from './billing_grant.ts';

const BUNDLE = 'com.rblxclothingmaker.app';
const PRODUCT = 'com.rblxclothingmaker.app.pro_monthly';
const OTHER = '22222222-2222-4222-8222-222222222222';

function assert(condition: unknown, message: string) {
  if (!condition) throw new Error(message);
}

type Row = Record<string, unknown> & { raw_payload?: Record<string, unknown> };

class Query {
  private filters: Array<(row: Row) => boolean> = [];
  private descending = false;
  private max: number | null = null;
  private mode: 'select' | 'insert' | 'update' | 'upsert' = 'select';
  private payload: Row | null = null;

  constructor(private db: FakeDb, private table: string) {}

  select() {
    this.mode = 'select';
    return this;
  }
  insert(row: Row) {
    this.mode = 'insert';
    this.payload = row;
    return this;
  }
  update(row: Row) {
    this.mode = 'update';
    this.payload = row;
    return this;
  }
  upsert(row: Row) {
    this.mode = 'upsert';
    this.payload = row;
    return this;
  }
  eq(column: string, value: unknown) {
    this.filters.push((row) => row[column] === value);
    return this;
  }
  filter(expression: string, operator: string, value: unknown) {
    if (expression === 'raw_payload->>originalTransactionId' && operator === 'eq') {
      this.filters.push((row) => row.raw_payload?.originalTransactionId === value);
    }
    return this;
  }
  order() {
    this.descending = true;
    return this;
  }
  limit(count: number) {
    this.max = count;
    return this;
  }
  maybeSingle() {
    return this.exec(true);
  }
  then<T>(onFulfilled: (value: { data: unknown; error: null }) => T, onRejected?: (reason: unknown) => T) {
    return this.exec(false).then(onFulfilled, onRejected);
  }

  private async exec(single: boolean) {
    const table = this.db.tables[this.table] ??= [];
    if (this.mode === 'insert' && this.payload) {
      const row = {
        ...this.payload,
        created_at: this.payload.created_at ?? new Date(Date.now() + this.db.clock++).toISOString(),
      };
      table.push(row);
      return { data: row, error: null };
    }
    if (this.mode === 'update' && this.payload) {
      for (const row of table) {
        if (this.filters.every((filter) => filter(row))) Object.assign(row, this.payload);
      }
      return { data: null, error: null };
    }
    if (this.mode === 'upsert' && this.payload) {
      const index = table.findIndex((row) => row.user_id === this.payload?.user_id);
      if (index >= 0) table[index] = { ...table[index], ...this.payload };
      else table.push({ ...this.payload });
      return { data: null, error: null };
    }
    let rows = table.filter((row) => this.filters.every((filter) => filter(row)));
    if (this.descending) {
      rows = rows.slice().sort((a, b) => String(b.created_at ?? '').localeCompare(String(a.created_at ?? '')));
    }
    if (this.max != null) rows = rows.slice(0, this.max);
    return { data: single ? rows[0] ?? null : rows, error: null };
  }
}

class FakeDb {
  tables: Record<string, Row[]> = {
    purchase_events: [],
    user_entitlements: [],
    billing_products: [{
      ios_product_id: PRODUCT,
      is_active: true,
      credit_amount: 0,
      type: 'subscription',
      plan_code: 'pro',
      code: 'pro_monthly',
    }],
    credit_wallets: [],
  };
  users = new Set<string>();
  clock = 1;
  tokenLookups: string[] = [];

  from(table: string) {
    return new Query(this, table);
  }
  rpc() {
    return Promise.resolve({ data: [{ new_balance: 0 }], error: null });
  }
  auth = {
    admin: {
      getUserById: async (id: string) => {
        this.tokenLookups.push(id);
        return this.users.has(id)
          ? { data: { user: { id } }, error: null }
          : { data: { user: null }, error: { message: 'not found' } };
      },
    },
  };
}

function client(db: FakeDb) {
  return db as unknown as SupabaseClient;
}

function entitlement(db: FakeDb, userId: string) {
  return db.tables.user_entitlements.find((row) => row.user_id === userId);
}

function transfers(db: FakeDb) {
  return db.tables.purchase_events.filter((row) => row.raw_payload?.kind === 'transfer');
}

async function loadSandboxTransaction() {
  const jws = Deno.readTextFileSync(new URL('./sandbox_transaction.jws', import.meta.url)).trim();
  const calls: string[] = [];
  const fetched = await fetchSignedTransactionInfo('2000000000000001', 'test-jwt', async (input) => {
    const url = String(input);
    calls.push(url);
    if (url.includes('api.storekit-sandbox.itunes.apple.com')) {
      return new Response(JSON.stringify({ signedTransactionInfo: jws }), { status: 200 });
    }
    return new Response('', { status: 401 });
  });
  assert(calls.some((url) => url.includes('api.storekit-sandbox.itunes.apple.com')), 'sandbox fetch was not used');
  const payload = await verifySignedTransaction(fetched.signedTransactionInfo, 'Sandbox', BUNDLE);
  return readTransaction(payload);
}

function seedOwner(db: FakeDb, userId: string, originalTransactionId: string) {
  db.users.add(userId);
  db.tables.purchase_events.push({
    user_id: userId,
    platform: 'ios',
    product_id: PRODUCT,
    purchase_token_or_txid: 'seed-tx',
    verification_status: 'verified',
    created_at: '2026-11-13T01:40:00.000Z',
    dedupe_key: `seed:${userId}`,
    raw_payload: { originalTransactionId },
  });
  db.tables.user_entitlements.push({
    user_id: userId,
    plan_code: 'pro',
    status: 'active',
  });
}

Deno.test('same account restore grants Pro and does not transfer', async () => {
  const tx = await loadSandboxTransaction();
  const owner = tx.appAccountToken ?? '';
  const db = new FakeDb();
  seedOwner(db, owner, tx.originalTransactionId ?? '');
  const verification = assertPurchaseTransaction(tx, {
    bundleId: BUNDLE,
    productId: PRODUCT,
    userId: owner,
    environment: 'Sandbox',
    now: (tx.expiresDate ?? 0) - 1000,
  });
  const result = await completeIosPurchase({
    svc: client(db),
    ctx: { opToken: 'same-account' },
    userId: owner,
    productId: PRODUCT,
    transactionId: tx.transactionId ?? 'tx',
    verification,
  });
  assert(result.granted, 'Pro was not granted');
  assert(result.transferredFrom === null, 'same account was treated as a transfer');
  assert(entitlement(db, owner)?.status === 'active', 'owner is not active');
  assert(transfers(db).length === 0, 'a transfer row was written');
});

Deno.test('restore onto another account expires the old Pro and records the transfer', async () => {
  const tx = await loadSandboxTransaction();
  const owner = tx.appAccountToken ?? '';
  const db = new FakeDb();
  seedOwner(db, owner, tx.originalTransactionId ?? '');
  const verification = assertPurchaseTransaction(tx, {
    bundleId: BUNDLE,
    productId: PRODUCT,
    userId: OTHER,
    environment: 'Sandbox',
    now: (tx.expiresDate ?? 0) - 1000,
  });
  const before = db.tables.purchase_events.length;
  const result = await completeIosPurchase({
    svc: client(db),
    ctx: { opToken: 'transfer' },
    userId: OTHER,
    productId: PRODUCT,
    transactionId: tx.transactionId ?? 'tx',
    verification,
  });
  assert(result.granted, 'Pro was not granted to the new account');
  assert(result.transferredFrom === owner, 'previous owner was not returned');
  assert(entitlement(db, owner)?.status === 'expired', 'old Pro is still active');
  assert(entitlement(db, OTHER)?.plan_code === 'pro', 'new account is not Pro');
  assert(entitlement(db, OTHER)?.status === 'active', 'new account is not active');
  const moved = transfers(db);
  assert(moved.length === 1, 'transfer row was not written');
  assert(moved[0].raw_payload?.fromUserId === owner, 'transfer is missing the old user');
  assert(moved[0].raw_payload?.toUserId === OTHER, 'transfer is missing the new user');
  assert(moved[0].raw_payload?.originalTransactionId === tx.originalTransactionId, 'transfer is missing the subscription id');
  assert(typeof moved[0].raw_payload?.transferredAt === 'string', 'transfer time was not recorded');
  assert(db.tables.purchase_events.length === before + 2, 'transfer and grant rows were not both stored');
});

Deno.test('a renewal after transfer grants the new account only', async () => {
  const tx = await loadSandboxTransaction();
  const owner = tx.appAccountToken ?? '';
  const db = new FakeDb();
  seedOwner(db, owner, tx.originalTransactionId ?? '');
  db.users.add(owner);
  const verification = assertPurchaseTransaction(tx, {
    bundleId: BUNDLE,
    productId: PRODUCT,
    userId: OTHER,
    environment: 'Sandbox',
    now: (tx.expiresDate ?? 0) - 1000,
  });
  await completeIosPurchase({
    svc: client(db),
    ctx: { opToken: 'transfer-first' },
    userId: OTHER,
    productId: PRODUCT,
    transactionId: tx.transactionId ?? 'tx',
    verification,
  });
  const resolved = await resolveAppleNotificationUser(client(db), tx);
  assert(resolved === OTHER, `renewal target was ${resolved}`);
  assert(!db.tokenLookups.includes(owner), 'notification lookup used appAccountToken after a transfer');
  const renewal = await grantBillingCredit({
    svc: client(db),
    ctx: { opToken: 'renew' },
    userId: resolved ?? '',
    platform: 'ios',
    productId: PRODUCT,
    transactionIdOrToken: 'renewal-tx',
    eventType: 'renewal',
    periodAnchor: '2026-11-14',
    rawPayload: { originalTransactionId: tx.originalTransactionId, expiresDate: verification.expiresDate },
  });
  assert(renewal.granted, 'renewal was not granted');
  assert(entitlement(db, OTHER)?.status === 'active', 'new account lost Pro on renewal');
  assert(entitlement(db, owner)?.status === 'expired', 'renewal restored the old account');
});

Deno.test('an expired transaction is rejected and nothing is transferred', async () => {
  const tx = await loadSandboxTransaction();
  const db = new FakeDb();
  seedOwner(db, tx.appAccountToken ?? '', tx.originalTransactionId ?? '');
  const before = JSON.stringify(db.tables);
  let code = '';
  try {
    assertPurchaseTransaction(tx, {
      bundleId: BUNDLE,
      productId: PRODUCT,
      userId: OTHER,
      environment: 'Sandbox',
      now: (tx.expiresDate ?? 0) + 1000,
    });
  } catch (error) {
    code = error instanceof AppleIapError ? error.code : '';
  }
  assert(code === 'EXPIRED', `expected EXPIRED, got ${code}`);
  assert(JSON.stringify(db.tables) === before, 'expired restore changed stored rows');
});

Deno.test('a revoked transaction is rejected and nothing is transferred', async () => {
  const tx = await loadSandboxTransaction();
  const db = new FakeDb();
  seedOwner(db, tx.appAccountToken ?? '', tx.originalTransactionId ?? '');
  const before = JSON.stringify(db.tables);
  let code = '';
  try {
    assertPurchaseTransaction({ ...tx, revocationDate: (tx.expiresDate ?? 0) - 1000 }, {
      bundleId: BUNDLE,
      productId: PRODUCT,
      userId: OTHER,
      environment: 'Sandbox',
      now: (tx.expiresDate ?? 0) - 2000,
    });
  } catch (error) {
    code = error instanceof AppleIapError ? error.code : '';
  }
  assert(code === 'REVOKED', `expected REVOKED, got ${code}`);
  assert(JSON.stringify(db.tables) === before, 'revoked restore changed stored rows');
});
