import Link from "next/link";
import { PublicShell } from "@/components/public-shell";
import { site } from "@/lib/site";

const perm = site.permissions.find((p) => p.slug === "asset-write")!;

export default function AssetWritePermissionPage() {
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
            The <code>asset:write</code> scope lets {site.appName} upload or
            update clothing and related creator assets on Roblox when you start an
            approved publish or update flow.
          </p>
        </section>
        <section>
          <h2>What we do with it</h2>
          <ul>
            <li>Upload assets you generate or edit in the app, after you confirm.</li>
            <li>Update asset payloads through server-side Open Cloud workflows.</li>
            <li>
              Keep Roblox tokens and keys on the backend for rate limiting and
              policy checks.
            </li>
          </ul>
        </section>
      </article>
    </PublicShell>
  );
}
