import Link from "next/link";
import { LinkField, PublicShell } from "@/components/public-shell";
import { site } from "@/lib/site";

export default function LandingPage() {
  return (
    <PublicShell landing>
      <section className="landing-hero" aria-label="Hero">
        <div className="landing-hero-copy">
          <p className="landing-brand">{site.appName}</p>
          <h1 className="landing-headline">
            Design UGC clothing.
            <br />
            Connect. Preview. Ship.
          </h1>
          <p className="landing-support">
            A mobile creator companion for generating, previewing, and managing
            Roblox clothing assets through a secure server-side integration.
          </p>
          <div className="landing-cta-row">
            <a
              className="landing-cta landing-cta-primary"
              href={site.playStoreUrl}
              target="_blank"
              rel="noreferrer"
            >
              Get it on Google Play
            </a>
            <Link className="landing-cta landing-cta-ghost" href="/permissions">
              View permissions
            </Link>
          </div>
        </div>
        <div className="landing-hero-visual" aria-hidden="true">
          <div className="landing-fabric">
            <svg className="landing-garment" viewBox="0 0 420 520" fill="none">
              <path
                className="garment-body"
                d="M210 48c28 0 48 10 62 28l54 18 36 92-48 18-10-28v268c0 18-14 32-32 32H158c-18 0-32-14-32-32V176l-10 28-48-18 36-92 54-18c14-18 34-28 62-28Z"
              />
              <path
                className="garment-stitch"
                d="M158 210h104M158 260h104M158 310h104M158 360h104"
                strokeDasharray="4 8"
              />
              <circle className="garment-pin" cx="210" cy="120" r="6" />
              <path
                className="garment-collar"
                d="M176 92c12 18 22 26 34 26s22-8 34-26"
              />
            </svg>
            <div className="landing-fabric-grid" />
          </div>
        </div>
      </section>

      <div className="landing-body">
        <section className="landing-section">
          <h2>What the app offers</h2>
          <p className="landing-section-lead">
            Built for Roblox creators who want generation, preview, and
            approved UGC workflows in one place.
          </p>
          <ul className="landing-feature-list">
            <li>
              <span className="landing-feature-label">Generate</span>
              AI-assisted clothing and accessory assets from prompts and
              reference images.
            </li>
            <li>
              <span className="landing-feature-label">Connect</span>
              Roblox account linking through OAuth 2.0 + PKCE on
              Roblox-controlled pages.
            </li>
            <li>
              <span className="landing-feature-label">Preview</span>
              Avatar fitting and secure handoff into a Roblox preview place for
              supported assets.
            </li>
            <li>
              <span className="landing-feature-label">Publish</span>
              Creator-side asset sync and approved Open Cloud workflows via a
              backend-for-frontend architecture.
            </li>
          </ul>
        </section>

        <section className="landing-section">
          <h2>Security boundaries</h2>
          <p>
            Roblox access tokens, Open Cloud keys, and validation live on the
            backend — not in the mobile app. That enables rate limiting, audit
            trails, safer token storage, and policy enforcement.
          </p>
          <p>
            {site.appName} never asks for your Roblox password. Sign-in happens
            on Roblox pages; the app only receives approved OAuth results.
          </p>
        </section>

        <section className="landing-section">
          <h2>Platform boundaries</h2>
          <p>
            Subscriptions and credits use supported mobile storefront flows
            where applicable. Asset approval, moderation, pricing, and creator
            eligibility remain subject to Roblox rules and can change
            independently of this app.
          </p>
          <p className="landing-disclaimer">
            Operated by {site.appName}. Not affiliated with or endorsed by
            Roblox.
          </p>
        </section>

        <section className="landing-section">
          <h2>Support &amp; compliance</h2>
          <p className="landing-section-lead">
            Official store and policy URLs for reviews, OAuth setup, and store
            listings.
          </p>
          <div className="link-fields">
            <LinkField label="Google Play Store URL" href={site.playStoreUrl} />
            <LinkField label="Privacy Policy URL" href={site.privacyUrl} />
            <LinkField label="Terms of Service URL" href={site.termsUrl} />
          </div>
          <p className="meta">
            Site: <a href={site.siteUrl}>{site.siteUrl}</a> ·{" "}
            <Link href="/permissions">Permissions</Link>
          </p>
          <p>
            Support:{" "}
            <a href={`mailto:${site.supportEmail}`}>{site.supportEmail}</a>
          </p>
        </section>

        <section className="landing-section">
          <h2>Roblox OAuth</h2>
          <p className="landing-section-lead">
            Suggested description for the Roblox OAuth app portal. Scopes:{" "}
            <code>openid, profile, asset:read, asset:write</code>.
          </p>
          <pre className="code-block">{site.oauthDescription}</pre>
          <p className="meta">
            Last updated {site.lastUpdated}. Each permission has its own page
            under <Link href="/permissions">/permissions</Link>.
          </p>
        </section>
      </div>
    </PublicShell>
  );
}
