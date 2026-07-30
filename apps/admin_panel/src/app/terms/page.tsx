import { readFileSync } from "fs";
import path from "path";
import { PublicShell } from "@/components/public-shell";
import { LegalMarkdown } from "@/components/legal-markdown";
import { site } from "@/lib/site";

const source = readFileSync(
  path.join(process.cwd(), "src/content/terms-of-service.md"),
  "utf8"
);

export default function TermsPage() {
  return (
    <PublicShell>
      <article className="public-article legal-page">
        <h1>Terms of Service</h1>
        <p className="lede">
          Full Terms of Service for {site.appName}.
        </p>
        <p className="meta">
          Public URL:{" "}
          <a href={site.termsUrl} target="_blank" rel="noreferrer">
            {site.termsUrl}
          </a>
        </p>
        <LegalMarkdown source={source} />
      </article>
    </PublicShell>
  );
}
