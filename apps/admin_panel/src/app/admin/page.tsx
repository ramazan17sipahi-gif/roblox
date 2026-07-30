"use client";
import Link from "next/link";
import { useEffect, useState } from "react";
import { getSupabaseBrowser } from "@/lib/supabase-browser";

const supabase = getSupabaseBrowser();

interface Stats {
  templates: number;
  categories: number;
  stickers: number;
  users: number;
}

export default function DashboardPage() {
  const [stats, setStats] = useState<Stats>({
    templates: 0,
    categories: 0,
    stickers: 0,
    users: 0,
  });
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
    <div className="admin-page">
      <div className="page-header">
        <div>
          <h1 className="page-title">Operasyon özeti</h1>
          <p className="page-subtitle">
            İçerik, kullanıcı ve senkron durumu tek bakışta
          </p>
        </div>
        <Link href="/admin/templates" className="btn btn-primary">
          <span className="material-symbols-rounded" style={{ fontSize: 18 }}>
            add
          </span>
          Şablon ekle
        </Link>
      </div>

      <div className="stat-grid">
        <StatCard
          icon="checkroom"
          label="Kıyafet şablonları"
          value={loading ? "—" : String(stats.templates)}
          tone="orange"
        />
        <StatCard
          icon="category"
          label="Sticker kategorileri"
          value={loading ? "—" : String(stats.categories)}
          tone="teal"
        />
        <StatCard
          icon="star"
          label="Toplam sticker"
          value={loading ? "—" : String(stats.stickers)}
          tone="slate"
        />
        <StatCard
          icon="group"
          label="Kayıtlı üyeler"
          value={loading ? "—" : String(stats.users)}
          tone="green"
        />
      </div>

      <div className="dashboard-split">
        <section className="panel-card">
          <div className="panel-card-head">
            <h3 className="section-title">Hızlı işlemler</h3>
            <span className="panel-card-meta">Sık kullanılanlar</span>
          </div>
          <div className="quick-actions-list">
            <QuickAction
              href="/admin/templates"
              icon="add_circle"
              title="Yeni şablon"
              subtitle="Kıyafet UV şablonu oluştur"
            />
            <QuickAction
              href="/admin/stickers"
              icon="palette"
              title="Sticker yönet"
              subtitle="Kategori ve varlık düzenle"
            />
            <QuickAction
              href="/admin/users"
              icon="person_search"
              title="Üye ara"
              subtitle="Profil ve abonelik kontrolü"
            />
          </div>
        </section>

        <section className="panel-card">
          <div className="panel-card-head">
            <h3 className="section-title">Sistem notu</h3>
            <span className="panel-card-meta">Senkron</span>
          </div>
          <div className="info-banner info-banner-plain">
            <span className="material-symbols-rounded">cloud_sync</span>
            <div>
              <strong>Canlı içerik akışı</strong>
              <p>
                Aktif şablonlar ve stickerlar Supabase üzerinden mobil uygulamaya
                yansır. Pro işaretli şablonlar yalnızca Pro aboneler tarafından
                açılabilir.
              </p>
            </div>
          </div>
        </section>
      </div>
    </div>
  );
}

function StatCard({
  icon,
  label,
  value,
  tone,
}: {
  icon: string;
  label: string;
  value: string;
  tone: "orange" | "teal" | "slate" | "green";
}) {
  return (
    <div className={`stat-card tone-${tone}`}>
      <div className="stat-icon-wrap">
        <span className="material-symbols-rounded">{icon}</span>
      </div>
      <div>
        <div className="stat-value">{value}</div>
        <div className="stat-label">{label}</div>
      </div>
    </div>
  );
}

function QuickAction({
  href,
  icon,
  title,
  subtitle,
}: {
  href: string;
  icon: string;
  title: string;
  subtitle: string;
}) {
  return (
    <Link href={href} className="quick-action-row">
      <div className="stat-icon-wrap tone-orange">
        <span className="material-symbols-rounded">{icon}</span>
      </div>
      <div className="quick-action-copy">
        <div className="quick-action-title">{title}</div>
        <div className="stat-label">{subtitle}</div>
      </div>
      <span className="material-symbols-rounded quick-action-chevron">
        chevron_right
      </span>
    </Link>
  );
}
