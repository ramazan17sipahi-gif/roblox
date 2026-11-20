import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import { AdminChrome } from "@/components/admin-shell";
import { ADMIN_COOKIE, ADMIN_LOGIN_PATH, hasAdminSession } from "@/lib/admin-auth";

export const dynamic = "force-dynamic";

export default async function AdminLayout({ children }: { children: React.ReactNode }) {
  if (!hasAdminSession((await cookies()).get(ADMIN_COOKIE)?.value)) {
    redirect(ADMIN_LOGIN_PATH);
  }
  return <AdminChrome>{children}</AdminChrome>;
}
