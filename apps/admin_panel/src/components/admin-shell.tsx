"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";

const NAV = [
  {
    section: "İçerik",
    items: [
      { href: "/admin", icon: "dashboard", label: "Dashboard" },
      { href: "/admin/templates", icon: "checkroom", label: "Kıyafet Şablonları" },
      { href: "/admin/stickers", icon: "star", label: "Sticker Yönetimi" },
    ],
  },
  {
    section: "Kullanıcılar",
    items: [
      { href: "/admin/users", icon: "group", label: "Üye Yönetimi" },
      { href: "/admin/credits", icon: "payments", label: "Kredi İşlemleri" },
    ],
  },
  {
    section: "Sistem",
    items: [{ href: "/admin/settings", icon: "settings", label: "Ayarlar" }],
  },
];

export function SidebarNav() {
  const pathname = usePathname();

  const isActive = (href: string) =>
    href === "/admin" ? pathname === "/admin" : pathname.startsWith(href);

  return (
    <aside className="sidebar">
      <div className="sidebar-brand">
        <div className="brand-logo-wrap">
          <span className="material-symbols-rounded brand-icon">checkroom</span>
        </div>
        <div className="brand-text">
          <div className="brand-title">RBLX Studio</div>
          <div className="brand-subtitle">Admin Console</div>
        </div>
      </div>

      <div className="sidebar-nav-scroll">
        {NAV.map((group) => (
          <div key={group.section} className="nav-group">
            <div className="nav-section-label">{group.section}</div>
            {group.items.map((item) => (
              <Link
                key={item.href}
                href={item.href}
                className={`nav-link${isActive(item.href) ? " active" : ""}`}
              >
                <span className="material-symbols-rounded nav-icon">{item.icon}</span>
                <span className="nav-label">{item.label}</span>
              </Link>
            ))}
          </div>
        ))}
      </div>

      <div className="sidebar-footer">
        <div className="sidebar-status">
          <span className="status-dot" />
          <div>
            <div className="sidebar-footer-title">Sistem hazır</div>
            <div className="sidebar-footer-sub">Supabase · canlı</div>
          </div>
        </div>
        <Link href="/" className="sidebar-site-link" target="_blank">
          <span className="material-symbols-rounded">public</span>
          Siteyi aç
        </Link>
      </div>
    </aside>
  );
}

export function AdminTopBar() {
  const pathname = usePathname();

  const meta: Record<string, { title: string; desc: string }> = {
    "/admin": { title: "Dashboard", desc: "Genel bakış ve hızlı işlemler" },
    "/admin/templates": {
      title: "Kıyafet Şablonları",
      desc: "Classic clothing UV şablonları",
    },
    "/admin/stickers": {
      title: "Sticker Yönetimi",
      desc: "Kategoriler ve sticker varlıkları",
    },
    "/admin/users": { title: "Üye Yönetimi", desc: "Kayıtlı kullanıcılar" },
    "/admin/credits": {
      title: "Kredi İşlemleri",
      desc: "Ledger ve bakiye hareketleri",
    },
    "/admin/settings": { title: "Ayarlar", desc: "Panel ve entegrasyon notları" },
  };

  const current =
    Object.entries(meta).find(([path]) =>
      path === "/admin" ? pathname === "/admin" : pathname.startsWith(path)
    )?.[1] ?? { title: "Admin", desc: "Yönetim paneli" };

  return (
    <header className="topbar">
      <div>
        <div className="topbar-eyebrow">RBLX Clothing Maker</div>
        <h2 className="topbar-title">{current.title}</h2>
        <p className="topbar-desc">{current.desc}</p>
      </div>
      <div className="topbar-actions">
        <span className="topbar-pill">
          <span className="material-symbols-rounded">cloud_done</span>
          Mobil senkron aktif
        </span>
      </div>
    </header>
  );
}
