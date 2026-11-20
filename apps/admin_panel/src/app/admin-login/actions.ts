"use server";

import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import {
  ADMIN_COOKIE,
  ADMIN_LOGIN_PATH,
  ADMIN_SESSION_SECONDS,
  adminCookieOptions,
  createAdminSession,
  getAdminPassword,
  matchesAdminPassword,
} from "@/lib/admin-auth";

export async function signIn(formData: FormData) {
  const expected = getAdminPassword();
  if (!expected) redirect(`${ADMIN_LOGIN_PATH}?error=unavailable`);

  const password = formData.get("password");
  if (typeof password !== "string" || !matchesAdminPassword(password, expected)) {
    redirect(`${ADMIN_LOGIN_PATH}?error=invalid`);
  }

  (await cookies()).set(ADMIN_COOKIE, createAdminSession(expected), {
    ...adminCookieOptions,
    maxAge: ADMIN_SESSION_SECONDS,
  });
  redirect("/admin");
}

export async function signOut() {
  (await cookies()).set(ADMIN_COOKIE, "", { ...adminCookieOptions, maxAge: 0 });
  redirect(ADMIN_LOGIN_PATH);
}
