import { NextResponse, type NextRequest } from "next/server";
import { ADMIN_COOKIE, ADMIN_LOGIN_PATH, adminApiFailure, hasAdminSession } from "@/lib/admin-auth";

export function proxy(request: NextRequest) {
  const path = request.nextUrl.pathname;
  if (path === "/api/admin" || path.startsWith("/api/admin/")) {
    const failure = adminApiFailure(request);
    if (failure) return failure;
  } else if (!hasAdminSession(request.cookies.get(ADMIN_COOKIE)?.value)) {
    const response = NextResponse.redirect(new URL(ADMIN_LOGIN_PATH, request.url), 303);
    response.headers.set("Cache-Control", "private, no-store");
    return response;
  }

  const response = NextResponse.next();
  response.headers.set("Cache-Control", "private, no-store");
  return response;
}

export const config = {
  matcher: ["/admin/:path*", "/api/admin/:path*"],
};
