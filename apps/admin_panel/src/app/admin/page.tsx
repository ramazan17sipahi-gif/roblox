"use client";
import { useEffect, useState } from "react";
import { createClient } from "@supabase/supabase-js";

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || ""
);

interface Stats {
  templates: number;
  categories: number;
  stickers: number;
  users: number;
}

export default function DashboardPage() {
  const [stats, setStats] = useState<Stats>({ templates: 0, categories: 0, stickers: 0, users: 0 });
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchStats = async () => {
      const [tpl, cat, stk, usr] = await Promise.all([
        supabase.from("clothing_templates").select("id", { count: "exact", head: true }),
        supabase.from("sticker_categories").select("id", { count: "exact", head: true }),
        supabase.from("stickers").select("id", { count: "exact", head: true }),
        supabase.from("profiles").select("id", { count: "exact", head: true }),
      ]);
      setStats({
        templates: tpl.count ?? 0,
        categories: cat.count ?? 0,
        stickers: stk.count ?? 0,
        users: usr.count ?? 0,
      });
      setLoading(false);
    };
    fetchStats();
  }, []);

  return (
    <div>
      <div className="page-header">
        <div>
          <h1 className="page-title">Dashboard</h1>
          <p className="page-subtitle">RBLX Clothing Maker yönetim paneli genel bakış</p>
        </div>
      </div>

      <div className="stat-grid">
        <StatCard
          icon="checkroom"
          label="Kıyafet Şablonları"
          value={loading ? "—" : String(stats.templates)}
          color="var(--purple)"
          bg="var(--purple-soft)"
        />
        <StatCard
          icon="category"
          label="Sticker Kategorileri"
          value={loading ? "—" : String(stats.categories)}
          color="var(--accent)"
          bg="var(--accent-soft)"
        />
        <StatCard
          icon="star"
          label="Toplam Sticker"
          value={loading ? "—" : String(stats.stickers)}
          color="var(--cyan)"
          bg="var(--cyan-soft)"
        />
        <StatCard
          icon="group"
          label="Kayıtlı Üyeler"
          value={loading ? "—" : String(stats.users)}
          color="var(--green)"
          bg="var(--green-soft)"
        />
      </div>

      {/* Quick Actions */}
      <h3 className="section-title">Hızlı İşlemler</h3>
      <div className="quick-actions-grid">
        <QuickAction href="/admin/templates" icon="add_circle" title="Yeni Şablon Ekle" subtitle="Kıyafet şablonu oluştur" />
        <QuickAction href="/admin/stickers" icon="palette" title="Sticker Yönet" subtitle="Kategori ve sticker düzenle" />
        <QuickAction href="/admin/users" icon="person_search" title="Üye Ara" subtitle="Kullanıcı bilgilerini görüntüle" />
      </div>

      <div className="info-banner" style={{ marginTop: 32 }}>
        <span className="material-symbols-rounded">cloud_sync</span>
        <div>
          <strong>Canlı içerik akışı</strong>
          <p>
            Admin panelden eklediğiniz <strong>aktif</strong> şablonlar ve stickerlar Supabase üzerinden
            mobil uygulamaya otomatik yansır. Ayrı uygulama güncellemesi gerekmez.
          </p>
        </div>
      </div>
    </div>
  );
}

function StatCard({ icon, label, value, color, bg }: {
  icon: string; label: string; value: string; color: string; bg: string;
}) {
  return (
    <div className="stat-card">
      <div className="stat-icon-wrap" style={{ background: bg }}>
        <span className="material-symbols-rounded" style={{ color }}>{icon}</span>
      </div>
      <div>
        <div className="stat-value" style={{ color }}>{value}</div>
        <div className="stat-label">{label}</div>
      </div>
    </div>
  );
}

function QuickAction({ href, icon, title, subtitle }: {
  href: string; icon: string; title: string; subtitle: string;
}) {
  return (
    <a href={href} className="quick-action-card">
      <div className="stat-icon-wrap" style={{ background: "var(--accent-soft)" }}>
        <span className="material-symbols-rounded" style={{ color: "var(--accent)" }}>{icon}</span>
      </div>
      <div>
        <div style={{ fontSize: 13, fontWeight: 700 }}>{title}</div>
        <div className="stat-label">{subtitle}</div>
      </div>
    </a>
  );
}
