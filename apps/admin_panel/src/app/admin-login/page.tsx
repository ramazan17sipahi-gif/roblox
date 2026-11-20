import type { Metadata } from "next";
import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import { ADMIN_COOKIE, getAdminPassword, hasAdminSession } from "@/lib/admin-auth";
import { signIn } from "./actions";
import styles from "./page.module.css";

export const metadata: Metadata = {
  title: "Yönetici girişi | RBLX Clothing Maker",
  robots: { index: false, follow: false },
};

export default async function AdminLoginPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string }>;
}) {
  if (hasAdminSession((await cookies()).get(ADMIN_COOKIE)?.value)) redirect("/admin");

  const { error } = await searchParams;
  const available = Boolean(getAdminPassword());

  return (
    <main className={styles.screen} lang="tr">
      <section className={`form-card ${styles.card}`} aria-labelledby="admin-login-title">
        <h1 className="page-title" id="admin-login-title">Yönetici girişi</h1>
        {!available ? (
          <p role="status">Yönetici parolası henüz yapılandırılmamış.</p>
        ) : (
          <form action={signIn} className={styles.form}>
            <div className={styles.field}>
              <label className="form-label" htmlFor="admin-password">Parola</label>
              <input
                className="form-input"
                id="admin-password"
                name="password"
                type="password"
                autoComplete="current-password"
                maxLength={1024}
                required
                aria-invalid={error === "invalid" || undefined}
                aria-describedby={error === "invalid" ? "admin-login-error" : undefined}
              />
            </div>
            {error === "invalid" && <p id="admin-login-error" role="alert">Parola hatalı.</p>}
            <button className="btn btn-primary" type="submit">Giriş yap</button>
          </form>
        )}
      </section>
    </main>
  );
}
