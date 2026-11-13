// App Store JWS checks without node:crypto X509Certificate.
// Supabase Edge does not implement X509Certificate.publicKey/verify, and
// pkijs refuses to install its crypto engine there (process.pid is missing,
// and assigning through `global` throws). Certificate bytes are parsed with
// pkijs; signatures are checked with WebCrypto.

import { Buffer } from 'node:buffer';
import { decodeProtectedHeader, importX509, jwtVerify } from 'npm:jose@5.9.6';
import { Certificate } from 'npm:pkijs@3.2.4';
import { APPLE_ROOT_CERTIFICATES } from './apple_roots.ts';

export class AppleIapError extends Error {
  constructor(message: string, readonly code: string) {
    super(message);
    this.name = 'AppleIapError';
  }
}

const LEAF_OID = '1.2.840.113635.100.6.11.1';
const INTERMEDIATE_OID = '1.2.840.113635.100.6.2.1';
const DATE_SKEW_MS = 60_000;

function certificateFromDer(der: Uint8Array): Certificate {
  const bytes = der.buffer.slice(der.byteOffset, der.byteOffset + der.byteLength) as ArrayBuffer;
  return Certificate.fromBER(bytes);
}

function certificateFromB64(b64: string): Certificate {
  return certificateFromDer(new Uint8Array(Buffer.from(b64, 'base64')));
}

function derToPem(der: Uint8Array): string {
  const lines = Buffer.from(der).toString('base64').match(/.{1,64}/g)?.join('\n') ?? '';
  return `-----BEGIN CERTIFICATE-----\n${lines}\n-----END CERTIFICATE-----\n`;
}

function hasExtension(cert: Certificate, oid: string): boolean {
  return (cert.extensions ?? []).some((ext) => ext.extnID === oid);
}

function checkDates(cert: Certificate, effective: Date, label: string): void {
  const notBefore = cert.notBefore.value.getTime();
  const notAfter = cert.notAfter.value.getTime();
  const at = effective.getTime();
  if (notBefore > at + DATE_SKEW_MS || notAfter < at - DATE_SKEW_MS) {
    throw new AppleIapError(`${label} certificate is outside its validity dates`, 'INVALID_CERTIFICATE');
  }
}

const ECDSA_SHA: Record<string, { hash: 'SHA-256' | 'SHA-384' | 'SHA-512'; alg: 'ES256' | 'ES384' | 'ES512'; size: number }> = {
  '1.2.840.10045.4.3.2': { hash: 'SHA-256', alg: 'ES256', size: 32 },
  '1.2.840.10045.4.3.3': { hash: 'SHA-384', alg: 'ES384', size: 48 },
  '1.2.840.10045.4.3.4': { hash: 'SHA-512', alg: 'ES512', size: 66 },
};

function ecdsaDerToRaw(der: Uint8Array, size: number): Uint8Array {
  let offset = 0;
  if (der[offset] !== 0x30) throw new Error('ECDSA signature is not a DER sequence');
  offset += 2;
  if ((der[1] & 0x80) !== 0) offset += der[1] & 0x7f;
  const readInt = (): Uint8Array => {
    if (der[offset] !== 0x02) throw new Error('ECDSA signature integer missing');
    const length = der[offset + 1];
    const bytes = der.slice(offset + 2, offset + 2 + length);
    offset += 2 + length;
    let start = 0;
    while (start < bytes.length - 1 && bytes[start] === 0) start++;
    const value = bytes.slice(start);
    if (value.length > size) throw new Error('ECDSA signature integer is too long');
    const padded = new Uint8Array(size);
    padded.set(value, size - value.length);
    return padded;
  };
  const raw = new Uint8Array(size * 2);
  raw.set(readInt(), 0);
  raw.set(readInt(), size);
  return raw;
}

