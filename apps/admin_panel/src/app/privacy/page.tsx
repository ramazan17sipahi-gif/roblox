import { readFileSync } from "fs";
import path from "path";
import { PublicShell } from "@/components/public-shell";
import { LegalMarkdown } from "@/components/legal-markdown";
import { site } from "@/lib/site";

const source = readFileSync(
  path.join(process.cwd(), "src/content/privacy-policy.md"),
  "utf8"
);

export default function PrivacyPage() {
  return (
    <PublicShell>
      <article className="public-article legal-page">
        <h1>Privacy Policy</h1>
        <p className="lede">
          Full Privacy Policy for {site.appName}.
        </p>
        <p className="meta">
          Public URL:{" "}
          <a href={site.privacyUrl} target="_blank" rel="noreferrer">
            {site.privacyUrl}
          </a>
        </p>
        <LegalMarkdown source={source} />
      </article>
    </PublicShell>
  );
}
