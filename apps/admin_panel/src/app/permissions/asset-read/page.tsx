import Link from "next/link";
import { PublicShell } from "@/components/public-shell";
import { site } from "@/lib/site";

const perm = site.permissions.find((p) => p.slug === "asset-read")!;

export default function AssetReadPermissionPage() {
  return (
    <PublicShell>
      <article className="public-article">
        <p className="meta">
          <Link href="/permissions">← All permissions</Link>
        </p>
        <h1>{perm.title}</h1>
        <p className="scope-badge">
          Scope: <code>{perm.scope}</code>
        </p>
        <p className="lede">{perm.summary}</p>
        <section>
          <h2>Why we ask for this</h2>
          <p>
            The <code>asset:read</code> scope lets our backend read asset
            metadata for items you choose to manage or preview through{" "}
            {site.appName}, so creator workflows can stay in sync with Roblox.
          </p>
        </section>
        <section>
          <h2>What we do with it</h2>
          <ul>
            <li>Fetch asset details needed for preview and sync flows.</li>
            <li>Show status for items you already own or create in the app.</li>
            <li>Run these calls on the server — not with secrets in the mobile client.</li>
          </ul>
        </section>
      </article>
    </PublicShell>
  );
}
