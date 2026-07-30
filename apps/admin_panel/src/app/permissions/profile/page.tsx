import Link from "next/link";
import { PublicShell } from "@/components/public-shell";
import { site } from "@/lib/site";

const perm = site.permissions.find((p) => p.slug === "profile")!;

export default function ProfilePermissionPage() {
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
            The <code>profile</code> scope lets {site.appName} show your Roblox
            username, display name, and avatar when you connect your account —
            so previews and creator tools feel tied to the right identity.
          </p>
        </section>
        <section>
          <h2>What we do with it</h2>
          <ul>
            <li>Display your Roblox profile details inside the app.</li>
            <li>Help you confirm the correct account was linked.</li>
            <li>Support avatar-related preview experiences you start yourself.</li>
          </ul>
        </section>
      </article>
    </PublicShell>
  );
}
