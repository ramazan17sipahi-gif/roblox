import React from "react";

function renderInline(text: string): React.ReactNode[] {
  const nodes: React.ReactNode[] = [];
  const re = /(\*\*[^*]+\*\*|\[([^\]]+)\]\(([^)]+)\))/g;
  let last = 0;
  let match: RegExpExecArray | null;
  let key = 0;

  while ((match = re.exec(text)) !== null) {
    if (match.index > last) {
      nodes.push(text.slice(last, match.index));
    }
    const token = match[0];
    if (token.startsWith("**")) {
      nodes.push(<strong key={key++}>{token.slice(2, -2)}</strong>);
    } else {
      nodes.push(
        <a key={key++} href={match[3]} target="_blank" rel="noreferrer">
          {match[2]}
        </a>
      );
    }
    last = match.index + token.length;
  }

  if (last < text.length) nodes.push(text.slice(last));
  return nodes;
}

function isTableSeparator(line: string) {
  return /^\|?\s*:?-+:?\s*(\|\s*:?-+:?\s*)+\|?$/.test(line.trim());
}

function parseTableRow(line: string) {
  return line
    .trim()
    .replace(/^\|/, "")
    .replace(/\|$/, "")
    .split("|")
    .map((cell) => cell.trim());
}

export function LegalMarkdown({ source }: { source: string }) {
  const lines = source.replace(/\r\n/g, "\n").split("\n");
  const blocks: React.ReactNode[] = [];
  let i = 0;
  let key = 0;

  while (i < lines.length) {
    const line = lines[i];
    const trimmed = line.trim();

    if (!trimmed) {
      i += 1;
      continue;
    }

    if (trimmed.startsWith("### ")) {
      blocks.push(<h3 key={key++}>{renderInline(trimmed.slice(4))}</h3>);
      i += 1;
      continue;
    }

    if (trimmed.startsWith("## ")) {
      blocks.push(<h2 key={key++}>{renderInline(trimmed.slice(3))}</h2>);
      i += 1;
      continue;
    }

    if (trimmed.startsWith("# ")) {
      blocks.push(<h1 key={key++}>{renderInline(trimmed.slice(2))}</h1>);
      i += 1;
      continue;
    }

    if (trimmed.startsWith("- ")) {
      const items: React.ReactNode[] = [];
      while (i < lines.length && lines[i].trim().startsWith("- ")) {
        items.push(
          <li key={key++}>{renderInline(lines[i].trim().slice(2))}</li>
        );
        i += 1;
      }
      blocks.push(<ul key={key++}>{items}</ul>);
      continue;
    }

    if (trimmed.startsWith("|") && i + 1 < lines.length && isTableSeparator(lines[i + 1])) {
      const headers = parseTableRow(trimmed);
      i += 2;
      const rows: string[][] = [];
      while (i < lines.length && lines[i].trim().startsWith("|")) {
        rows.push(parseTableRow(lines[i]));
        i += 1;
      }
      blocks.push(
        <div className="legal-table-wrap" key={key++}>
          <table className="legal-table">
            <thead>
              <tr>
                {headers.map((h, idx) => (
                  <th key={idx}>{renderInline(h)}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {rows.map((row, rIdx) => (
                <tr key={rIdx}>
                  {row.map((cell, cIdx) => (
                    <td key={cIdx}>{renderInline(cell)}</td>
                  ))}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      );
      continue;
    }

    const para: string[] = [trimmed];
    i += 1;
    while (
      i < lines.length &&
      lines[i].trim() &&
      !lines[i].trim().startsWith("#") &&
      !lines[i].trim().startsWith("- ") &&
      !lines[i].trim().startsWith("|")
    ) {
      para.push(lines[i].trim());
      i += 1;
    }
    blocks.push(<p key={key++}>{renderInline(para.join(" "))}</p>);
  }

  return <div className="legal-markdown">{blocks}</div>;
}
