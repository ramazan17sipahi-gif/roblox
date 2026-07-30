"use client";
import { useEffect, useState } from "react";
import { createClient } from "@supabase/supabase-js";

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || ""
);

interface Profile {
  id: string;
  display_name: string | null;
  avatar_url: string | null;
  tier_code: string | null;
  created_at: string;
}

interface CreditBalance {
  userId: string;
  total: number;
}

export default function UsersPage() {
  const [profiles, setProfiles] = useState<Profile[]>([]);
  const [creditMap, setCreditMap] = useState<Record<string, number>>({});
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState("");
  const [selectedUser, setSelectedUser] = useState<Profile | null>(null);
  const [creditAmount, setCreditAmount] = useState(0);
  const [creditReason, setCreditReason] = useState("admin_grant");
  const [showCreditModal, setShowCreditModal] = useState(false);

  const fetchUsers = async () => {
    setLoading(true);
    const { data } = await supabase
      .from("profiles")
      .select("*")
      .order("created_at", { ascending: false });
    if (data) setProfiles(data);

    // Fetch credit balances
    const { data: credits } = await supabase
      .from("credits_ledger")
      .select("user_id, amount");
    if (credits) {
      const map: Record<string, number> = {};
      for (const c of credits) {
        const uid = c.user_id as string;
        map[uid] = (map[uid] || 0) + (c.amount as number);
      }
      setCreditMap(map);
    }

    setLoading(false);
  };

  useEffect(() => { fetchUsers(); }, []);

  const filtered = profiles.filter((p) => {
    if (!search.trim()) return true;
    const q = search.toLowerCase();
    return (
      (p.display_name || "").toLowerCase().includes(q) ||
      p.id.toLowerCase().includes(q)
    );
  });

  const handleAddCredit = async () => {
    if (!selectedUser || creditAmount === 0) return;
    await supabase.from("credits_ledger").insert({
      user_id: selectedUser.id,
      amount: creditAmount,
      reason_code: creditReason,
      description: `Admin tarafından ${creditAmount > 0 ? "eklendi" : "çıkarıldı"}: ${creditReason}`,
    });
    setShowCreditModal(false);
    setCreditAmount(0);
    fetchUsers();
  };

  const tierBadge = (tier: string | null) => {
    switch (tier) {
      case "pro": return "badge-purple";
      case "premium": return "badge-yellow";
      case "enterprise": return "badge-accent";
      default: return "badge-cyan";
    }
  };

  const formatDate = (iso: string) => {
    const d = new Date(iso);
    return d.toLocaleDateString("tr-TR", { day: "2-digit", month: "short", year: "numeric" });
  };

  return (
    <div>
      <div className="page-header">
        <div>
          <h1 className="page-title">Üye Yönetimi</h1>
          <p className="page-subtitle">Kullanıcı profilleri, kredi bakiyeleri ve yönetim</p>
        </div>
        <div style={{ display: "flex", gap: 8, alignItems: "center" }}>
          <div style={{ position: "relative" }}>
            <span className="material-symbols-rounded" style={{
              position: "absolute", left: 12, top: "50%", transform: "translateY(-50%)",
              fontSize: 18, color: "var(--text-muted)"
            }}>search</span>
            <input
              className="form-input"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="İsim veya ID ile ara..."
              style={{ paddingLeft: 38, width: 280 }}
            />
          </div>
        </div>
      </div>

      {/* Credit Modal */}
      {showCreditModal && selectedUser && (
        <div className="form-card">
          <h3 style={{ fontSize: 16, fontWeight: 800, marginBottom: 16, display: "flex", alignItems: "center", gap: 8 }}>
            <span className="material-symbols-rounded" style={{ fontSize: 20, color: "var(--green)" }}>monetization_on</span>
            Kredi İşlemi — {selectedUser.display_name || selectedUser.id.slice(0, 8)}
          </h3>
          <div style={{ display: "flex", gap: 12, marginBottom: 12 }}>
            <div style={{ display: "flex", alignItems: "center", gap: 8, padding: "8px 14px", background: "var(--bg-elevated)", borderRadius: 8 }}>
              <span className="material-symbols-rounded" style={{ fontSize: 16, color: "var(--text-muted)" }}>account_balance_wallet</span>
              <span style={{ fontSize: 12, color: "var(--text-muted)" }}>Mevcut:</span>
              <span style={{ fontSize: 14, fontWeight: 800, color: "var(--green)" }}>{creditMap[selectedUser.id] || 0}</span>
            </div>
          </div>
          <div className="form-grid">
            <div>
              <label className="form-label">Miktar</label>
              <input
                className="form-input"
                type="number"
                value={creditAmount}
                onChange={(e) => setCreditAmount(Number(e.target.value))}
                placeholder="Pozitif = ekle, negatif = çıkar"
              />
            </div>
            <div>
              <label className="form-label">Sebep</label>
              <select className="form-select" value={creditReason} onChange={(e) => setCreditReason(e.target.value)}>
                <option value="admin_grant">Admin Hibe</option>
                <option value="admin_correction">Düzeltme</option>
                <option value="refund">İade</option>
                <option value="bonus">Bonus</option>
                <option value="penalty">Ceza (Negatif)</option>
              </select>
            </div>
          </div>
          <div className="form-actions">
            <button className="btn btn-success" onClick={handleAddCredit} disabled={creditAmount === 0}>
              <span className="material-symbols-rounded" style={{ fontSize: 16 }}>add_card</span>
              {creditAmount >= 0 ? `+${creditAmount} Kredi Ekle` : `${creditAmount} Kredi Çıkar`}
            </button>
            <button className="btn btn-secondary" onClick={() => setShowCreditModal(false)}>İptal</button>
          </div>
        </div>
      )}

      {loading ? (
        <div className="empty-state">
          <span className="material-symbols-rounded">hourglass_top</span>
          <p>Kullanıcılar yükleniyor...</p>
        </div>
      ) : filtered.length === 0 ? (
        <div className="empty-state">
          <span className="material-symbols-rounded">person_off</span>
          <p>Kullanıcı bulunamadı</p>
        </div>
      ) : (
        <table className="data-table">
          <thead>
            <tr>
              <th>Kullanıcı</th>
              <th>ID</th>
              <th>Tier</th>
              <th>Kredi</th>
              <th>Kayıt Tarihi</th>
              <th>İşlemler</th>
            </tr>
          </thead>
          <tbody>
            {filtered.map((p) => (
              <tr key={p.id}>
                <td>
                  <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
                    {p.avatar_url ? (
                      <img
                        src={p.avatar_url}
                        style={{ width: 36, height: 36, borderRadius: "50%", objectFit: "cover" }}
                        alt=""
                      />
                    ) : (
                      <div className="user-avatar">
                        {(p.display_name || "?")[0].toUpperCase()}
                      </div>
                    )}
                    <div>
                      <div style={{ fontWeight: 700, fontSize: 13 }}>{p.display_name || "İsimsiz"}</div>
                    </div>
                  </div>
                </td>
                <td>
                  <code style={{ fontSize: 10, color: "var(--text-muted)", background: "var(--bg-elevated)", padding: "2px 6px", borderRadius: 4 }}>
                    {p.id.slice(0, 8)}...
                  </code>
                </td>
                <td>
                  <span className={`badge ${tierBadge(p.tier_code)}`}>
                    {p.tier_code || "free"}
                  </span>
                </td>
                <td>
                  <span style={{ fontWeight: 700, color: (creditMap[p.id] || 0) > 0 ? "var(--green)" : "var(--text-muted)" }}>
                    {creditMap[p.id] || 0}
                  </span>
                </td>
                <td style={{ fontSize: 12, color: "var(--text-muted)" }}>
                  {formatDate(p.created_at)}
                </td>
                <td>
                  <div style={{ display: "flex", gap: 6 }}>
                    <button
                      className="btn btn-success btn-sm"
                      onClick={() => { setSelectedUser(p); setShowCreditModal(true); setCreditAmount(0); }}
                    >
                      <span className="material-symbols-rounded" style={{ fontSize: 14 }}>add_card</span>
                      Kredi
                    </button>
                    <button className="btn btn-secondary btn-sm" onClick={() => {
                      navigator.clipboard.writeText(p.id);
                    }}>
                      <span className="material-symbols-rounded" style={{ fontSize: 14 }}>content_copy</span>
                    </button>
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </div>
  );
}