async function assertSignedBy(subject: Certificate, issuerDer: Uint8Array, label: string): Promise<void> {
  const oid = subject.signatureAlgorithm.algorithmId;
  const spec = ECDSA_SHA[oid];
  if (!spec) {
    throw new AppleIapError(`${label} signature algorithm ${oid} is not supported`, 'VERIFICATION_FAILURE');
  }
  let valid = false;
  try {
    const key = await importX509(derToPem(issuerDer), spec.alg);
    if (!(key instanceof CryptoKey)) throw new Error('issuer public key could not be imported');
    const signature = ecdsaDerToRaw(new Uint8Array(subject.signatureValue.valueBlock.valueHexView), spec.size);
    valid = await crypto.subtle.verify(
      { name: 'ECDSA', hash: spec.hash },
      key,
      signature as BufferSource,
      subject.tbsView as BufferSource,
    );
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    throw new AppleIapError(`${label} certificate check failed: ${message}`, 'VERIFICATION_FAILURE');
  }
  if (!valid) {
    throw new AppleIapError(`${label} certificate was not signed by its issuer`, 'VERIFICATION_FAILURE');
  }
}

/**
 * Verifies an App Store signed payload (notification or transaction).
 * The certificate chain is leaf, intermediate, and the embedded Apple root.
 * x5c length stays 3, matching Apple's SignedDataVerifier.
 */
export async function verifyAppleSignedPayload(jws: string): Promise<Record<string, unknown>> {
  let header: ReturnType<typeof decodeProtectedHeader>;
  try {
    header = decodeProtectedHeader(jws);
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    throw new AppleIapError(`JWS header rejected: ${message}`, 'VERIFICATION_FAILURE');
  }
  if (header.alg !== 'ES256') {
    throw new AppleIapError(`JWS alg ${header.alg ?? 'missing'} is not ES256`, 'VERIFICATION_FAILURE');
  }
  const chain = header.x5c;
  if (!Array.isArray(chain) || chain.length !== 3 || chain.some((cert) => typeof cert !== 'string')) {
    throw new AppleIapError('JWS x5c chain length is not 3', 'INVALID_CHAIN_LENGTH');
  }

  let leaf: Certificate;
  let intermediate: Certificate;
  let root: Certificate;
  try {
    leaf = certificateFromB64(chain[0]);
    intermediate = certificateFromB64(chain[1]);
    root = certificateFromDer(APPLE_ROOT_CERTIFICATES[0]);
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    throw new AppleIapError(`JWS certificate rejected: ${message}`, 'INVALID_CERTIFICATE');
  }

  await assertSignedBy(intermediate, APPLE_ROOT_CERTIFICATES[0], 'intermediate');
  await assertSignedBy(leaf, new Uint8Array(Buffer.from(chain[1], 'base64')), 'leaf');
  if (!hasExtension(intermediate, INTERMEDIATE_OID)) {
    throw new AppleIapError('intermediate certificate is missing the Apple WWDR OID', 'VERIFICATION_FAILURE');
  }
  if (!hasExtension(leaf, LEAF_OID)) {
    throw new AppleIapError('leaf certificate is missing the Apple IAP OID', 'VERIFICATION_FAILURE');
  }

  const leafDer = new Uint8Array(Buffer.from(chain[0], 'base64'));
  let payload: Record<string, unknown>;
  try {
    const key = await importX509(derToPem(leafDer), 'ES256');
    const verified = await jwtVerify(jws, key, { algorithms: ['ES256'] });
    payload = JSON.parse(JSON.stringify(verified.payload)) as Record<string, unknown>;
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    throw new AppleIapError(`JWS signature rejected: ${message}`, 'VERIFICATION_FAILURE');
  }

  const signedAt = typeof payload.signedDate === 'number' ? new Date(payload.signedDate) : new Date();
  checkDates(root, signedAt, 'root');
  checkDates(intermediate, signedAt, 'intermediate');
  checkDates(leaf, signedAt, 'leaf');
  return payload;
}
