import { SidebarNav, AdminTopBar } from "@/components/admin-shell";

export default function AdminLayout({ children }: { children: React.ReactNode }) {
  return (
    <div className="app-shell">
      <SidebarNav />
      <div className="main-column">
        <AdminTopBar />
        <main className="main-content">{children}</main>
      </div>
    </div>
  );
}
