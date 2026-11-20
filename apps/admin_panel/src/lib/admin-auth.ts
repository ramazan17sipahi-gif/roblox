import { createHash, createHmac, randomBytes, timingSafeEqual } from "node:crypto";
import { NextResponse, type NextRequest } from "next/server";

export const ADMIN_LOGIN_PATH = "/admin-login";
export const ADMIN_COOKIE = process.env.NODE_ENV === "production"
  ? "__Host-rblx_admin_session"
  : "rblx_admin_session";
export const ADMIN_SESSION_SECONDS = 8 * 60 * 60;
export const adminCookieOptions = {
  httpOnly: true,
  secure: process.env.NODE_ENV === "production",
  sameSite: "strict",
  path: "/",
} as const;

export function getAdminPassword() {
  const password = process.env.ADMIN_PANEL_PASSWORD;
  return password && password.trim().length >= 24 && password.length <= 1024 ? password : undefined;
}

export function matchesAdminPassword(candidate: string, expected: string) {
  if (candidate.length > 1024) return false;
  const digest = (value: string) => createHash("sha256").update(value).digest();
  return timingSafeEqual(digest(candidate), digest(expected));
}

function signSession(payload: string, password: string) {
  return createHmac("sha256", password)
    .update(`rblx-admin-session-v1:${payload}`)
    .digest("base64url");
}

export function createAdminSession(password: string) {
  const expires = Math.floor(Date.now() / 1000) + ADMIN_SESSION_SECONDS;
  const payload = `${expires}.${randomBytes(16).toString("hex")}`;
  return `${payload}.${signSession(payload, password)}`;
}

export function hasAdminSession(value: string | undefined) {
  const password = getAdminPassword();
  if (!password || !value) return false;

  const match = /^(\d{10})\.([a-f0-9]{32})\.([A-Za-z0-9_-]{43})$/.exec(value);
  if (!match) return false;
  const [, expiry, nonce, signature] = match;
  if (Number(expiry) <= Math.floor(Date.now() / 1000)) return false;

  const expected = signSession(`${expiry}.${nonce}`, password);
  return timingSafeEqual(Buffer.from(signature), Buffer.from(expected));
}

export function adminApiFailure(request: NextRequest) {
  const headers = { "Cache-Control": "private, no-store" };
  if (!hasAdminSession(request.cookies.get(ADMIN_COOKIE)?.value)) {
    return NextResponse.json({ error: "Yönetici girişi gerekli." }, { status: 401, headers });
  }

  if (request.method !== "GET" && request.method !== "HEAD") {
    const origin = request.headers.get("origin");
    const site = request.headers.get("sec-fetch-site");
    if ((origin && origin !== request.nextUrl.origin) || (site && site !== "same-origin" && site !== "none")) {
      return NextResponse.json({ error: "Bu istek kabul edilmedi." }, { status: 403, headers });
    }
  }

  return null;
}
