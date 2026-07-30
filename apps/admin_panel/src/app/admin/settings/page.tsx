export default function SettingsPage() {
  return (
    <div>
      <div className="page-header">
        <div>
          <h1 className="page-title">Ayarlar</h1>
          <p className="page-subtitle">Panel ve entegrasyon bilgileri</p>
        </div>
      </div>

      <div className="info-banner">
        <span className="material-symbols-rounded">info</span>
        <div>
          <strong>Supabase bağlantısı</strong>
          <p>
            Şablon ve sticker değişiklikleri <code>clothing_templates</code> tablosuna yazılır.
            Mobil uygulama aktif kayıtları anında çeker — ayrı deploy gerekmez.
          </p>
        </div>
      </div>

      <div className="form-card">
        <h3 className="section-title">Ortam değişkenleri</h3>
        <ul className="settings-list">
          <li><code>NEXT_PUBLIC_SUPABASE_URL</code> — Supabase proje URL</li>
          <li><code>NEXT_PUBLIC_SUPABASE_ANON_KEY</code> — Okuma anahtarı</li>
          <li><code>NEXT_PUBLIC_SUPABASE_SERVICE_KEY</code> — Admin yazma (sunucuda tutulmalı)</li>
        </ul>
      </div>
    </div>
  );
}
