"use client";
import { useEffect, useState } from "react";
import { createClient } from "@supabase/supabase-js";

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || ""
);

interface CreditEntry {
  id: string;
  user_id: string;
  amount: number;
  reason_code: string;
  description: string | null;
  created_at: string;
}

export default function CreditsPage() {
  const [entries, setEntries] = useState<CreditEntry[]>([]);
  const [loading, setLoading] = useState(true);
  const [profileMap, setProfileMap] = useState<Record<string, string>>({});

  useEffect(() => {
    const fetchData = async () => {
      setLoading(true);
      const { data: ledger } = await supabase
        .from("credits_ledger")
        .select("*")
        .order("created_at", { ascending: false })
        .limit(100);
      if (ledger) setEntries(ledger);

      // Fetch profile names for display
      const { data: profiles } = await supabase
        .from("profiles")
        .select("id, display_name");
      if (profiles) {
        const map: Record<string, string> = {};
        for (const p of profiles) {
          map[p.id] = p.display_name || p.id.slice(0, 8);
        }
        setProfileMap(map);
      }
      setLoading(false);
    };
    fetchData();
  }, []);

  const formatDate = (iso: string) => {
    const d = new Date(iso);
    return d.toLocaleString("tr-TR", {
      day: "2-digit", month: "short", year: "numeric",
      hour: "2-digit", minute: "2-digit"
    });
  };

  const reasonLabel = (code: string) => {
    const labels: Record<string, string> = {
      "admin_grant": "Admin Hibe",
      "admin_correction": "Düzeltme",
      "signup_bonus": "Kayıt Bonusu",
      "refund": "İade",
      "bonus": "Bonus",
      "penalty": "Ceza",
      "generation_spend": "Kullanım",
      "purchase": "Satın Alma",
    };
    return labels[code] || code;
  };

  const reasonBadge = (code: string) => {
    if (code.includes("grant") || code.includes("bonus") || code === "signup_bonus") return "badge-green";
    if (code.includes("refund")) return "badge-cyan";
    if (code.includes("penalty") || code.includes("spend")) return "badge-red";
    if (code.includes("purchase")) return "badge-purple";
    return "badge-accent";
  };

  return (
    <div>
      <div className="page-header">
        <div>
          <h1 className="page-title">Kredi İşlemleri</h1>
          <p className="page-subtitle">Son 100 kredi hareketi • credits_ledger tablosu</p>
        </div>
      </div>

      {loading ? (
        <div className="empty-state">
          <span className="material-symbols-rounded">hourglass_top</span>
          <p>Yükleniyor...</p>
        </div>
      ) : entries.length === 0 ? (
        <div className="empty-state">
          <span className="material-symbols-rounded">account_balance</span>
          <p>Henüz kredi hareketi yok</p>
        </div>
      ) : (
        <table className="data-table">
          <thead>
            <tr>
              <th>Tarih</th>
              <th>Kullanıcı</th>
              <th>Miktar</th>
              <th>Sebep</th>
              <th>Açıklama</th>
            </tr>
          </thead>
          <tbody>
            {entries.map((e) => (
              <tr key={e.id}>
                <td style={{ fontSize: 11, color: "var(--text-muted)", whiteSpace: "nowrap" }}>
                  {formatDate(e.created_at)}
                </td>
                <td>
                  <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
                    <div className="user-avatar" style={{ width: 28, height: 28, fontSize: 11 }}>
                      {(profileMap[e.user_id] || "?")[0].toUpperCase()}
                    </div>
                    <span style={{ fontSize: 12, fontWeight: 600 }}>{profileMap[e.user_id] || e.user_id.slice(0, 8)}</span>
                  </div>
                </td>
                <td>
                  <span style={{
                    fontWeight: 800, fontSize: 14,
                    color: e.amount > 0 ? "var(--green)" : "var(--red)",
                  }}>
                    {e.amount > 0 ? "+" : ""}{e.amount}
                  </span>
                </td>
                <td>
                  <span className={`badge ${reasonBadge(e.reason_code)}`}>
                    {reasonLabel(e.reason_code)}
                  </span>
                </td>
                <td style={{ fontSize: 12, color: "var(--text-secondary)", maxWidth: 300 }}>
                  {e.description || "—"}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </div>
  );
}
