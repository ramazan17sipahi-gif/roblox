import Link from "next/link";
import { PublicShell } from "@/components/public-shell";
import { site } from "@/lib/site";

const perm = site.permissions.find((p) => p.slug === "openid")!;

export default function OpenIdPermissionPage() {
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
            The <code>openid</code> scope lets {site.appName} complete a
            standards-based OpenID Connect login with Roblox. It confirms who
            you are without asking you to type your Roblox password into the
            app.
          </p>
        </section>
        <section>
          <h2>What we do with it</h2>
          <ul>
            <li>Establish a secure sign-in session after Roblox consent.</li>
            <li>Link your Roblox identity to your app account on our backend.</li>
            <li>Never store your Roblox password.</li>
          </ul>
        </section>
      </article>
    </PublicShell>
  );
}
