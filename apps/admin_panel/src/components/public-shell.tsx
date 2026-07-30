import Link from "next/link";
import { site } from "@/lib/site";

export function PublicShell({
  children,
  landing = false,
}: {
  children: React.ReactNode;
  landing?: boolean;
}) {
  return (
    <div className={`public-shell${landing ? " is-landing" : ""}`}>
      <header className="public-header">
        <Link href="/" className="public-brand">
          <span className="public-brand-mark">RBLX</span>
          <span className="public-brand-rest">Clothing Maker</span>
        </Link>
        <nav className="public-nav">
          <Link href="/permissions">Permissions</Link>
          <Link href="/privacy">Privacy</Link>
          <Link href="/terms">Terms</Link>
          <a
            className="public-nav-cta"
            href={site.playStoreUrl}
            target="_blank"
            rel="noreferrer"
          >
            Play Store
          </a>
        </nav>
      </header>
      <main className={landing ? "public-main-landing" : "public-main"}>
        {children}
      </main>
      <footer className="public-footer">
        <p>
          {site.appName} is not affiliated with or endorsed by Roblox.
        </p>
        <p>
          Support:{" "}
          <a href={`mailto:${site.supportEmail}`}>{site.supportEmail}</a>
        </p>
      </footer>
    </div>
  );
}

export function LinkField({
  label,
  href,
}: {
  label: string;
  href: string;
}) {
  return (
    <div className="link-field">
      <div className="link-field-label">{label}</div>
      <a className="link-field-value" href={href} target="_blank" rel="noreferrer">
        {href}
      </a>
    </div>
  );
}
