"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";

const NAV = [
  { section: "Ana Menü", items: [
    { href: "/admin", icon: "dashboard", label: "Dashboard" },
    { href: "/admin/templates", icon: "checkroom", label: "Kıyafet Şablonları" },
    { href: "/admin/stickers", icon: "star", label: "Sticker Yönetimi" },
  ]},
  { section: "Kullanıcılar", items: [
    { href: "/admin/users", icon: "group", label: "Üye Yönetimi" },
    { href: "/admin/credits", icon: "monetization_on", label: "Kredi İşlemleri" },
  ]},
  { section: "Sistem", items: [
    { href: "/admin/settings", icon: "settings", label: "Ayarlar" },
  ]},
];

export function SidebarNav() {
  const pathname = usePathname();

  const isActive = (href: string) =>
    href === "/admin" ? pathname === "/admin" : pathname.startsWith(href);

  return (
    <nav className="sidebar">
      <div className="sidebar-brand">
        <div className="brand-logo-wrap">
          <span className="material-symbols-rounded brand-icon">checkroom</span>
        </div>
        <div>
          <div className="brand-title">RBLX Clothing Maker</div>
          <div className="brand-subtitle">Admin Panel</div>
        </div>
      </div>

      {NAV.map((group) => (
        <div key={group.section}>
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

      <div className="sidebar-footer">
        <span className="status-dot" />
        <div>
          <div className="sidebar-footer-title">Supabase bağlı</div>
          <div className="sidebar-footer-sub">v1.0.0 • Canlı içerik</div>
        </div>
      </div>
    </nav>
  );
}

export function AdminTopBar() {
  const pathname = usePathname();

  const titles: Record<string, string> = {
    "/admin": "Dashboard",
    "/admin/templates": "Kıyafet Şablonları",
    "/admin/stickers": "Sticker Yönetimi",
    "/admin/users": "Üye Yönetimi",
    "/admin/credits": "Kredi İşlemleri",
    "/admin/settings": "Ayarlar",
  };

  const title =
    Object.entries(titles).find(([path]) =>
      path === "/admin" ? pathname === "/admin" : pathname.startsWith(path)
    )?.[1] ?? "Admin";

  return (
    <header className="topbar">
      <div>
        <div className="topbar-eyebrow">Yönetim</div>
        <h2 className="topbar-title">{title}</h2>
      </div>
      <div className="topbar-actions">
        <span className="topbar-pill">
          <span className="material-symbols-rounded" style={{ fontSize: 16 }}>sync</span>
          Mobil uygulama otomatik senkron
        </span>
      </div>
    </header>
  );
}
