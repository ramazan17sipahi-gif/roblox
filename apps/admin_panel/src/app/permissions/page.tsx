import Link from "next/link";
import { PublicShell } from "@/components/public-shell";
import { site } from "@/lib/site";

export default function PermissionsIndexPage() {
  return (
    <PublicShell>
      <article className="public-article">
        <h1>OAuth Permissions</h1>
        <p className="lede">
          {site.appName} requests only the Roblox OAuth scopes needed for
          secure sign-in and approved creator workflows. Each scope is explained
          on its own page.
        </p>
        <ul className="perm-list">
          {site.permissions.map((p) => (
            <li key={p.slug}>
              <Link href={`/permissions/${p.slug}`}>
                <strong>{p.scope}</strong>
              </Link>
              <span> — {p.summary}</span>
            </li>
          ))}
        </ul>
      </article>
    </PublicShell>
  );
}
